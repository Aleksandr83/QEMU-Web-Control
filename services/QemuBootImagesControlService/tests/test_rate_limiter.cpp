#include "rate_limiter.h"
#include <gtest/gtest.h>
#include <chrono>
#include <thread>

using namespace qemu::boot_images;

TEST(RateLimiterTest, AllowWithinLimit) {
    RateLimiter limiter(3, std::chrono::seconds(60));
    EXPECT_TRUE(limiter.allow("192.168.1.1"));
    EXPECT_TRUE(limiter.allow("192.168.1.1"));
    EXPECT_TRUE(limiter.allow("192.168.1.1"));
    EXPECT_FALSE(limiter.allow("192.168.1.1"));
}

TEST(RateLimiterTest, DifferentKeysIndependent) {
    RateLimiter limiter(1, std::chrono::seconds(60));
    EXPECT_TRUE(limiter.allow("ip1"));
    EXPECT_FALSE(limiter.allow("ip1"));
    EXPECT_TRUE(limiter.allow("ip2"));
    EXPECT_TRUE(limiter.allow("ip3"));
}

TEST(RateLimiterTest, ZeroMaxUnlimited) {
    RateLimiter limiter(0, std::chrono::seconds(60));
    for (int i = 0; i < 100; ++i) {
        EXPECT_TRUE(limiter.allow("any"));
    }
}

TEST(RateLimiterTest, ResetClearsCounts) {
    RateLimiter limiter(1, std::chrono::seconds(60));
    EXPECT_TRUE(limiter.allow("x"));
    EXPECT_FALSE(limiter.allow("x"));
    limiter.reset();
    EXPECT_TRUE(limiter.allow("x"));
}
