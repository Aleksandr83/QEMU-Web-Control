#include "config.h"
#include "http_server.h"
#include "logger.h"
#include "qemu_service_impl.h"
#include "vnc_proxy.h"
#include "proto/qemu_control.grpc.pb.h"
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
    std::string config_path = qemu::control::Config::default_config_path();
    if (argc >= 2) {
        config_path = argv[1];
    }

    auto& config = qemu::control::Config::instance();
    config.load(config_path);

    auto& logger = qemu::control::Logger::instance();
    logger.init(config.log_path(), qemu::control::Logger::Level::INFO);
    logger.info("QemuControlService loading config_path=" + config_path);

    std::string server_addr = config.listen_address() + ":" + std::to_string(config.port());
    logger.info("Service starting listen=" + server_addr);

    qemu::control::QemuServiceImpl service(&config, &logger);

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

    qemu::control::HttpServer http_server(&service, config.listen_address(), config.http_port());
    http_server.start();

    qemu::control::VncProxy vnc_proxy(&config, &logger);
    vnc_proxy.start();

    logger.info("QemuControlService started listening on " + server_addr);
    server->Wait();
    g_server = nullptr;

    vnc_proxy.stop();
    logger.info("QemuControlService shutting down");
    return 0;
}
