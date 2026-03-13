#pragma once

#include "proto/qemu_control.grpc.pb.h"
#include "config.h"
#include "logger.h"
#include <grpcpp/grpcpp.h>
#include <mutex>
#include <unordered_map>
#include <vector>

namespace qemu {
namespace control {

class QemuServiceImpl : public QemuControl::Service {
public:
    QemuServiceImpl(Config* config, Logger* logger);

    grpc::Status StartVm(grpc::ServerContext* context,
                        const StartVmRequest* request,
                        StartVmResponse* response) override;

    grpc::Status StopVm(grpc::ServerContext* context,
                        const StopVmRequest* request,
                        StopVmResponse* response) override;

    grpc::Status GetVmStatus(grpc::ServerContext* context,
                             const GetVmStatusRequest* request,
                             GetVmStatusResponse* response) override;

    grpc::Status CapturePreview(grpc::ServerContext* context,
                               const CapturePreviewRequest* request,
                               CapturePreviewResponse* response) override;

    bool SendTextToVm(const std::string& vm_id, const std::string& uuid, const std::string& text,
                     const std::string& keyboard_layout, std::string* err_out);

    std::vector<std::string> getServiceLogs(int max_lines) const;
    bool clearServiceLog() const;

private:
    bool isRunning(int pid) const;
    std::string buildQemuCommand(const StartVmRequest* request, std::string* error_out = nullptr) const;
    bool doQmpScreendump(const std::string& socket_path, const std::string& out_path, std::string* err_out);
    bool doSendTextViaQmp(const std::string& socket_path, const std::string& text,
                         const std::string& keyboard_layout, std::string* err_out);

    Config* config_;
    Logger* logger_;
    std::mutex mutex_;
    std::unordered_map<std::string, int> vm_pids_;
    std::unordered_map<std::string, std::string> vm_qmp_sockets_;
};

}  // namespace control
}  // namespace qemu
