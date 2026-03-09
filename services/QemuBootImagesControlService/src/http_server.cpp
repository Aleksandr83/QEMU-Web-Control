#include "http_server.h"
#include "config.h"
#include "logger.h"
#include "move_operation.h"
#include <httplib.h>
#include <nlohmann/json.hpp>
#include <openssl/hmac.h>
#include <openssl/evp.h>
#include <sstream>
#include <cstdio>

namespace qemu {
namespace boot_images {

static std::string hmac_sha256_hex(const std::string& key, const std::string& data) {
    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int digest_len = 0;
    HMAC(EVP_sha256(), key.data(), static_cast<int>(key.size()),
         reinterpret_cast<const unsigned char*>(data.data()), data.size(),
         digest, &digest_len);
    std::string hex;
    hex.reserve(digest_len * 2);
    for (unsigned int i = 0; i < digest_len; ++i) {
        char buf[3];
        std::snprintf(buf, sizeof(buf), "%02x", digest[i]);
        hex += buf;
    }
    return hex;
}

static bool verify_auth(const httplib::Request& req, std::string& err_msg) {
    const std::string& api_key = Config::instance().api_key();
    if (api_key.empty()) return true;

    auto it_key = req.headers.find("X-API-Key");
    if (it_key == req.headers.end()) {
        err_msg = "Missing X-API-Key";
        return false;
    }
    if (it_key->second != api_key) {
        err_msg = "Invalid X-API-Key";
        return false;
    }

    auto it_sig = req.headers.find("X-Signature");
    if (it_sig == req.headers.end()) {
        err_msg = "Missing X-Signature";
        return false;
    }
    std::string expected = hmac_sha256_hex(api_key, req.body);
    if (it_sig->second != expected) {
        err_msg = "Invalid X-Signature";
        return false;
    }
    return true;
}

HttpServer::HttpServer(IsoServiceImpl* service, const std::string& host, uint16_t port)
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
}

void HttpServer::run() {
    httplib::Server svr;

    svr.Post("/delete", [this](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Content-Type", "application/json");
        res.set_header("Access-Control-Allow-Origin", "*");

        std::string auth_err;
        if (!verify_auth(req, auth_err)) {
            res.status = 401;
            res.set_content("{\"error\":\"" + auth_err + "\"}", "application/json");
            return;
        }

        std::string peer = req.remote_addr;
        if (peer.empty()) peer = "unknown";

        std::vector<std::string> paths;
        try {
            auto j = nlohmann::json::parse(req.body);
            if (j.contains("paths") && j["paths"].is_array()) {
                for (const auto& p : j["paths"]) {
                    if (p.is_string()) {
                        paths.push_back(p.get<std::string>());
                    }
                }
            }
        } catch (const nlohmann::json::exception&) {
            res.status = 400;
            res.set_content("{\"error\":\"Invalid JSON\"}", "application/json");
            return;
        }

        bool rate_limited = false;
        auto results = service_->deletePaths(paths, peer, &rate_limited);

        if (rate_limited) {
            res.status = 429;
            res.set_content("{\"error\":\"Rate limit exceeded\"}", "application/json");
            return;
        }

        nlohmann::json j_results = nlohmann::json::array();
        for (const auto& r : results) {
            nlohmann::json jr;
            jr["path"] = r.path;
            jr["success"] = r.success;
            jr["error_message"] = r.error_message;
            j_results.push_back(jr);
        }
        nlohmann::json j;
        j["results"] = j_results;
        res.set_content(j.dump(), "application/json");
    });

    svr.Get("/health", [](const httplib::Request&, httplib::Response& res) {
        res.set_header("Content-Type", "application/json");
        res.set_content("{\"status\":\"ok\"}", "application/json");
    });

    svr.Post("/move", [](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Content-Type", "application/json");
        res.set_header("Access-Control-Allow-Origin", "*");

        std::string auth_err;
        if (!verify_auth(req, auth_err)) {
            res.status = 401;
            res.set_content("{\"error\":\"" + auth_err + "\"}", "application/json");
            return;
        }

        std::string peer = req.remote_addr;
        if (peer.empty()) peer = "unknown";

        std::string operation_id, source_filename, destination_directory;
        try {
            auto j = nlohmann::json::parse(req.body);
            operation_id = j.value("operation_id", "");
            source_filename = j.value("source_filename", "");
            destination_directory = j.value("destination_directory", "");
        } catch (const nlohmann::json::exception&) {
            res.status = 400;
            res.set_content("{\"error\":\"Invalid JSON\"}", "application/json");
            return;
        }

        Logger::instance().info("IN request peer=" + peer + " method=MoveIso operation_id=" + operation_id +
            " source=" + source_filename + " dest=" + destination_directory);

        auto& cfg = Config::instance();
        std::string staging = cfg.staging_dir();
        if (staging.empty()) staging = "/tmp/iso_staging";

        std::string err = MoveOperationManager::instance().startMove(
            operation_id, source_filename, destination_directory,
            staging, cfg.allowed_directories());

        if (!err.empty()) {
            res.status = 400;
            Logger::instance().warn("OUT request peer=" + peer + " method=MoveIso operation_id=" + operation_id + " status=failed error=" + err);
            nlohmann::json j;
            j["error"] = err;
            res.set_content(j.dump(), "application/json");
            return;
        }
        Logger::instance().info("OUT request peer=" + peer + " method=MoveIso operation_id=" + operation_id + " status=started");
        nlohmann::json j;
        j["operation_id"] = operation_id;
        res.set_content(j.dump(), "application/json");
    });

    svr.Get("/progress/:id", [](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Content-Type", "application/json");
        res.set_header("Access-Control-Allow-Origin", "*");

        auto it = req.path_params.find("id");
        std::string operation_id = (it != req.path_params.end()) ? it->second : "";
        if (operation_id.empty()) {
            res.status = 400;
            res.set_content("{\"error\":\"Missing operation id\"}", "application/json");
            return;
        }
        Logger::instance().log(Logger::Level::DEBUG, "IN request peer=" + req.remote_addr + " method=GetProgress operation_id=" + operation_id);
        auto state = MoveOperationManager::instance().getProgress(operation_id);

        std::string status_str;
        switch (state.status) {
            case MoveStatus::Pending: status_str = "pending"; break;
            case MoveStatus::Running: status_str = "running"; break;
            case MoveStatus::Completed: status_str = "completed"; break;
            case MoveStatus::Cancelled: status_str = "cancelled"; break;
            case MoveStatus::Failed: status_str = "failed"; break;
            default: status_str = "unknown"; break;
        }

        nlohmann::json j;
        j["operation_id"] = operation_id;
        j["status"] = status_str;
        j["progress"] = state.progress;
        j["error_message"] = state.error_message;
        res.set_content(j.dump(), "application/json");
    });

    svr.Post("/cancel", [](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Content-Type", "application/json");
        res.set_header("Access-Control-Allow-Origin", "*");

        std::string auth_err;
        if (!verify_auth(req, auth_err)) {
            res.status = 401;
            res.set_content("{\"error\":\"" + auth_err + "\"}", "application/json");
            return;
        }

        std::string peer = req.remote_addr;
        if (peer.empty()) peer = "unknown";

        std::string operation_id;
        try {
            auto j = nlohmann::json::parse(req.body);
            operation_id = j.value("operation_id", "");
        } catch (const nlohmann::json::exception&) {
            res.status = 400;
            res.set_content("{\"error\":\"Invalid JSON\"}", "application/json");
            return;
        }

        Logger::instance().info("IN request peer=" + peer + " method=CancelMove operation_id=" + operation_id);
        MoveOperationManager::instance().cancel(operation_id);
        Logger::instance().info("OUT request peer=" + peer + " method=CancelMove operation_id=" + operation_id + " status=cancelled");
        nlohmann::json j;
        j["operation_id"] = operation_id;
        j["cancelled"] = true;
        res.set_content(j.dump(), "application/json");
    });

    std::string addr = host_ + ":" + std::to_string(port_);
    Logger::instance().info("HTTP server listening on " + addr);
    svr.listen(host_.c_str(), port_);
}

}  // namespace boot_images
}  // namespace qemu
