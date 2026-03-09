#include "move_operation.h"
#include <algorithm>
#include <filesystem>
#include <fstream>
#include <thread>
#include <vector>

namespace fs = std::filesystem;

namespace qemu {
namespace boot_images {

MoveOperationManager& MoveOperationManager::instance() {
    static MoveOperationManager inst;
    return inst;
}

static std::string resolve_path(const std::string& path) {
    std::error_code ec;
    fs::path p(path);
    fs::path canonical = fs::weakly_canonical(p, ec);
    if (ec) return "";
    return canonical.string();
}

bool MoveOperationManager::is_allowed_destination(
    const std::string& path,
    const std::vector<std::string>& allowed_dirs) const {
    std::string resolved = resolve_path(path);
    if (resolved.empty()) return false;

    std::string dir = fs::path(resolved).parent_path().string();
    std::string dir_resolved = resolve_path(dir);
    if (dir_resolved.empty()) return false;

    for (const auto& allowed : allowed_dirs) {
        std::string allowed_resolved = resolve_path(allowed);
        if (allowed_resolved.empty()) continue;
        if (dir_resolved == allowed_resolved) return true;
        std::string prefix = allowed_resolved;
        if (prefix.back() != '/') prefix += "/";
        if (dir_resolved.size() >= prefix.size() &&
            dir_resolved.compare(0, prefix.size(), prefix) == 0) {
            return true;
        }
    }
    return false;
}

std::string MoveOperationManager::startMove(
    const std::string& operation_id,
    const std::string& source_filename,
    const std::string& destination_directory,
    const std::string& staging_dir,
    const std::vector<std::string>& allowed_dirs) {
    if (operation_id.empty() || source_filename.empty() ||
        destination_directory.empty() || staging_dir.empty()) {
        return "Missing required parameters";
    }

    if (source_filename.find('/') != std::string::npos ||
        source_filename.find("..") != std::string::npos) {
        return "Invalid source filename";
    }

    std::string src_path = staging_dir;
    if (src_path.back() != '/') src_path += "/";
    src_path += source_filename;

    std::string dest_dir = destination_directory;
    while (!dest_dir.empty() && dest_dir.back() == '/') dest_dir.pop_back();
    std::string dest_path = dest_dir + "/" + source_filename;

    std::error_code ec;
    if (!fs::exists(src_path, ec) || ec) {
        return "Source file does not exist: " + src_path;
    }
    if (!fs::is_regular_file(src_path, ec)) {
        return "Source is not a regular file";
    }

    if (!is_allowed_destination(dest_path, allowed_dirs)) {
        return "Destination not in allowed directories";
    }

    {
        std::lock_guard<std::mutex> lock(mutex_);
        if (operations_.count(operation_id)) {
            return "Operation ID already exists";
        }
        MoveOperationState state;
        state.status = MoveStatus::Pending;
        state.progress = 0;
        state.source_path = src_path;
        state.dest_path = dest_path;
        operations_[operation_id] = state;
        cancel_flags_[operation_id] = false;
    }

    std::thread t(&MoveOperationManager::runMove, this, operation_id);
    t.detach();

    return "";
}

void MoveOperationManager::cancel(const std::string& operation_id) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = cancel_flags_.find(operation_id);
    if (it != cancel_flags_.end()) {
        it->second = true;
    }
}

bool MoveOperationManager::isCancelled(const std::string& operation_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = cancel_flags_.find(operation_id);
    return it != cancel_flags_.end() && it->second;
}

MoveOperationState MoveOperationManager::getProgress(
    const std::string& operation_id) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = operations_.find(operation_id);
    if (it == operations_.end()) {
        MoveOperationState empty;
        empty.status = MoveStatus::Failed;
        empty.error_message = "Operation not found";
        return empty;
    }
    return it->second;
}

void MoveOperationManager::runMove(const std::string& operation_id) {
    std::string src_path;
    std::string dest_path;
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = operations_.find(operation_id);
        if (it == operations_.end()) return;
        it->second.status = MoveStatus::Running;
        src_path = it->second.source_path;
        dest_path = it->second.dest_path;
    }

    std::error_code ec;
    auto size = fs::file_size(src_path, ec);
    if (ec || size == 0) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = operations_.find(operation_id);
        if (it != operations_.end()) {
            it->second.status = MoveStatus::Failed;
            it->second.error_message = "Cannot get file size";
        }
        return;
    }

    std::ifstream in(src_path, std::ios::binary);
    if (!in) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = operations_.find(operation_id);
        if (it != operations_.end()) {
            it->second.status = MoveStatus::Failed;
            it->second.error_message = "Cannot open source file";
        }
        return;
    }

    std::ofstream out(dest_path, std::ios::binary | std::ios::trunc);
    if (!out) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = operations_.find(operation_id);
        if (it != operations_.end()) {
            it->second.status = MoveStatus::Failed;
            it->second.error_message = "Cannot create destination file";
        }
        return;
    }

    const size_t chunk_size = 1024 * 1024;
    std::vector<char> buf(chunk_size);
    size_t total_copied = 0;

    while (in && out) {
        if (isCancelled(operation_id)) {
            out.close();
            fs::remove(dest_path, ec);
            std::lock_guard<std::mutex> lock(mutex_);
            auto it = operations_.find(operation_id);
            if (it != operations_.end()) {
                it->second.status = MoveStatus::Cancelled;
                it->second.progress = 0;
            }
            return;
        }

        in.read(buf.data(), chunk_size);
        size_t got = in.gcount();
        if (got == 0) break;

        out.write(buf.data(), got);
        if (!out) {
            std::lock_guard<std::mutex> lock(mutex_);
            auto it = operations_.find(operation_id);
            if (it != operations_.end()) {
                it->second.status = MoveStatus::Failed;
                it->second.error_message = "Write error";
            }
            out.close();
            fs::remove(dest_path, ec);
            return;
        }

        total_copied += got;
        int pct = static_cast<int>((total_copied * 100) / size);
        if (pct > 100) pct = 100;

        std::lock_guard<std::mutex> lock(mutex_);
        auto it = operations_.find(operation_id);
        if (it != operations_.end()) {
            it->second.progress = pct;
        }
    }

    in.close();
    out.close();

    if (isCancelled(operation_id)) {
        fs::remove(dest_path, ec);
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = operations_.find(operation_id);
        if (it != operations_.end()) {
            it->second.status = MoveStatus::Cancelled;
            it->second.progress = 0;
        }
        return;
    }

    if (total_copied != size) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = operations_.find(operation_id);
        if (it != operations_.end()) {
            it->second.status = MoveStatus::Failed;
            it->second.error_message = "Copy incomplete";
        }
        fs::remove(dest_path, ec);
        return;
    }

    fs::remove(src_path, ec);

    std::lock_guard<std::mutex> lock(mutex_);
    auto it = operations_.find(operation_id);
    if (it != operations_.end()) {
        it->second.status = MoveStatus::Completed;
        it->second.progress = 100;
    }
}

}  // namespace boot_images
}  // namespace qemu
