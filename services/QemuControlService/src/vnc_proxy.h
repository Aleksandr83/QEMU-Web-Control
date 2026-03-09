#pragma once

#include "config.h"
#include "logger.h"
#include <atomic>
#include <memory>
#include <string>
#include <thread>

namespace qemu {
namespace control {

class VncProxy {
public:
    VncProxy(Config* config, Logger* logger);
    ~VncProxy();

    void start();
    void stop();

private:
    void run();

    Config* config_;
    Logger* logger_;
    std::atomic<bool> running_{false};
    pid_t websockify_pid_ = -1;
    std::unique_ptr<std::thread> thread_;
};

}  // namespace control
}  // namespace qemu
