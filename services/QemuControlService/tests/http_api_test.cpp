#include "config.h"
#include "http_server.h"
#include "logger.h"
#include "qemu_service_impl.h"
#include <gtest/gtest.h>
#include <httplib.h>
#include <nlohmann/json.hpp>
#include <fstream>
#include <filesystem>
#include <thread>
#include <chrono>

namespace fs = std::filesystem;

namespace {

constexpr uint16_t TEST_HTTP_PORT = 55454;

class HttpApiTest : public ::testing::Test {
protected:
    fs::path tmp_dir_;
    std::string config_path_;
    std::string fake_qemu_path_;
    std::unique_ptr<qemu::control::QemuServiceImpl> service_;
    std::unique_ptr<qemu::control::HttpServer> http_server_;

    void SetUp() override {
        tmp_dir_ = fs::temp_directory_path() / ("qemu_control_test_" + std::to_string(getpid()));
        fs::create_directories(tmp_dir_);

        fake_qemu_path_ = (tmp_dir_ / "fake_qemu.sh").string();
        std::ofstream qemu(fake_qemu_path_);
        qemu << "#!/bin/sh\n"
             << "while [ $# -gt 0 ]; do\n"
             << "  case \"$1\" in\n"
             << "    -pidfile)\n"
             << "      echo $$ > \"$2\"\n"
             << "      shift 2\n"
             << "      ;;\n"
             << "    *)\n"
             << "      shift\n"
             << "      ;;\n"
             << "  esac\n"
             << "done\n"
             << "sleep 5\n";
        qemu.close();
        fs::permissions(fake_qemu_path_, fs::perms::owner_exec | fs::perms::owner_read);

        std::string conf = "LISTEN_ADDRESS=127.0.0.1\nPORT=0\nHTTP_PORT=" +
                           std::to_string(TEST_HTTP_PORT) + "\nLOG_PATH=\nQEMU_BIN_PATH=" +
                           fake_qemu_path_ + "\nVM_STORAGE=" + tmp_dir_.string() + "\n";
        config_path_ = (tmp_dir_ / "qemu-control.conf").string();
        std::ofstream cf(config_path_);
        cf << conf;
        cf.close();

        auto& config = qemu::control::Config::instance();
        config.load(config_path_);

        qemu::control::Logger::instance().init("", qemu::control::Logger::Level::WARN);

        service_ = std::make_unique<qemu::control::QemuServiceImpl>(
            &config, &qemu::control::Logger::instance());
        http_server_ = std::make_unique<qemu::control::HttpServer>(
            service_.get(), "127.0.0.1", TEST_HTTP_PORT);
        http_server_->start();
        std::this_thread::sleep_for(std::chrono::milliseconds(300));
    }

    void TearDown() override {
        http_server_.reset();
        std::error_code ec;
        fs::remove_all(tmp_dir_, ec);
    }

