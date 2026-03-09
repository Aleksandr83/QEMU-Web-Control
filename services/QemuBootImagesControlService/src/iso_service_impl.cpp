#include "iso_service_impl.h"
#include "config.h"
#include "logger.h"
#include "move_operation.h"
#include "rate_limiter.h"
#include <algorithm>
#include <filesystem>

namespace fs = std::filesystem;

namespace qemu {
namespace boot_images {

IsoServiceImpl::IsoServiceImpl(const std::vector<std::string>& allowed_dirs,
                               Logger* logger,
                               RateLimiter* rate_limiter)
    : allowed_dirs_(allowed_dirs), logger_(logger), rate_limiter_(rate_limiter) {}

std::string IsoServiceImpl::extract_peer(const grpc::ServerContext* context) {
    if (!context) return "unknown";
    std::string peer = context->peer();
    if (peer.empty()) return "unknown";
    size_t first = peer.find(':');
    if (first == std::string::npos) return peer;
    std::string after_prefix = peer.substr(first + 1);
    size_t last_colon = after_prefix.rfind(':');
    if (last_colon != std::string::npos && last_colon > 0) {
        return after_prefix.substr(0, last_colon);
    }
    return after_prefix.empty() ? peer : after_prefix;
}

std::string IsoServiceImpl::resolve_path(const std::string& path) const {
    std::error_code ec;
    fs::path p(path);
    fs::path canonical = fs::weakly_canonical(p, ec);
    if (ec) return "";
    return canonical.string();
}

bool IsoServiceImpl::is_allowed_path(const std::string& path) const {
    std::string resolved = resolve_path(path);
    if (resolved.empty()) return false;

    std::string lower = resolved;
    std::transform(lower.begin(), lower.end(), lower.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    if (lower.size() < 4 || lower.substr(lower.size() - 4) != ".iso") {
        return false;
    }

    for (const auto& dir : allowed_dirs_) {
        std::string dir_resolved = resolve_path(dir);
        if (dir_resolved.empty()) continue;

        if (resolved == dir_resolved) return false;
        std::string prefix = dir_resolved;
        if (prefix.back() != '/') prefix += "/";
        if (resolved.size() > prefix.size() &&
            resolved.compare(0, prefix.size(), prefix) == 0) {
            return true;
        }
    }
    return false;
}

std::vector<DeleteResult> IsoServiceImpl::deletePaths(const std::vector<std::string>& paths,
                                                       const std::string& peer,
                                                       bool* rate_limited) {
    std::vector<DeleteResult> results;
    if (rate_limited) *rate_limited = false;

    size_t path_count = 0;
    for (const auto& p : paths) {
        if (!p.empty()) ++path_count;
    }

    if (logger_) {
        logger_->info("IN request peer=" + peer + " method=DeleteIso paths_count=" +
                     std::to_string(path_count));
    }

    if (rate_limiter_ && !rate_limiter_->allow(peer)) {
        if (logger_) {
            logger_->warn("OUT request peer=" + peer + " method=DeleteIso status=rate_limited");
        }
        if (rate_limited) *rate_limited = true;
        return results;
    }

    int success_count = 0;
    int fail_count = 0;

    for (const auto& path : paths) {
        if (path.empty()) continue;

        DeleteResult r;
        r.path = path;

        if (!is_allowed_path(path)) {
            r.success = false;
            r.error_message = "Path not in allowed ISO directories";
            ++fail_count;
            results.push_back(r);
            continue;
        }

        std::error_code ec;
        if (!fs::exists(path, ec) || ec) {
            r.success = false;
            r.error_message = "File does not exist";
            ++fail_count;
            results.push_back(r);
            continue;
        }

        if (!fs::is_regular_file(path, ec)) {
            r.success = false;
            r.error_message = "Not a regular file";
            ++fail_count;
            results.push_back(r);
            continue;
        }

        if (fs::remove(path, ec)) {
            r.success = true;
            ++success_count;
        } else {
            r.success = false;
            r.error_message = ec.message();
            ++fail_count;
        }
        results.push_back(r);
    }

    if (logger_) {
        logger_->info("OUT request peer=" + peer + " method=DeleteIso success=" +
                     std::to_string(success_count) + " failed=" + std::to_string(fail_count));
    }

    return results;
}

grpc::Status IsoServiceImpl::DeleteIso(grpc::ServerContext* context,
                                      const DeleteIsoRequest* request,
                                      DeleteIsoResponse* response) {
    std::string peer = extract_peer(context);
    std::vector<std::string> paths(request->paths().begin(), request->paths().end());
    bool rate_limited = false;
    auto results = deletePaths(paths, peer, &rate_limited);

    if (rate_limited) {
        return grpc::Status(grpc::StatusCode::RESOURCE_EXHAUSTED, "Rate limit exceeded");
    }

    for (const auto& r : results) {
        auto* proto = response->add_results();
        proto->set_path(r.path);
        proto->set_success(r.success);
        proto->set_error_message(r.error_message);
    }

    return grpc::Status::OK;
}

grpc::Status IsoServiceImpl::MoveIso(grpc::ServerContext* context,
                                    const MoveIsoRequest* request,
                                    MoveIsoResponse* response) {
    std::string peer = extract_peer(context);
    if (logger_) {
        logger_->info("IN request peer=" + peer + " method=MoveIso operation_id=" +
                     request->operation_id());
    }

    auto& cfg = Config::instance();
    std::string staging = cfg.staging_dir();
    if (staging.empty()) staging = "/tmp/iso_staging";

    std::string err = MoveOperationManager::instance().startMove(
        request->operation_id(),
        request->source_filename(),
        request->destination_directory(),
        staging,
        cfg.allowed_directories());

    if (!err.empty()) {
        response->set_error_message(err);
        return grpc::Status::OK;
    }
    return grpc::Status::OK;
}

grpc::Status IsoServiceImpl::GetProgressOperation(grpc::ServerContext* context,
                                                  const GetProgressOperationRequest* request,
                                                  GetProgressOperationResponse* response) {
    if (logger_) {
        logger_->log(Logger::Level::DEBUG, "IN request peer=" + extract_peer(context) + " method=GetProgressOperation operation_id=" + request->operation_id());
    }
    auto state = MoveOperationManager::instance().getProgress(request->operation_id());

    std::string status_str;
    switch (state.status) {
        case MoveStatus::Pending: status_str = "pending"; break;
        case MoveStatus::Running: status_str = "running"; break;
        case MoveStatus::Completed: status_str = "completed"; break;
        case MoveStatus::Cancelled: status_str = "cancelled"; break;
        case MoveStatus::Failed: status_str = "failed"; break;
        default: status_str = "unknown"; break;
    }

    response->set_status(status_str);
    response->set_progress(state.progress);
    response->set_error_message(state.error_message);
    return grpc::Status::OK;
}

grpc::Status IsoServiceImpl::CancelMoveOperation(grpc::ServerContext* context,
                                                const CancelMoveOperationRequest* request,
                                                CancelMoveOperationResponse* response) {
    if (logger_) {
        logger_->info("IN request peer=" + extract_peer(context) + " method=CancelMoveOperation operation_id=" + request->operation_id());
    }
    MoveOperationManager::instance().cancel(request->operation_id());
    response->set_cancelled(true);
    return grpc::Status::OK;
}

}  // namespace boot_images
}  // namespace qemu
