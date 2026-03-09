#pragma once

#include <cstdint>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace qemu {
namespace boot_images {

enum class MoveStatus {
    Pending,
    Running,
    Completed,
    Cancelled,
    Failed,
};

struct MoveOperationState {
    MoveStatus status = MoveStatus::Pending;
    int progress = 0;
    std::string error_message;
    std::string source_path;
    std::string dest_path;
};

class MoveOperationManager {
public:
    static MoveOperationManager& instance();

    std::string startMove(const std::string& operation_id,
                          const std::string& source_filename,
                          const std::string& destination_directory,
                          const std::string& staging_dir,
                          const std::vector<std::string>& allowed_dirs);

    void cancel(const std::string& operation_id);
    bool isCancelled(const std::string& operation_id) const;
    MoveOperationState getProgress(const std::string& operation_id) const;
    void runMove(const std::string& operation_id);

private:
    MoveOperationManager() = default;
    bool is_allowed_destination(const std::string& path,
                                const std::vector<std::string>& allowed_dirs) const;

    mutable std::mutex mutex_;
    std::unordered_map<std::string, MoveOperationState> operations_;
    std::unordered_map<std::string, bool> cancel_flags_;
};

}  // namespace boot_images
}  // namespace qemu
