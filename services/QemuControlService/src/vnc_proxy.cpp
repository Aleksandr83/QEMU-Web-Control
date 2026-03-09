#include "vnc_proxy.h"
#include <chrono>
#include <csignal>
#include <cstring>
#include <fcntl.h>
#include <fstream>
#include <unistd.h>
#include <sys/wait.h>

namespace qemu {
namespace control {

VncProxy::VncProxy(Config* config, Logger* logger)
    : config_(config), logger_(logger) {}

VncProxy::~VncProxy() {
    stop();
}

void VncProxy::start() {
    if (config_->vnc_token_file().empty()) {
        logger_->info("VNC proxy disabled: VNC_TOKEN_FILE not set");
        return;
    }
    if (running_.exchange(true)) return;
    thread_ = std::make_unique<std::thread>(&VncProxy::run, this);
}

void VncProxy::stop() {
    if (!running_.exchange(false)) return;
    if (websockify_pid_ > 0) {
        kill(websockify_pid_, SIGTERM);
        int status;
        for (int i = 0; i < 50 && waitpid(websockify_pid_, &status, WNOHANG) == 0; ++i) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        if (waitpid(websockify_pid_, &status, WNOHANG) == 0) {
            kill(websockify_pid_, SIGKILL);
        }
        websockify_pid_ = -1;
    }
    if (thread_ && thread_->joinable()) {
        thread_->join();
    }
}

void VncProxy::run() {
    std::string token_file = config_->vnc_token_file();
    uint16_t port = config_->vnc_ws_port();

    std::ifstream f(token_file);
    if (!f.good()) {
        std::ofstream create(token_file);
        if (!create) {
            logger_->warn("VNC proxy: cannot create token file " + token_file);
            return;
        }
    }

    std::string port_str = std::to_string(port);
    std::string listen_addr = "0.0.0.0:" + port_str;

    std::string cert = config_->vnc_ssl_cert();
    std::string key  = config_->vnc_ssl_key();
    bool use_ssl = !cert.empty() && !key.empty();

    websockify_pid_ = fork();
    if (websockify_pid_ < 0) {
        logger_->error("VNC proxy fork failed: " + std::string(strerror(errno)));
        return;
    }

    if (websockify_pid_ == 0) {
        setsid();
        int devnull = open("/dev/null", O_RDWR);
        if (devnull >= 0) {
            dup2(devnull, STDIN_FILENO);
            dup2(devnull, STDOUT_FILENO);
            dup2(devnull, STDERR_FILENO);
            if (devnull > 2) close(devnull);
        }
        if (use_ssl) {
            if (execlp("websockify", "websockify", "-v",
                       "--token-plugin", "TokenFile",
                       "--token-source", token_file.c_str(),
                       "--cert", cert.c_str(),
                       "--key", key.c_str(),
                       listen_addr.c_str(), nullptr) < 0) {
                execlp("python3", "python3", "-m", "websockify", "-v",
                       "--token-plugin", "TokenFile",
                       "--token-source", token_file.c_str(),
                       "--cert", cert.c_str(),
                       "--key", key.c_str(),
                       listen_addr.c_str(), nullptr);
            }
        } else {
            if (execlp("websockify", "websockify", "-v",
                       "--token-plugin", "TokenFile",
                       "--token-source", token_file.c_str(),
                       listen_addr.c_str(), nullptr) < 0) {
                execlp("python3", "python3", "-m", "websockify", "-v",
                       "--token-plugin", "TokenFile",
                       "--token-source", token_file.c_str(),
                       listen_addr.c_str(), nullptr);
            }
        }
        _exit(127);
    }

    logger_->info("VNC proxy started websockify pid=" + std::to_string(websockify_pid_) +
                  " port=" + port_str + " token_file=" + token_file);

    while (running_) {
        int status;
        pid_t r = waitpid(websockify_pid_, &status, WNOHANG);
        if (r == websockify_pid_) {
            logger_->warn("VNC proxy websockify exited");
            websockify_pid_ = -1;
            break;
        }
        std::this_thread::sleep_for(std::chrono::seconds(5));
    }
}

}  // namespace control
}  // namespace qemu
