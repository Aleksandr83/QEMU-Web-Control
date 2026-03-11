#include "config.h"
#include <fstream>
#include <sstream>
#include <cstdlib>

namespace qemu {
namespace control {

Config& Config::instance() {
    static Config inst;
    return inst;
}

std::string Config::default_config_path() {
    const char* env = std::getenv("QEMU_CONTROL_CONFIG");
    if (env && env[0]) {
        return env;
    }
    return "/etc/QemuWebControl/qemu-control.conf";
}

static std::string trim(const std::string& s) {
    auto start = s.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    auto end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end == std::string::npos ? std::string::npos : end - start + 1);
}

void Config::load(const std::string& config_path) {
    std::ifstream f(config_path);
    if (!f.is_open()) {
        return;
    }

    std::string line;
    while (std::getline(f, line)) {
        if (line.empty() || line[0] == '#') continue;
        size_t eq = line.find('=');
        if (eq == std::string::npos) continue;

        std::string key = trim(line.substr(0, eq));
        std::string val = trim(line.substr(eq + 1));
        if (key == "LISTEN_ADDRESS") {
            listen_addr_ = val;
        } else if (key == "PORT") {
            port_ = static_cast<uint16_t>(std::stoul(val));
        } else if (key == "HTTP_PORT") {
            http_port_ = static_cast<uint16_t>(std::stoul(val));
        } else if (key == "LOG_PATH") {
            log_path_ = val;
        } else if (key == "QEMU_BIN_PATH") {
            qemu_bin_path_ = val;
        } else if (key == "VM_STORAGE") {
            vm_storage_ = val;
        } else if (key == "QMP_SOCKET_DIR") {
            qmp_socket_dir_ = val;
        } else if (key == "USE_KVM") {
            use_kvm_ = (val == "1" || val == "true" || val == "yes");
        } else if (key == "VNC_BIND_ADDRESS") {
            if (!val.empty()) {
                vnc_bind_address_ = val;
            }
        } else if (key == "VNC_TOKEN_FILE") {
            if (!val.empty()) {
                vnc_token_file_ = val;
            }
        } else if (key == "VNC_WS_PORT") {
            vnc_ws_port_ = static_cast<uint16_t>(std::stoul(val));
        } else if (key == "VNC_SSL_CERT") {
            vnc_ssl_cert_ = val;
        } else if (key == "VNC_SSL_KEY") {
            vnc_ssl_key_ = val;
        } else if (key == "VNC_WEB_DIR") {
            if (!val.empty()) {
                vnc_web_dir_ = val;
            }
        } else if (key == "AAVMF_CODE_PATH") {
            if (!val.empty()) {
                aavmf_code_path_ = val;
            }
        } else if (key == "RISCV_BIOS_PATH") {
            if (!val.empty()) {
                riscv_bios_path_ = val;
            }
        }
    }
}

}  // namespace control
}  // namespace qemu
