#include "qemu_service_impl.h"
#include <cerrno>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <signal.h>
#include <cstring>
#include <sstream>
#include <fstream>
#include <fcntl.h>
#include <chrono>
#include <thread>
#include <sys/stat.h>
#include <filesystem>

namespace qemu {
namespace control {

QemuServiceImpl::QemuServiceImpl(Config* config, Logger* logger)
    : config_(config), logger_(logger) {}

grpc::Status QemuServiceImpl::StartVm(grpc::ServerContext* context,
                                      const StartVmRequest* request,
                                      StartVmResponse* response) {
    (void)context;
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = vm_pids_.find(request->vm_id());
    if (it != vm_pids_.end() && isRunning(it->second)) {
        logger_->warn("StartVm rejected: VM already running vm_id=" + request->vm_id());
        response->set_success(false);
        response->set_error_message("VM already running");
        return grpc::Status::OK;
    }

    if (!request->qmp_socket_path().empty()) {
        std::filesystem::path p(request->qmp_socket_path());
        std::error_code ec;
        std::filesystem::create_directories(p.parent_path(), ec);
        logger_->info("StartVm vm_id=" + request->vm_id() + " qmp_socket_path=" + request->qmp_socket_path() +
            (ec ? " create_directories failed: " + ec.message() : " dir_ok"));
    }
    std::string cmd = buildQemuCommand(request);
    logger_->info("StartVm vm_id=" + request->vm_id() + " cmd=" + cmd);
    if (cmd.empty()) {
        logger_->error("StartVm failed: could not build QEMU command vm_id=" + request->vm_id());
        response->set_success(false);
        response->set_error_message("Failed to build QEMU command");
        return grpc::Status::OK;
    }

    pid_t pid = fork();
    if (pid < 0) {
        logger_->error("StartVm fork failed vm_id=" + request->vm_id() + ": " + strerror(errno));
        response->set_success(false);
        response->set_error_message(std::string("fork failed: ") + strerror(errno));
        return grpc::Status::OK;
    }

    std::string stderr_path;
    if (!request->qmp_socket_path().empty()) {
        stderr_path = request->qmp_socket_path();
        size_t pos = stderr_path.rfind(".qmp");
        if (pos != std::string::npos) {
            stderr_path.replace(pos, 4, ".start.err");
        } else {
            stderr_path += ".start.err";
        }
    }
    std::string run_cmd = cmd;
    if (!stderr_path.empty()) {
        run_cmd = "(" + cmd + ") 2>" + stderr_path;
    }

    if (pid == 0) {
        setsid();
        execl("/bin/sh", "sh", "-c", run_cmd.c_str(), nullptr);
        _exit(127);
    }

    int qemu_pid = static_cast<int>(pid);
    if (!request->qmp_socket_path().empty()) {
        std::string pidfile = request->qmp_socket_path();
        size_t pos = pidfile.rfind(".qmp");
        if (pos != std::string::npos) {
            pidfile.replace(pos, 4, ".pid");
        } else {
            pidfile += ".pid";
        }
        bool pid_read = false;
        for (int i = 0; i < 15; ++i) {
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
            std::ifstream f(pidfile);
            if (f && f >> qemu_pid && qemu_pid > 0) {
                std::error_code ec;
                std::filesystem::remove(pidfile, ec);
                pid_read = true;
                break;
            }
        }
        if (!pid_read) {
            logger_->warn("StartVm vm_id=" + request->vm_id() + " pidfile not found/empty: " + pidfile + " (shell_pid=" + std::to_string(pid) + ")");
            std::string err_msg = "QEMU failed to start (pidfile not found)";
            if (!stderr_path.empty() && std::filesystem::exists(stderr_path)) {
                std::ifstream ef(stderr_path);
                if (ef) {
                    std::string err_content((std::istreambuf_iterator<char>(ef)), std::istreambuf_iterator<char>());
                    ef.close();
                    std::error_code ec;
                    std::filesystem::remove(stderr_path, ec);
                    if (!err_content.empty()) {
                        logger_->error("StartVm vm_id=" + request->vm_id() + " QEMU stderr: " + err_content);
                        err_msg = "QEMU failed: " + err_content;
                        if (err_msg.length() > 200) {
                            err_msg = err_msg.substr(0, 197) + "...";
                        }
                    }
                }
            }
            response->set_success(false);
            response->set_error_message(err_msg);
            return grpc::Status::OK;
        }
        if (!stderr_path.empty()) {
            std::error_code ec;
            std::filesystem::remove(stderr_path, ec);
        }
        vm_qmp_sockets_[request->vm_id()] = request->qmp_socket_path();
    }
    vm_pids_[request->vm_id()] = qemu_pid;
    response->set_success(true);
    response->set_pid(qemu_pid);
    logger_->info("Started VM " + request->vm_id() + " pid=" + std::to_string(qemu_pid));
    return grpc::Status::OK;
}

grpc::Status QemuServiceImpl::StopVm(grpc::ServerContext* context,
                                    const StopVmRequest* request,
                                    StopVmResponse* response) {
    (void)context;
    std::lock_guard<std::mutex> lock(mutex_);
    int pid = request->pid() > 0 ? request->pid() : 0;
    if (pid <= 0) {
        auto it = vm_pids_.find(request->vm_id());
        if (it != vm_pids_.end()) {
            pid = it->second;
            vm_pids_.erase(it);
        }
    }
    if (pid <= 0) {
        logger_->warn("StopVm rejected: VM not found vm_id=" + request->vm_id());
        response->set_success(false);
        response->set_error_message("VM not found or not running");
        return grpc::Status::OK;
    }

    if (kill(pid, SIGTERM) != 0) {
        logger_->error("StopVm kill failed vm_id=" + request->vm_id() + " pid=" + std::to_string(pid) + ": " + strerror(errno));
        response->set_success(false);
        response->set_error_message(std::string("kill failed: ") + strerror(errno));
        return grpc::Status::OK;
    }
    vm_pids_.erase(request->vm_id());
    vm_qmp_sockets_.erase(request->vm_id());
    response->set_success(true);
    logger_->info("Stopped VM " + request->vm_id() + " pid=" + std::to_string(pid));
    return grpc::Status::OK;
}

grpc::Status QemuServiceImpl::GetVmStatus(grpc::ServerContext* context,
                                          const GetVmStatusRequest* request,
                                          GetVmStatusResponse* response) {
    (void)context;
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = vm_pids_.find(request->vm_id());
    if (it == vm_pids_.end()) {
        response->set_running(false);
        return grpc::Status::OK;
    }
    int pid = it->second;
    bool running = isRunning(pid);
    if (!running) {
        vm_pids_.erase(it);
        vm_qmp_sockets_.erase(request->vm_id());
    }
    response->set_running(running);
    response->set_pid(pid);
    return grpc::Status::OK;
}

grpc::Status QemuServiceImpl::CapturePreview(grpc::ServerContext* context,
                                            const CapturePreviewRequest* request,
                                            CapturePreviewResponse* response) {
    (void)context;
    std::string socket_path;
    int pid = 0;
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = vm_qmp_sockets_.find(request->vm_id());
        if (it != vm_qmp_sockets_.end()) {
            socket_path = it->second;
        } else if (!request->uuid().empty()) {
            std::string dir = config_->qmp_socket_dir();
            while (!dir.empty() && dir.back() == '/') dir.pop_back();
            std::string fallback = dir + "/qemu-" + request->uuid() + ".qmp";
            if (std::filesystem::exists(fallback)) {
                socket_path = fallback;
                vm_qmp_sockets_[request->vm_id()] = socket_path;
                logger_->info("CapturePreview vm_id=" + request->vm_id() + " fallback by uuid socket=" + socket_path);
            }
        }
        if (socket_path.empty()) {
            logger_->warn("CapturePreview vm_id=" + request->vm_id() + " VM not in vm_qmp_sockets_ (known: " + std::to_string(vm_qmp_sockets_.size()) + ")");
            response->set_success(false);
            response->set_error_message("VM not found or QMP socket unknown");
            return grpc::Status::OK;
        }
        auto pit = vm_pids_.find(request->vm_id());
        if (pit != vm_pids_.end()) pid = pit->second;
    }
    logger_->info("CapturePreview vm_id=" + request->vm_id() + " socket=" + socket_path + " pid=" + std::to_string(pid));
    if (pid > 0 && !isRunning(pid)) {
        logger_->warn("CapturePreview vm_id=" + request->vm_id() + " pid=" + std::to_string(pid) + " process not running");
        std::lock_guard<std::mutex> lock(mutex_);
        vm_pids_.erase(request->vm_id());
        vm_qmp_sockets_.erase(request->vm_id());
        response->set_success(false);
        response->set_error_message("VM process not running");
        return grpc::Status::OK;
    }

