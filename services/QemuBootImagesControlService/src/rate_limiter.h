#pragma once

#include <chrono>
#include <map>
#include <mutex>
#include <string>

namespace qemu {
namespace boot_images {

class RateLimiter {
public:
    RateLimiter(size_t max_requests, std::chrono::seconds window);

    bool allow(const std::string& key);
    void reset();

private:
    struct Entry {
        size_t count = 0;
        std::chrono::steady_clock::time_point window_start;
    };

    size_t max_requests_;
    std::chrono::seconds window_;
    std::map<std::string, Entry> entries_;
    std::mutex mtx_;
};

}  // namespace boot_images
}  // namespace qemu
