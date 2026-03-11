#include "http_server.h"
#include "config.h"
#include "logger.h"
#include "proto/qemu_control.grpc.pb.h"
#include <httplib.h>
#include <nlohmann/json.hpp>
#include <sstream>

namespace qemu {
namespace control {

HttpServer::HttpServer(QemuServiceImpl* service, const std::string& host, uint16_t port)
    : service_(service), host_(host), port_(port) {}

HttpServer::~HttpServer() {
    stop();
}

void HttpServer::start() {
    if (running_) return;
    running_ = true;
    thread_ = std::make_unique<std::thread>(&HttpServer::run, this);
}

void HttpServer::stop() {
    running_ = false;
    if (server_) {
        server_->stop();
    }
    if (thread_ && thread_->joinable()) {
        thread_->join();
    }
}

void HttpServer::run() {
    server_ = std::make_unique<httplib::Server>();

    server_->Post("/start", [this](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Content-Type", "application/json");
        StartVmRequest pb_req;
        StartVmResponse pb_res;
        try {
            auto j = nlohmann::json::parse(req.body);
            pb_req.set_vm_id(j.value("vm_id", ""));
            pb_req.set_architecture(j.value("architecture", "x86_64"));
            pb_req.set_cpu_cores(j.value("cpu_cores", 2));
            pb_req.set_ram_mb(j.value("ram_mb", 2048));
            pb_req.set_primary_disk_path(j.value("primary_disk_path", ""));
            pb_req.set_iso_path(j.value("iso_path", ""));
            pb_req.set_network_type(j.value("network_type", "user"));
            pb_req.set_vnc_port(j.value("vnc_port", 0));
            pb_req.set_mac_address(j.value("mac_address", ""));
            pb_req.set_qmp_socket_path(j.value("qmp_socket_path", ""));
            pb_req.set_enable_kvm(j.value("enable_kvm", false));
            if (j.contains("additional_disks") && j["additional_disks"].is_array()) {
                for (const auto& d : j["additional_disks"]) {
                    if (d.is_string()) {
                        pb_req.add_additional_disks(d.get<std::string>());
                    }
                }
            }
        } catch (const nlohmann::json::exception& e) {
            res.status = 400;
            res.set_content("{\"success\":false,\"error_message\":\"Invalid JSON: " + std::string(e.what()) + "\"}", "application/json");
            return;
        }

        grpc::ServerContext ctx;
        grpc::Status st = service_->StartVm(&ctx, &pb_req, &pb_res);

        nlohmann::json j;
        j["success"] = pb_res.success();
        j["pid"] = pb_res.pid();
        j["error_message"] = pb_res.error_message();
        res.status = st.ok() ? 200 : 500;
        res.set_content(j.dump(), "application/json");
        Logger::instance().info("POST /start vm_id=" + pb_req.vm_id() + " -> " + std::to_string(res.status) + (pb_res.success() ? " pid=" + std::to_string(pb_res.pid()) : " err=" + pb_res.error_message()));
    });

    server_->Post("/stop", [this](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Content-Type", "application/json");
        StopVmRequest pb_req;
        StopVmResponse pb_res;
        try {
            auto j = nlohmann::json::parse(req.body);
            pb_req.set_vm_id(j.value("vm_id", ""));
            pb_req.set_pid(j.value("pid", 0));
        } catch (const nlohmann::json::exception& e) {
            res.status = 400;
            res.set_content("{\"success\":false,\"error_message\":\"Invalid JSON\"}", "application/json");
            return;
        }

        grpc::ServerContext ctx;
        grpc::Status st = service_->StopVm(&ctx, &pb_req, &pb_res);

        nlohmann::json j;
        j["success"] = pb_res.success();
        j["error_message"] = pb_res.error_message();
        res.status = st.ok() ? 200 : 500;
        res.set_content(j.dump(), "application/json");
        Logger::instance().info("POST /stop vm_id=" + pb_req.vm_id() + " -> " + std::to_string(res.status) + (pb_res.success() ? " ok" : " err=" + pb_res.error_message()));
    });

    server_->Post("/status", [this](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Content-Type", "application/json");
        GetVmStatusRequest pb_req;
        GetVmStatusResponse pb_res;
        try {
            auto j = nlohmann::json::parse(req.body);
            pb_req.set_vm_id(j.value("vm_id", ""));
        } catch (const nlohmann::json::exception&) {
            res.status = 400;
            res.set_content("{\"error\":\"Invalid JSON\"}", "application/json");
            return;
        }

        grpc::ServerContext ctx;
        grpc::Status st = service_->GetVmStatus(&ctx, &pb_req, &pb_res);

        nlohmann::json j;
        j["running"] = pb_res.running();
        j["pid"] = pb_res.pid();
        j["error_message"] = pb_res.error_message();
        res.status = st.ok() ? 200 : 500;
        res.set_content(j.dump(), "application/json");
    });

    server_->Post("/preview", [this](const httplib::Request& req, httplib::Response& res) {
        CapturePreviewRequest pb_req;
        CapturePreviewResponse pb_res;
        try {
            auto j = nlohmann::json::parse(req.body);
            pb_req.set_vm_id(j.value("vm_id", ""));
            pb_req.set_uuid(j.value("uuid", ""));
        } catch (const nlohmann::json::exception&) {
            res.status = 400;
            res.set_content("{\"success\":false,\"error_message\":\"Invalid JSON\"}", "application/json");
            return;
        }

        grpc::ServerContext ctx;
        grpc::Status st = service_->CapturePreview(&ctx, &pb_req, &pb_res);

        if (!st.ok()) {
            res.status = 500;
            res.set_content("{\"success\":false,\"error_message\":\"Internal error\"}", "application/json");
            return;
        }
        if (!pb_res.success()) {
            Logger::instance().warn("POST /preview vm_id=" + pb_req.vm_id() + " err=" + pb_res.error_message());
            nlohmann::json j;
            j["success"] = false;
            j["error_message"] = pb_res.error_message();
            res.set_header("Content-Type", "application/json");
            res.set_content(j.dump(), "application/json");
            return;
        }
        res.set_header("Content-Type", "image/png");
        res.set_content(pb_res.image_data(), "image/png");
        Logger::instance().info("POST /preview vm_id=" + pb_req.vm_id() + " -> 200 size=" + std::to_string(pb_res.image_data().size()));
    });

    server_->Get("/health", [](const httplib::Request&, httplib::Response& res) {
        res.set_header("Content-Type", "application/json");
        res.set_content("{\"status\":\"ok\"}", "application/json");
    });

    server_->Get("/", [](const httplib::Request&, httplib::Response& res) {
        res.set_header("Content-Type", "text/html; charset=utf-8");
        res.set_content(
            "<!DOCTYPE html><html><head><meta charset='utf-8'>"
            "<title>QemuControlService</title>"
            "<style>body{font-family:sans-serif;display:flex;align-items:center;justify-content:center;"
            "height:100vh;margin:0;background:#0f172a;color:#94a3b8;}"
            ".box{text-align:center;padding:2rem;border:1px solid #334155;border-radius:0.5rem;}"
            "h1{color:#22d3ee;margin-bottom:0.5rem;}p{margin:0;font-size:0.9rem;}"
            "</style></head><body><div class='box'>"
            "<h1>QemuControlService</h1>"
            "<p>Certificate accepted. You can close this tab and return to the application.</p>"
            "</div></body></html>",
            "text/html"
        );
    });

    std::string addr = host_ + ":" + std::to_string(port_);
    Logger::instance().info("HTTP server listening on " + addr);
    server_->listen(host_.c_str(), port_);
}

}  // namespace control
}  // namespace qemu
