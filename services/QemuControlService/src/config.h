#pragma once

#include <cstdint>
#include <string>

namespace qemu {
namespace control {

class Config {
public:
    static Config& instance();

    void load(const std::string& config_path = default_config_path());
    std::string listen_address() const { return listen_addr_; }
    uint16_t port() const { return port_; }
    uint16_t http_port() const { return http_port_; }
    std::string log_path() const { return log_path_; }
    std::string qemu_bin_path() const { return qemu_bin_path_; }
    std::string vm_storage() const { return vm_storage_; }
    std::string qmp_socket_dir() const { return qmp_socket_dir_; }
    bool use_kvm() const { return use_kvm_; }
    std::string vnc_bind_address() const { return vnc_bind_address_; }
    std::string vnc_token_file() const { return vnc_token_file_; }
    uint16_t vnc_ws_port() const { return vnc_ws_port_; }
    std::string vnc_ssl_cert() const { return vnc_ssl_cert_; }
    std::string vnc_ssl_key() const { return vnc_ssl_key_; }

    static std::string default_config_path();

private:
    Config() = default;
    std::string listen_addr_ = "0.0.0.0";
    uint16_t port_ = 50053;
    uint16_t http_port_ = 50054;
    std::string log_path_;
    std::string qemu_bin_path_ = "/usr/bin/qemu-system-x86_64";
    std::string vm_storage_ = "/var/lib/qemu/vms";
    std::string qmp_socket_dir_ = "/var/qemu/qmp";
    bool use_kvm_ = true;
    std::string vnc_bind_address_ = "0.0.0.0";
    std::string vnc_token_file_;
    uint16_t vnc_ws_port_ = 50055;
    std::string vnc_ssl_cert_;
    std::string vnc_ssl_key_;
};

}  // namespace control
}  // namespace qemu
