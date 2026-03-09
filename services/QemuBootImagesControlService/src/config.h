#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace qemu {
namespace boot_images {

class Config {
public:
    static Config& instance();

    void load(const std::string& config_path = default_config_path());
    const std::vector<std::string>& allowed_directories() const { return allowed_dirs_; }
    const std::string& staging_dir() const { return staging_dir_; }
    std::string listen_address() const { return listen_addr_; }
    uint16_t port() const { return port_; }
    uint16_t http_port() const { return http_port_; }
    std::string log_path() const { return log_path_; }
    size_t rate_limit_max_requests() const { return rate_limit_max_; }
    int rate_limit_window_sec() const { return rate_limit_window_sec_; }
    const std::string& api_key() const { return api_key_; }

    static std::string default_config_path();

private:
    Config() = default;
    std::vector<std::string> allowed_dirs_;
    std::string staging_dir_;
    std::string listen_addr_ = "0.0.0.0";
    uint16_t port_ = 50051;
    uint16_t http_port_ = 50052;
    std::string log_path_;
    size_t rate_limit_max_ = 100;
    int rate_limit_window_sec_ = 60;
    std::string api_key_;
};

}  // namespace boot_images
}  // namespace qemu
