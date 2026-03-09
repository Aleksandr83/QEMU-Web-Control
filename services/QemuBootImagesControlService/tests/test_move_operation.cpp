#include "config.h"
#include "logger.h"
#include "move_operation.h"
#include "proto/qemu_boot_images.grpc.pb.h"
#include <grpcpp/grpcpp.h>
#include <gtest/gtest.h>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <string>
#include <thread>

namespace fs = std::filesystem;

class MoveOperationTest : public ::testing::Test {
protected:
    void SetUp() override {
        tmp_base_ = fs::temp_directory_path() / ("qemu_move_test_" + std::to_string(getpid()));
        staging_dir_ = (tmp_base_ / "staging").string();
        dest_dir_ = (tmp_base_ / "dest").string();
        fs::create_directories(staging_dir_);
        fs::create_directories(dest_dir_);
        allowed_dirs_ = {dest_dir_};
        qemu::boot_images::Logger::instance().init("", qemu::boot_images::Logger::Level::ERROR);
    }

    void TearDown() override {
        std::error_code ec;
        fs::remove_all(tmp_base_, ec);
    }

    std::string create_staging_file(const std::string& name, size_t size = 100) {
        fs::path p = fs::path(staging_dir_) / name;
        std::ofstream f(p, std::ios::binary);
        std::string data(size, 'x');
        f << data;
        f.close();
        return p.string();
    }

    fs::path tmp_base_;
    std::string staging_dir_;
    std::string dest_dir_;
    std::vector<std::string> allowed_dirs_;
};

TEST_F(MoveOperationTest, StartMove_Success_CopiesFile) {
    create_staging_file("test.iso");
    auto& mgr = qemu::boot_images::MoveOperationManager::instance();

    std::string err = mgr.startMove("op1", "test.iso", dest_dir_, staging_dir_, allowed_dirs_);
    ASSERT_TRUE(err.empty()) << err;

    for (int i = 0; i < 50; ++i) {
        auto state = mgr.getProgress("op1");
        if (state.status == qemu::boot_images::MoveStatus::Completed) {
            EXPECT_EQ(state.progress, 100);
            EXPECT_TRUE(fs::exists(fs::path(dest_dir_) / "test.iso"));
            EXPECT_FALSE(fs::exists(fs::path(staging_dir_) / "test.iso"));
            return;
        }
        if (state.status == qemu::boot_images::MoveStatus::Failed) {
            FAIL() << "Move failed: " << state.error_message;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
    FAIL() << "Move did not complete in time";
}

TEST_F(MoveOperationTest, StartMove_SourceNotFound_ReturnsError) {
    auto& mgr = qemu::boot_images::MoveOperationManager::instance();
    std::string err = mgr.startMove("op2", "nonexistent.iso", dest_dir_, staging_dir_, allowed_dirs_);
    EXPECT_FALSE(err.empty());
    EXPECT_TRUE(err.find("exist") != std::string::npos || err.find("Source") != std::string::npos);
}

TEST_F(MoveOperationTest, StartMove_InvalidFilename_ReturnsError) {
    create_staging_file("ok.iso");
    auto& mgr = qemu::boot_images::MoveOperationManager::instance();
    std::string err = mgr.startMove("op3", "../etc/passwd", dest_dir_, staging_dir_, allowed_dirs_);
    EXPECT_FALSE(err.empty());
}

TEST_F(MoveOperationTest, StartMove_DestinationNotAllowed_ReturnsError) {
    create_staging_file("test.iso");
    std::vector<std::string> restricted = {"/tmp/other"};
    auto& mgr = qemu::boot_images::MoveOperationManager::instance();
    std::string err = mgr.startMove("op4", "test.iso", "/tmp/evil", staging_dir_, restricted);
    EXPECT_FALSE(err.empty());
}

TEST_F(MoveOperationTest, GetProgress_UnknownOperation_ReturnsFailed) {
    auto& mgr = qemu::boot_images::MoveOperationManager::instance();
    auto state = mgr.getProgress("unknown-op");
    EXPECT_EQ(state.status, qemu::boot_images::MoveStatus::Failed);
    EXPECT_FALSE(state.error_message.empty());
}

TEST_F(MoveOperationTest, Cancel_StopsOperation) {
    create_staging_file("large.iso", 5 * 1024 * 1024);
    auto& mgr = qemu::boot_images::MoveOperationManager::instance();

    std::string err = mgr.startMove("op5", "large.iso", dest_dir_, staging_dir_, allowed_dirs_);
    ASSERT_TRUE(err.empty());

    std::this_thread::sleep_for(std::chrono::milliseconds(50));
    mgr.cancel("op5");

    for (int i = 0; i < 30; ++i) {
        auto state = mgr.getProgress("op5");
        if (state.status == qemu::boot_images::MoveStatus::Cancelled) {
            EXPECT_TRUE(fs::exists(fs::path(staging_dir_) / "large.iso"));
            return;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
}

TEST_F(MoveOperationTest, StartMove_DuplicateOperationId_ReturnsError) {
    create_staging_file("test.iso");
    auto& mgr = qemu::boot_images::MoveOperationManager::instance();

    std::string err1 = mgr.startMove("op6", "test.iso", dest_dir_, staging_dir_, allowed_dirs_);
    ASSERT_TRUE(err1.empty());

    std::string err2 = mgr.startMove("op6", "test.iso", dest_dir_, staging_dir_, allowed_dirs_);
    EXPECT_FALSE(err2.empty());
    EXPECT_TRUE(err2.find("already") != std::string::npos || err2.find("exists") != std::string::npos);

    for (int i = 0; i < 50; ++i) {
        auto state = mgr.getProgress("op6");
        if (state.status == qemu::boot_images::MoveStatus::Completed) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
}
