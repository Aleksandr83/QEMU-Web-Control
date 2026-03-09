#include "config.h"
#include "iso_service_impl.h"
#include "logger.h"
#include "rate_limiter.h"
#include "proto/qemu_boot_images.grpc.pb.h"
#include <grpcpp/grpcpp.h>
#include <gtest/gtest.h>
#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>
#include <thread>
#include <vector>

namespace fs = std::filesystem;

class IsoServiceTest : public ::testing::Test {
protected:
    void SetUp() override {
        tmp_dir_ = fs::temp_directory_path() / ("qemu_boot_test_" + std::to_string(getpid()));
        fs::create_directories(tmp_dir_);
        staging_dir_ = (tmp_dir_ / "staging").string();
        fs::create_directories(staging_dir_);
        allowed_dirs_ = {tmp_dir_.string()};
        qemu::boot_images::Logger::instance().init("", qemu::boot_images::Logger::Level::ERROR);
    }

    void TearDown() override {
        unsetenv("QEMU_ISO_DIRECTORIES");
        unsetenv("QEMU_ISO_STAGING_DIR");
        std::error_code ec;
        fs::remove_all(tmp_dir_, ec);
    }

    std::string create_iso_file(const std::string& name = "test.iso") {
        fs::path p = tmp_dir_ / name;
        std::ofstream f(p);
        f << "test";
        f.close();
        return p.string();
    }

    std::string create_staging_file(const std::string& name, size_t size = 50) {
        fs::path p = fs::path(staging_dir_) / name;
        std::ofstream f(p, std::ios::binary);
        f << std::string(size, 'x');
        f.close();
        return p.string();
    }

    fs::path tmp_dir_;
    std::string staging_dir_;
    std::vector<std::string> allowed_dirs_;
};

