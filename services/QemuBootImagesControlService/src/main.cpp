#include "config.h"
#include "http_server.h"
#include "iso_service_impl.h"
#include "logger.h"
#include "rate_limiter.h"
#include "proto/qemu_boot_images.grpc.pb.h"
#include <grpcpp/grpcpp.h>
#include <csignal>
#include <iostream>
#include <memory>
#include <string>

static grpc::Server* g_server = nullptr;

static void signal_handler(int) {
    if (g_server) {
        g_server->Shutdown();
    }
}

int main(int argc, char* argv[]) {
    std::string config_path = qemu::boot_images::Config::default_config_path();
    if (argc >= 2) {
        config_path = argv[1];
    }

    auto& config = qemu::boot_images::Config::instance();
    config.load(config_path);

    auto& logger = qemu::boot_images::Logger::instance();
    logger.init(config.log_path(), qemu::boot_images::Logger::Level::INFO);
    logger.info("Service loading config_path=" + config_path);

    qemu::boot_images::RateLimiter rate_limiter(
        config.rate_limit_max_requests(),
        std::chrono::seconds(config.rate_limit_window_sec()));

    std::string server_addr = config.listen_address() + ":" + std::to_string(config.port());
    logger.info("Service starting listen=" + server_addr +
                " rate_limit=" + std::to_string(config.rate_limit_max_requests()) +
                "/" + std::to_string(config.rate_limit_window_sec()) + "s");

    qemu::boot_images::IsoServiceImpl service(
        config.allowed_directories(), &logger, &rate_limiter);

    grpc::ServerBuilder builder;
    builder.AddListeningPort(server_addr, grpc::InsecureServerCredentials());
    builder.RegisterService(&service);

    std::unique_ptr<grpc::Server> server(builder.BuildAndStart());
    if (!server) {
        logger.error("Failed to start gRPC server on " + server_addr);
        return 1;
    }

    g_server = server.get();
    std::signal(SIGINT, signal_handler);
    std::signal(SIGTERM, signal_handler);

    qemu::boot_images::HttpServer http_server(
        &service, config.listen_address(), config.http_port());
    http_server.start();

    logger.info("Service started listening on " + server_addr);
    server->Wait();
    g_server = nullptr;

    logger.info("Service shutting down");
    return 0;
}