    char tmp_path[] = "/tmp/qemu-preview-XXXXXX.png";
    int fd = mkstemps(tmp_path, 4);
    if (fd < 0) {
        response->set_success(false);
        response->set_error_message(std::string("mkstemp failed: ") + strerror(errno));
        return grpc::Status::OK;
    }
    close(fd);

    std::string qmp_err;
    for (int attempt = 0; attempt < 3; ++attempt) {
        if (doQmpScreendump(socket_path, tmp_path, &qmp_err)) {
            logger_->info("CapturePreview vm_id=" + request->vm_id() + " screendump ok attempt=" + std::to_string(attempt + 1));
            break;
        }
        logger_->warn("CapturePreview vm_id=" + request->vm_id() + " attempt=" + std::to_string(attempt + 1) + " qmp_err=" + qmp_err);
        unlink(tmp_path);
        if (qmp_err.find("socket file not found") != std::string::npos ||
            qmp_err.find("No such file or directory") != std::string::npos) {
            if (attempt < 2) {
                logger_->info("CapturePreview vm_id=" + request->vm_id() + " retry in 2s");
                std::this_thread::sleep_for(std::chrono::seconds(2));
                continue;
            }
            std::lock_guard<std::mutex> lock(mutex_);
            vm_qmp_sockets_.erase(request->vm_id());
            if (pid > 0 && !isRunning(pid)) {
                vm_pids_.erase(request->vm_id());
            }
        }
        response->set_success(false);
        response->set_error_message(qmp_err.empty() ? "QMP screendump failed" : qmp_err);
        return grpc::Status::OK;
    }

