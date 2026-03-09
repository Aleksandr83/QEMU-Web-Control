#pragma once

#include "proto/qemu_boot_images.grpc.pb.h"
#include <grpcpp/grpcpp.h>
#include <string>
#include <vector>

namespace qemu {
namespace boot_images {

struct DeleteResult {
    std::string path;
    bool success = false;
    std::string error_message;
};

class Logger;
class RateLimiter;

class IsoServiceImpl final : public QemuBootImagesControl::Service {
public:
    IsoServiceImpl(const std::vector<std::string>& allowed_dirs,
                  Logger* logger,
                  RateLimiter* rate_limiter);

    grpc::Status DeleteIso(grpc::ServerContext* context,
                          const DeleteIsoRequest* request,
                          DeleteIsoResponse* response) override;

    grpc::Status MoveIso(grpc::ServerContext* context,
                        const MoveIsoRequest* request,
                        MoveIsoResponse* response) override;

    grpc::Status GetProgressOperation(grpc::ServerContext* context,
                                      const GetProgressOperationRequest* request,
                                      GetProgressOperationResponse* response) override;

    grpc::Status CancelMoveOperation(grpc::ServerContext* context,
                                    const CancelMoveOperationRequest* request,
                                    CancelMoveOperationResponse* response) override;

    std::vector<DeleteResult> deletePaths(const std::vector<std::string>& paths,
                                          const std::string& peer,
                                          bool* rate_limited = nullptr);

private:
    bool is_allowed_path(const std::string& path) const;
    std::string resolve_path(const std::string& path) const;
    static std::string extract_peer(const grpc::ServerContext* context);

    std::vector<std::string> allowed_dirs_;
    Logger* logger_;
    RateLimiter* rate_limiter_;
};

}  // namespace boot_images
}  // namespace qemu
