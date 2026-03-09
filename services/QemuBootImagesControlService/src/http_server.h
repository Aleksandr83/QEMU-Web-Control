#pragma once

#include "iso_service_impl.h"
#include <atomic>
#include <memory>
#include <string>
#include <thread>

namespace qemu {
namespace boot_images {

class HttpServer {
public:
    HttpServer(IsoServiceImpl* service, const std::string& host, uint16_t port);
    ~HttpServer();

    void start();
    void stop();

private:
    void run();

    IsoServiceImpl* service_;
    std::string host_;
    uint16_t port_;
    std::atomic<bool> running_{false};
    std::unique_ptr<std::thread> thread_;
};

}  // namespace boot_images
}  // namespace qemu