TEST_F(IsoServiceTest, DeleteIso_SingleFile_Success) {
    std::string path = create_iso_file();
    ASSERT_TRUE(fs::exists(path));

    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::DeleteIsoRequest request;
    request.add_paths(path);
    qemu::boot_images::DeleteIsoResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.DeleteIso(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    ASSERT_EQ(response.results_size(), 1);
    EXPECT_TRUE(response.results(0).success());
    EXPECT_FALSE(fs::exists(path));
}

TEST_F(IsoServiceTest, DeleteIso_MultipleFiles_Success) {
    std::string path1 = create_iso_file("a.iso");
    std::string path2 = create_iso_file("b.iso");
    ASSERT_TRUE(fs::exists(path1));
    ASSERT_TRUE(fs::exists(path2));

    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::DeleteIsoRequest request;
    request.add_paths(path1);
    request.add_paths(path2);
    qemu::boot_images::DeleteIsoResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.DeleteIso(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    ASSERT_EQ(response.results_size(), 2);
    EXPECT_TRUE(response.results(0).success());
    EXPECT_TRUE(response.results(1).success());
    EXPECT_FALSE(fs::exists(path1));
    EXPECT_FALSE(fs::exists(path2));
}

TEST_F(IsoServiceTest, DeleteIso_PathOutsideAllowed_Fails) {
    std::string path = create_iso_file();
    std::string evil_path = "/etc/passwd";

    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::DeleteIsoRequest request;
    request.add_paths(evil_path);
    qemu::boot_images::DeleteIsoResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.DeleteIso(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    ASSERT_EQ(response.results_size(), 1);
    EXPECT_FALSE(response.results(0).success());
    EXPECT_TRUE(response.results(0).error_message().find("allowed") != std::string::npos);
}

TEST_F(IsoServiceTest, DeleteIso_NonIsoExtension_Fails) {
    fs::path p = tmp_dir_ / "file.txt";
    std::ofstream f(p);
    f << "test";
    f.close();

    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::DeleteIsoRequest request;
    request.add_paths(p.string());
    qemu::boot_images::DeleteIsoResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.DeleteIso(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    ASSERT_EQ(response.results_size(), 1);
    EXPECT_FALSE(response.results(0).success());
}

TEST_F(IsoServiceTest, DeleteIso_EmptyList_Ok) {
    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::DeleteIsoRequest request;
    qemu::boot_images::DeleteIsoResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.DeleteIso(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    EXPECT_EQ(response.results_size(), 0);
}

TEST_F(IsoServiceTest, DeleteIso_EmptyPathSkipped) {
    std::string path = create_iso_file();
    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::DeleteIsoRequest request;
    request.add_paths("");
    request.add_paths(path);
    request.add_paths("");
    qemu::boot_images::DeleteIsoResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.DeleteIso(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    ASSERT_EQ(response.results_size(), 1);
    EXPECT_TRUE(response.results(0).success());
    EXPECT_FALSE(fs::exists(path));
}

TEST_F(IsoServiceTest, DeleteIso_FileDoesNotExist) {
    std::string path = (tmp_dir_ / "nonexistent.iso").string();
    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::DeleteIsoRequest request;
    request.add_paths(path);
    qemu::boot_images::DeleteIsoResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.DeleteIso(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    ASSERT_EQ(response.results_size(), 1);
    EXPECT_FALSE(response.results(0).success());
    EXPECT_TRUE(response.results(0).error_message().find("exist") != std::string::npos);
}

TEST_F(IsoServiceTest, DeleteIso_DirectoryAsPath_Fails) {
    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::DeleteIsoRequest request;
    request.add_paths(tmp_dir_.string());
    qemu::boot_images::DeleteIsoResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.DeleteIso(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    ASSERT_EQ(response.results_size(), 1);
    EXPECT_FALSE(response.results(0).success());
}

TEST_F(IsoServiceTest, DeleteIso_ExtensionCaseInsensitive) {
    std::string path = create_iso_file("UPPER.ISO");
    ASSERT_TRUE(fs::exists(path));

    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::DeleteIsoRequest request;
    request.add_paths(path);
    qemu::boot_images::DeleteIsoResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.DeleteIso(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    ASSERT_EQ(response.results_size(), 1);
    EXPECT_TRUE(response.results(0).success());
    EXPECT_FALSE(fs::exists(path));
}

TEST_F(IsoServiceTest, DeleteIso_MixedSuccessAndFail) {
    std::string valid_path = create_iso_file("valid.iso");
    std::string invalid_path = "/etc/passwd";

    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::DeleteIsoRequest request;
    request.add_paths(invalid_path);
    request.add_paths(valid_path);
    qemu::boot_images::DeleteIsoResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.DeleteIso(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    ASSERT_EQ(response.results_size(), 2);
    EXPECT_FALSE(response.results(0).success());
    EXPECT_TRUE(response.results(1).success());
    EXPECT_FALSE(fs::exists(valid_path));
}

TEST_F(IsoServiceTest, DeleteIso_PathTraversal_Fails) {
    std::string path = (tmp_dir_ / ".." / ".." / "etc" / "passwd").string();
    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::DeleteIsoRequest request;
    request.add_paths(path);
    qemu::boot_images::DeleteIsoResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.DeleteIso(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    ASSERT_EQ(response.results_size(), 1);
    EXPECT_FALSE(response.results(0).success());
}

TEST_F(IsoServiceTest, DeleteIso_RateLimitExceeded) {
    qemu::boot_images::RateLimiter limiter(2, std::chrono::seconds(60));
    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, &limiter);

    std::string path1 = create_iso_file("a.iso");
    std::string path2 = create_iso_file("b.iso");
    std::string path3 = create_iso_file("c.iso");

    grpc::ServerContext ctx;

    qemu::boot_images::DeleteIsoRequest request;
    request.add_paths(path1);
    qemu::boot_images::DeleteIsoResponse response;
    ASSERT_TRUE(service.DeleteIso(&ctx, &request, &response).ok());

    request.Clear();
    response.Clear();
    request.add_paths(path2);
    ASSERT_TRUE(service.DeleteIso(&ctx, &request, &response).ok());

    request.Clear();
    response.Clear();
    request.add_paths(path3);
    grpc::Status status = service.DeleteIso(&ctx, &request, &response);

    EXPECT_EQ(status.error_code(), grpc::StatusCode::RESOURCE_EXHAUSTED);
    EXPECT_TRUE(status.error_message().find("Rate limit") != std::string::npos);
    EXPECT_TRUE(fs::exists(path3));
}

TEST_F(IsoServiceTest, DeleteIso_RateLimitDisabled) {
    qemu::boot_images::RateLimiter limiter(0, std::chrono::seconds(60));
    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, &limiter);

    for (int i = 0; i < 5; ++i) {
        std::string path = create_iso_file("f" + std::to_string(i) + ".iso");
        qemu::boot_images::DeleteIsoRequest request;
        request.add_paths(path);
        qemu::boot_images::DeleteIsoResponse response;
        grpc::ServerContext ctx;
        grpc::Status status = service.DeleteIso(&ctx, &request, &response);
        ASSERT_TRUE(status.ok()) << "Request " << i;
        ASSERT_EQ(response.results_size(), 1);
        EXPECT_TRUE(response.results(0).success());
    }
}

TEST_F(IsoServiceTest, MoveIso_Success_StartsOperation) {
    setenv("QEMU_ISO_DIRECTORIES", tmp_dir_.string().c_str(), 1);
    setenv("QEMU_ISO_STAGING_DIR", staging_dir_.c_str(), 1);
    qemu::boot_images::Config::instance().load("/nonexistent");

    create_staging_file("move_test.iso");
    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);

    qemu::boot_images::MoveIsoRequest request;
    request.set_operation_id("grpc-move-1");
    request.set_source_filename("move_test.iso");
    request.set_destination_directory(tmp_dir_.string());
    qemu::boot_images::MoveIsoResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.MoveIso(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    EXPECT_TRUE(response.error_message().empty());

    for (int i = 0; i < 50; ++i) {
        qemu::boot_images::GetProgressOperationRequest prog_req;
        prog_req.set_operation_id("grpc-move-1");
        qemu::boot_images::GetProgressOperationResponse prog_res;
        service.GetProgressOperation(&ctx, &prog_req, &prog_res);
        if (prog_res.status() == "completed") {
            EXPECT_EQ(prog_res.progress(), 100);
            EXPECT_TRUE(fs::exists(tmp_dir_ / "move_test.iso"));
            return;
        }
        if (prog_res.status() == "failed") {
            FAIL() << "Move failed: " << prog_res.error_message();
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
}

TEST_F(IsoServiceTest, GetProgressOperation_Unknown_ReturnsFailed) {
    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::GetProgressOperationRequest request;
    request.set_operation_id("nonexistent-op");
    qemu::boot_images::GetProgressOperationResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.GetProgressOperation(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    EXPECT_EQ(response.status(), "failed");
    EXPECT_FALSE(response.error_message().empty());
}

TEST_F(IsoServiceTest, CancelMoveOperation_Ok) {
    qemu::boot_images::IsoServiceImpl service(allowed_dirs_, nullptr, nullptr);
    qemu::boot_images::CancelMoveOperationRequest request;
    request.set_operation_id("any-id");
    qemu::boot_images::CancelMoveOperationResponse response;

    grpc::ServerContext ctx;
    grpc::Status status = service.CancelMoveOperation(&ctx, &request, &response);

    ASSERT_TRUE(status.ok());
    EXPECT_TRUE(response.cancelled());
}
