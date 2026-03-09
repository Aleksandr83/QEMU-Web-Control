#include "rate_limiter.h"

namespace qemu {
namespace boot_images {

RateLimiter::RateLimiter(size_t max_requests, std::chrono::seconds window)
    : max_requests_(max_requests), window_(window) {}

bool RateLimiter::allow(const std::string& key) {
    if (max_requests_ == 0) return true;

    std::lock_guard<std::mutex> lock(mtx_);
    auto now = std::chrono::steady_clock::now();
    auto& e = entries_[key];

    if (e.count == 0 || now - e.window_start >= window_) {
        e.count = 1;
        e.window_start = now;
        return true;
    }

    if (e.count >= max_requests_) {
        return false;
    }
    ++e.count;
    return true;
}

void RateLimiter::reset() {
    std::lock_guard<std::mutex> lock(mtx_);
    entries_.clear();
}

}  // namespace boot_images
}  // namespace qemu
