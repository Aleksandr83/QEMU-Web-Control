#pragma once

#include "qemu_service_impl.h"
#include <httplib.h>
#include <cstdint>
#include <memory>
#include <string>
#include <thread>

namespace qemu {
namespace control {

class HttpServer {
public:
    HttpServer(QemuServiceImpl* service, const std::string& host, uint16_t port);
    ~HttpServer();

    void start();
    void stop();

private:
    void run();

    QemuServiceImpl* service_;
    std::string host_;
    uint16_t port_;
    bool running_ = false;
    std::unique_ptr<std::thread> thread_;
    std::unique_ptr<httplib::Server> server_;
};

}  // namespace control
}  // namespace qemu