    httplib::Client makeClient() {
        return httplib::Client("127.0.0.1", TEST_HTTP_PORT);
    }
};

TEST_F(HttpApiTest, HealthReturnsOk) {
    auto cli = makeClient();
    cli.set_connection_timeout(2, 0);
    auto res = cli.Get("/health");
    ASSERT_TRUE(res) << "Connection failed: " << res.error();
    EXPECT_EQ(res->status, 200);
    auto j = nlohmann::json::parse(res->body);
    EXPECT_EQ(j["status"], "ok");
}

TEST_F(HttpApiTest, StartInvalidJsonReturns400) {
    auto cli = makeClient();
    cli.set_connection_timeout(2, 0);
    auto res = cli.Post("/start", "invalid json", "application/json");
    ASSERT_TRUE(res);
    EXPECT_EQ(res->status, 400);
    auto j = nlohmann::json::parse(res->body);
    EXPECT_FALSE(j["success"]);
    EXPECT_TRUE(j["error_message"].get<std::string>().find("Invalid JSON") != std::string::npos);
}

TEST_F(HttpApiTest, StopInvalidJsonReturns400) {
    auto cli = makeClient();
    cli.set_connection_timeout(2, 0);
    auto res = cli.Post("/stop", "{", "application/json");
    ASSERT_TRUE(res);
    EXPECT_EQ(res->status, 400);
}

TEST_F(HttpApiTest, StatusInvalidJsonReturns400) {
    auto cli = makeClient();
    cli.set_connection_timeout(2, 0);
    auto res = cli.Post("/status", "not json", "application/json");
    ASSERT_TRUE(res);
    EXPECT_EQ(res->status, 400);
}

TEST_F(HttpApiTest, StartStopStatusFlow) {
    auto disk_path = (tmp_dir_ / "disk.qcow2").string();
    std::ofstream(disk_path).close();

    nlohmann::json start_req = {
        {"vm_id", "test-vm-1"},
        {"architecture", "x86_64"},
        {"cpu_cores", 2},
        {"ram_mb", 2048},
        {"primary_disk_path", disk_path},
        {"additional_disks", nlohmann::json::array()},
        {"iso_path", ""},
        {"network_type", "user"},
        {"vnc_port", 0},
        {"mac_address", ""},
        {"qmp_socket_path", ""}
    };

    auto cli = makeClient();
    cli.set_connection_timeout(2, 0);

    auto start_res = cli.Post("/start", start_req.dump(), "application/json");
    ASSERT_TRUE(start_res) << start_res.error();
    EXPECT_EQ(start_res->status, 200);
    auto start_j = nlohmann::json::parse(start_res->body);
    ASSERT_TRUE(start_j["success"]) << start_j.dump();
    int pid = start_j["pid"];
    EXPECT_GT(pid, 0);

    auto status_res = cli.Post("/status", "{\"vm_id\":\"test-vm-1\"}", "application/json");
    ASSERT_TRUE(status_res);
    EXPECT_EQ(status_res->status, 200);
    auto status_j = nlohmann::json::parse(status_res->body);
    EXPECT_TRUE(status_j["running"]);
    EXPECT_EQ(status_j["pid"], pid);

    nlohmann::json stop_req = {{"vm_id", "test-vm-1"}, {"pid", pid}};
    auto stop_res = cli.Post("/stop", stop_req.dump(), "application/json");
    ASSERT_TRUE(stop_res);
    EXPECT_EQ(stop_res->status, 200);
    auto stop_j = nlohmann::json::parse(stop_res->body);
    EXPECT_TRUE(stop_j["success"]);

    std::this_thread::sleep_for(std::chrono::milliseconds(200));

    auto status_after = cli.Post("/status", "{\"vm_id\":\"test-vm-1\"}", "application/json");
    ASSERT_TRUE(status_after);
    auto status_after_j = nlohmann::json::parse(status_after->body);
    EXPECT_FALSE(status_after_j["running"]);
}

TEST_F(HttpApiTest, StartDuplicateReturnsError) {
    auto disk_path = (tmp_dir_ / "disk2.qcow2").string();
    std::ofstream(disk_path).close();

    nlohmann::json req = {
        {"vm_id", "test-vm-dup"},
        {"primary_disk_path", disk_path}
    };

    auto cli = makeClient();
    cli.set_connection_timeout(2, 0);

    auto res1 = cli.Post("/start", req.dump(), "application/json");
    ASSERT_TRUE(res1);
    ASSERT_EQ(nlohmann::json::parse(res1->body)["success"], true);

    auto res2 = cli.Post("/start", req.dump(), "application/json");
    ASSERT_TRUE(res2);
    auto j = nlohmann::json::parse(res2->body);
    EXPECT_FALSE(j["success"]);
    EXPECT_EQ(j["error_message"], "VM already running");

    nlohmann::json stop_req = {{"vm_id", "test-vm-dup"}, {"pid", nlohmann::json::parse(res1->body)["pid"]}};
    cli.Post("/stop", stop_req.dump(), "application/json");
}

TEST_F(HttpApiTest, StopNonexistentVmReturnsError) {
    auto cli = makeClient();
    cli.set_connection_timeout(2, 0);

    nlohmann::json req = {{"vm_id", "nonexistent-vm"}, {"pid", 0}};
    auto res = cli.Post("/stop", req.dump(), "application/json");
    ASSERT_TRUE(res);
    EXPECT_EQ(res->status, 200);
    auto j = nlohmann::json::parse(res->body);
    EXPECT_FALSE(j["success"]);
    EXPECT_EQ(j["error_message"], "VM not found or not running");
}

TEST_F(HttpApiTest, PreviewNonexistentVmReturnsErrorInJson) {
    auto cli = makeClient();
    cli.set_connection_timeout(2, 0);

    auto res = cli.Post("/preview", "{\"vm_id\":\"nonexistent-vm\"}", "application/json");
    ASSERT_TRUE(res);
    EXPECT_EQ(res->status, 200);
    auto j = nlohmann::json::parse(res->body);
    EXPECT_FALSE(j["success"]);
    EXPECT_FALSE(j["error_message"].get<std::string>().empty());
}

TEST_F(HttpApiTest, PreviewInvalidJsonReturns400) {
    auto cli = makeClient();
    cli.set_connection_timeout(2, 0);

    auto res = cli.Post("/preview", "invalid", "application/json");
    ASSERT_TRUE(res);
    EXPECT_EQ(res->status, 400);
}

TEST_F(HttpApiTest, PreviewWithQmpSocketButNoSocketFileReturnsErrorInJson) {
    auto disk_path = (tmp_dir_ / "disk_preview.qcow2").string();
    std::ofstream(disk_path).close();

    auto qmp_path = (tmp_dir_ / "qemu-preview-test.qmp").string();
    nlohmann::json start_req = {
        {"vm_id", "preview-vm"},
        {"architecture", "x86_64"},
        {"cpu_cores", 2},
        {"ram_mb", 2048},
        {"primary_disk_path", disk_path},
        {"additional_disks", nlohmann::json::array()},
        {"iso_path", ""},
        {"network_type", "user"},
        {"vnc_port", 0},
        {"mac_address", ""},
        {"qmp_socket_path", qmp_path}
    };

    auto cli = makeClient();
    cli.set_connection_timeout(2, 0);

    auto start_res = cli.Post("/start", start_req.dump(), "application/json");
    ASSERT_TRUE(start_res) << start_res.error();
    ASSERT_EQ(start_res->status, 200);
    auto start_j = nlohmann::json::parse(start_res->body);
    ASSERT_TRUE(start_j["success"]) << start_j.dump();

    auto preview_res = cli.Post("/preview", "{\"vm_id\":\"preview-vm\"}", "application/json");
    ASSERT_TRUE(preview_res);
    EXPECT_EQ(preview_res->status, 200);
    auto j = nlohmann::json::parse(preview_res->body);
    EXPECT_FALSE(j["success"]);
    std::string err = j["error_message"];
    EXPECT_TRUE(err.find("socket") != std::string::npos || err.find("not found") != std::string::npos)
        << "Expected socket/not found in error, got: " << err;

    nlohmann::json stop_req = {{"vm_id", "preview-vm"}, {"pid", start_j["pid"]}};
    cli.Post("/stop", stop_req.dump(), "application/json");
}

}  // namespace
