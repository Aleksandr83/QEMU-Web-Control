#include "config.h"
#include <gtest/gtest.h>
#include <fstream>
#include <cstdlib>

using namespace qemu::boot_images;

class ConfigTest : public ::testing::Test {
protected:
    void TearDown() override {
        unsetenv("QEMU_ISO_DIRECTORIES");
        unsetenv("QEMU_BOOT_IMAGES_CONFIG");
    }
};

TEST_F(ConfigTest, DefaultConfigPath) {
    unsetenv("QEMU_BOOT_IMAGES_CONFIG");
    EXPECT_EQ(Config::default_config_path(), "/etc/QemuWebControl/boot-media.conf");
}

TEST_F(ConfigTest, DefaultConfigPathFromEnv) {
    setenv("QEMU_BOOT_IMAGES_CONFIG", "/custom/path.conf", 1);
    EXPECT_EQ(Config::default_config_path(), "/custom/path.conf");
}

TEST_F(ConfigTest, LoadFromEnv) {
    setenv("QEMU_ISO_DIRECTORIES", "/dir1,/dir2,/dir3", 1);
    auto& config = Config::instance();
    config.load("/nonexistent");
    const auto& dirs = config.allowed_directories();
    ASSERT_EQ(dirs.size(), 3u);
    EXPECT_EQ(dirs[0], "/dir1");
    EXPECT_EQ(dirs[1], "/dir2");
    EXPECT_EQ(dirs[2], "/dir3");
}

TEST_F(ConfigTest, LoadFromFile) {
    unsetenv("QEMU_ISO_DIRECTORIES");
    unsetenv("QEMU_BOOT_IMAGES_CONFIG");
    std::string path = "/tmp/qemu_boot_config_test_" + std::to_string(getpid()) + ".conf";
    std::ofstream f(path);
    f << "ISO_DIRECTORIES=/a,/b\n";
    f << "PORT=9999\n";
    f << "RATE_LIMIT_MAX_REQUESTS=50\n";
    f << "RATE_LIMIT_WINDOW_SEC=30\n";
    f.close();

    auto& config = Config::instance();
    config.load(path);
    const auto& dirs = config.allowed_directories();
    ASSERT_EQ(dirs.size(), 2u);
    EXPECT_EQ(dirs[0], "/a");
    EXPECT_EQ(dirs[1], "/b");
    EXPECT_EQ(config.port(), 9999);
    EXPECT_EQ(config.rate_limit_max_requests(), 50u);
    EXPECT_EQ(config.rate_limit_window_sec(), 30);

    std::remove(path.c_str());
}
