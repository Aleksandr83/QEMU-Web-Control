#include "config.h"
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cstdlib>
#include <cerrno>
#include <cstring>

namespace qemu {
namespace boot_images {

Config& Config::instance() {
    static Config inst;
    return inst;
}

std::string Config::default_config_path() {
    const char* env = std::getenv("QEMU_BOOT_IMAGES_CONFIG");
    if (env && env[0]) {
        return env;
    }
    return "/etc/QemuWebControl/boot-media.conf";
}

static std::string trim(const std::string& s) {
    auto start = s.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    auto end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end == std::string::npos ? std::string::npos : end - start + 1);
}

static void split(const std::string& s, char delim, std::vector<std::string>& out) {
    std::stringstream ss(s);
    std::string item;
    while (std::getline(ss, item, delim)) {
        item = trim(item);
        if (!item.empty()) {
            out.push_back(item);
        }
    }
}

void Config::load(const std::string& config_path) {
    allowed_dirs_.clear();

    const char* env_dirs = std::getenv("QEMU_ISO_DIRECTORIES");
    if (env_dirs && env_dirs[0]) {
        split(env_dirs, ',', allowed_dirs_);
        for (auto& d : allowed_dirs_) {
            while (!d.empty() && d.back() == '/') d.pop_back();
        }
        const char* env_staging = std::getenv("QEMU_ISO_STAGING_DIR");
        staging_dir_ = (env_staging && env_staging[0]) ? env_staging : "/tmp/iso_staging";
        while (!staging_dir_.empty() && staging_dir_.back() == '/') staging_dir_.pop_back();
        return;
    }

    std::ifstream f(config_path);
    if (!f.is_open()) {
        allowed_dirs_ = {"/var/lib/qemu/iso", "/srv/iso"};
        staging_dir_ = "/tmp/iso_staging";
        return;
    }

    std::string line;
    while (std::getline(f, line)) {
        if (line.empty() || line[0] == '#') continue;
        size_t eq = line.find('=');
        if (eq == std::string::npos) continue;

        std::string key = trim(line.substr(0, eq));
        std::string val = trim(line.substr(eq + 1));
        if (key == "ISO_DIRECTORIES") {
            allowed_dirs_.clear();
            split(val, ',', allowed_dirs_);
            for (auto& d : allowed_dirs_) {
                while (!d.empty() && d.back() == '/') d.pop_back();
            }
        } else if (key == "LISTEN_ADDRESS") {
            listen_addr_ = val;
        } else if (key == "PORT") {
            port_ = static_cast<uint16_t>(std::stoul(val));
        } else if (key == "HTTP_PORT") {
            http_port_ = static_cast<uint16_t>(std::stoul(val));
        } else if (key == "LOG_PATH") {
            log_path_ = val;
        } else if (key == "RATE_LIMIT_MAX_REQUESTS") {
            rate_limit_max_ = static_cast<size_t>(std::stoull(val));
        } else if (key == "RATE_LIMIT_WINDOW_SEC") {
            rate_limit_window_sec_ = std::stoi(val);
        } else if (key == "API_KEY") {
            api_key_ = val;
        } else if (key == "STAGING_DIR") {
            staging_dir_ = val;
            while (!staging_dir_.empty() && staging_dir_.back() == '/') staging_dir_.pop_back();
        }
    }
    if (staging_dir_.empty()) {
        const char* env = std::getenv("QEMU_ISO_STAGING_DIR");
        if (env && env[0]) {
            staging_dir_ = env;
            while (!staging_dir_.empty() && staging_dir_.back() == '/') staging_dir_.pop_back();
        } else {
            staging_dir_ = "/tmp/iso_staging";
        }
    }
}

}  // namespace boot_images
}  // namespace qemu
