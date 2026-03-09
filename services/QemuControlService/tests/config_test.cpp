#include "config.h"
#include <gtest/gtest.h>
#include <fstream>
#include <cstdlib>
#include <filesystem>

namespace fs = std::filesystem;

namespace {

class ConfigTest : public ::testing::Test {
protected:
    fs::path tmp_dir_;

    void SetUp() override {
        tmp_dir_ = fs::temp_directory_path() / ("qemu_control_test_" + std::to_string(getpid()));
        fs::create_directories(tmp_dir_);
    }

    void TearDown() override {
        std::error_code ec;
        fs::remove_all(tmp_dir_, ec);
    }

    std::string writeConfig(const std::string& content) {
        auto path = tmp_dir_ / "test.conf";
        std::ofstream f(path);
        if (!f) {
            ADD_FAILURE() << "Failed to create " << path;
            return "";
        }
        f << content;
        f.close();
        return path.string();
    }
};

TEST_F(ConfigTest, DefaultConfigPathWithoutEnv) {
    unsetenv("QEMU_CONTROL_CONFIG");
    EXPECT_EQ(qemu::control::Config::default_config_path(),
              "/etc/QemuWebControl/qemu-control.conf");
}

TEST_F(ConfigTest, DefaultConfigPathWithEnv) {
    auto custom = tmp_dir_ / "custom.conf";
    setenv("QEMU_CONTROL_CONFIG", custom.c_str(), 1);
    EXPECT_EQ(qemu::control::Config::default_config_path(), custom.string());
    unsetenv("QEMU_CONTROL_CONFIG");
}

TEST_F(ConfigTest, LoadParsesAllFields) {
    std::string content = R"(
LISTEN_ADDRESS=127.0.0.1
PORT=50053
HTTP_PORT=50054
LOG_PATH=/var/log/qemu.log
QEMU_BIN_PATH=/usr/bin/qemu-system-x86
VM_STORAGE=/var/lib/qemu/vms
QMP_SOCKET_DIR=/var/qemu/qmp
)";
    auto path = writeConfig(content);

    auto& config = qemu::control::Config::instance();
    config.load(path);

    EXPECT_EQ(config.listen_address(), "127.0.0.1");
    EXPECT_EQ(config.port(), 50053);
    EXPECT_EQ(config.http_port(), 50054);
    EXPECT_EQ(config.log_path(), "/var/log/qemu.log");
    EXPECT_EQ(config.qemu_bin_path(), "/usr/bin/qemu-system-x86");
    EXPECT_EQ(config.vm_storage(), "/var/lib/qemu/vms");
    EXPECT_EQ(config.qmp_socket_dir(), "/var/qemu/qmp");
}

TEST_F(ConfigTest, LoadSkipsCommentsAndEmptyLines) {
    std::string content = R"(
# comment
LISTEN_ADDRESS=0.0.0.0

PORT=60000
)";
    auto path = writeConfig(content);

    auto& config = qemu::control::Config::instance();
    config.load(path);

    EXPECT_EQ(config.listen_address(), "0.0.0.0");
    EXPECT_EQ(config.port(), 60000);
}

TEST_F(ConfigTest, LoadTrimsWhitespace) {
    std::string content = "  LISTEN_ADDRESS  =  127.0.0.1  \n";
    auto path = writeConfig(content);

    auto& config = qemu::control::Config::instance();
    config.load(path);

    EXPECT_EQ(config.listen_address(), "127.0.0.1");
}

TEST_F(ConfigTest, LoadMissingFileKeepsDefaults) {
    auto& config = qemu::control::Config::instance();
    config.load("/nonexistent/path/conf");

    EXPECT_EQ(config.listen_address(), "0.0.0.0");
    EXPECT_EQ(config.port(), 50053);
    EXPECT_EQ(config.http_port(), 50054);
    EXPECT_EQ(config.qemu_bin_path(), "/usr/bin/qemu-system-x86_64");
}

}  // namespace