    std::ifstream f(tmp_path, std::ios::binary);
    if (!f) {
        logger_->error("CapturePreview vm_id=" + request->vm_id() + " failed to read screendump file " + tmp_path);
        unlink(tmp_path);
        response->set_success(false);
        response->set_error_message("Failed to read screendump file");
        return grpc::Status::OK;
    }
    std::string data((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    f.close();
    unlink(tmp_path);

    response->set_success(true);
    response->set_image_data(data);
    return grpc::Status::OK;
}

bool QemuServiceImpl::isRunning(int pid) const {
    return kill(pid, 0) == 0;
}

static std::string qemuBinForArch(const std::string& default_bin, const std::string& arch) {
    if (arch.empty() || arch == "x86_64") {
        return default_bin;
    }
    size_t last_slash = default_bin.rfind('/');
    std::string dir = (last_slash != std::string::npos) ? default_bin.substr(0, last_slash + 1) : "";
    return dir + "qemu-system-" + arch;
}

static bool isVirtMachineArch(const std::string& arch) {
    return arch == "aarch64" || arch == "arm" || arch == "riscv64";
}

static bool isArmArch(const std::string& arch) {
    return arch == "aarch64" || arch == "arm";
}

std::string QemuServiceImpl::buildQemuCommand(const StartVmRequest* request) const {
    const std::string arch = request->architecture();
    std::ostringstream oss;

    oss << qemuBinForArch(config_->qemu_bin_path(), arch);

    if (isVirtMachineArch(arch)) {
        oss << " -machine virt";
        if (arch == "aarch64") {
            oss << " -cpu cortex-a57";
        } else if (arch == "arm") {
            oss << " -cpu cortex-a15";
        }
        oss << " -accel tcg";
        oss << " -device ramfb -device usb-ehci -device usb-kbd -device usb-mouse";
        if (isArmArch(arch)) {
            const std::string& aavmf = config_->aavmf_code_path();
            if (!aavmf.empty() && std::filesystem::exists(aavmf)) {
                oss << " -bios '" << aavmf << "'";
            } else {
                logger_->warn("buildQemuCommand: AAVMF not found at " + aavmf + " for arch=" + arch);
            }
        } else {
            const std::string& riscv_bios = config_->riscv_bios_path();
            if (!riscv_bios.empty() && std::filesystem::exists(riscv_bios)) {
                oss << " -drive if=pflash,format=raw,readonly=on,file='" << riscv_bios << "'";
            } else {
                logger_->warn("buildQemuCommand: RISC-V EDK2 firmware not found at " + riscv_bios + ", falling back to -bios default");
                oss << " -bios default";
            }
        }
    } else {
        if (request->enable_kvm() && config_->use_kvm()) {
            oss << " -enable-kvm";
        } else {
            oss << " -accel tcg";
        }
    }

    oss << " -m " << request->ram_mb()
        << " -smp " << request->cpu_cores()
        << " -drive file='" << request->primary_disk_path() << "',format=qcow2,if=virtio";
    for (int i = 0; i < request->additional_disks_size(); ++i) {
        oss << " -drive file='" << request->additional_disks(i) << "',format=qcow2,if=virtio";
    }

    std::string pidfile;
    if (!request->qmp_socket_path().empty()) {
        oss << " -qmp unix:" << request->qmp_socket_path() << ",server=on,wait=off";
        pidfile = request->qmp_socket_path();
        size_t pos = pidfile.rfind(".qmp");
        if (pos != std::string::npos) {
            pidfile.replace(pos, 4, ".pid");
        } else {
            pidfile += ".pid";
        }
        oss << " -pidfile " << pidfile;
    }

    if (request->vnc_port() > 0) {
        oss << " -vnc " << config_->vnc_bind_address() << ":" << (request->vnc_port() - 5900);
    }

    if (!request->iso_path().empty()) {
        if (isVirtMachineArch(arch)) {
            oss << " -drive file='" << request->iso_path() << "',media=cdrom,if=none,id=cdrom0,readonly=on"
                << " -device virtio-scsi-pci"
                << " -device scsi-cd,drive=cdrom0,bootindex=0";
        } else {
            oss << " -cdrom '" << request->iso_path() << "' -boot order=d";
        }
    }

    if (!request->mac_address().empty()) {
        oss << " -net nic,macaddr=" << request->mac_address();
    }
    oss << " -net " << (request->network_type().empty() ? "user" : request->network_type());
    oss << " -daemonize";
    return oss.str();
}

static bool qmpReadUntilReturn(int sock, char* buf, size_t buf_size, std::string* err) {
    std::string acc;
    for (int i = 0; i < 20; ++i) {
        ssize_t n = recv(sock, buf, buf_size - 1, 0);
        if (n <= 0) {
            if (err) *err = std::string("recv failed: ") + (n == 0 ? "connection closed" : strerror(errno));
            return false;
        }
        buf[n] = '\0';
        acc.append(buf);
        if (strstr(acc.c_str(), "\"return\"") != nullptr) {
            return true;
        }
        if (strstr(acc.c_str(), "\"error\"") != nullptr) {
            if (err) *err = "QMP error: " + acc.substr(0, 300);
            return false;
        }
    }
    if (err) *err = "QMP timeout: no return in response";
    return false;
}

static bool qmpReadGreeting(int sock, char* buf, size_t buf_size, std::string* err) {
    ssize_t n = recv(sock, buf, buf_size - 1, 0);
    if (n <= 0) {
        if (err) *err = std::string("recv greeting failed: ") + (n == 0 ? "connection closed" : strerror(errno));
        return false;
    }
    buf[n] = '\0';
    return true;
}

bool QemuServiceImpl::doQmpScreendump(const std::string& socket_path, const std::string& out_path, std::string* err_out) {
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        if (err_out) *err_out = std::string("socket failed: ") + strerror(errno);
        return false;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    if (socket_path.size() >= sizeof(addr.sun_path)) {
        close(sock);
        if (err_out) *err_out = "socket path too long";
        return false;
    }
    strncpy(addr.sun_path, socket_path.c_str(), sizeof(addr.sun_path) - 1);

    struct stat st;
    if (stat(socket_path.c_str(), &st) != 0) {
        std::string e = "socket file not found: " + socket_path + " (" + strerror(errno) + "). Restart the VM.";
        close(sock);
        if (err_out) *err_out = e;
        return false;
    }
    if (!S_ISSOCK(st.st_mode)) {
        std::string e = "path is not a socket: " + socket_path;
        close(sock);
        if (err_out) *err_out = e;
        return false;
    }
    if (connect(sock, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) != 0) {
        int err = errno;
        if (err == ECONNREFUSED) {
            unlink(socket_path.c_str());
        }
        std::string e = "connect failed: " + std::string(strerror(err)) + (err == ECONNREFUSED ? " (stale socket removed, restart VM)" : "");
        close(sock);
        if (err_out) *err_out = e;
        return false;
    }

    char buf[4096];
    if (!qmpReadGreeting(sock, buf, sizeof(buf), err_out)) {
        close(sock);
        return false;
    }

    std::string cap_cmd = "{\"execute\":\"qmp_capabilities\"}\r\n";
    if (send(sock, cap_cmd.c_str(), cap_cmd.size(), 0) != static_cast<ssize_t>(cap_cmd.size())) {
        if (err_out) *err_out = std::string("send qmp_capabilities failed: ") + strerror(errno);
        close(sock);
        return false;
    }
    if (!qmpReadUntilReturn(sock, buf, sizeof(buf), err_out)) {
        close(sock);
        return false;
    }

    std::string escaped;
    for (char c : out_path) {
        if (c == '\\') escaped += "\\\\";
        else if (c == '"') escaped += "\\\"";
        else escaped += c;
    }
    std::string dump_cmd = "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"" + escaped + "\",\"format\":\"png\"}}\r\n";
    if (send(sock, dump_cmd.c_str(), dump_cmd.size(), 0) != static_cast<ssize_t>(dump_cmd.size())) {
        if (err_out) *err_out = std::string("send screendump failed: ") + strerror(errno);
        close(sock);
        return false;
    }
    bool ok = qmpReadUntilReturn(sock, buf, sizeof(buf), err_out);
    close(sock);
    if (!ok) return false;

    for (int i = 0; i < 10; ++i) {
        std::ifstream f(out_path, std::ios::binary | std::ios::ate);
        if (f && f.tellg() > 0) {
            return true;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
    if (err_out) *err_out = "screendump file not created or empty";
    return false;
}

}  // namespace control
}  // namespace qemu
