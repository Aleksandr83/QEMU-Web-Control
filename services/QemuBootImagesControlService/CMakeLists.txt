cmake_minimum_required(VERSION 3.15)
project(QemuBootImagesControlService VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

include(FetchContent)
FetchContent_Declare(
  httplib
  GIT_REPOSITORY https://github.com/yhirose/cpp-httplib.git
  GIT_TAG v0.14.3
  GIT_SHALLOW TRUE
)
set(HTTPLIB_USE_OPENSSL_IF_AVAILABLE OFF CACHE BOOL "" FORCE)
set(HTTPLIB_USE_ZLIB_IF_AVAILABLE OFF CACHE BOOL "" FORCE)
set(HTTPLIB_USE_BROTLI_IF_AVAILABLE OFF CACHE BOOL "" FORCE)
set(HTTPLIB_USE_ZSTD_IF_AVAILABLE OFF CACHE BOOL "" FORCE)
set(HTTPLIB_INSTALL OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(httplib)

FetchContent_Declare(
  json
  GIT_REPOSITORY https://github.com/nlohmann/json.git
  GIT_TAG v3.11.3
  GIT_SHALLOW TRUE
)
set(JSON_Install OFF CACHE BOOL "" FORCE)
set(JSON_BuildTests OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(json)

find_package(Protobuf REQUIRED)
find_package(gRPC CONFIG REQUIRED)
find_package(Threads REQUIRED)
find_package(OpenSSL REQUIRED)

find_program(GRPC_CPP_PLUGIN grpc_cpp_plugin REQUIRED)

function(protobuf_generate_grpc_cpp SRCS HDRS)
  set(${SRCS})
  set(${HDRS})
  set(PROTO_OUT "${CMAKE_CURRENT_BINARY_DIR}/proto")
  foreach(FIL ${ARGN})
    get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
    get_filename_component(FIL_WE ${FIL} NAME_WE)
    get_filename_component(FIL_DIR ${FIL} DIRECTORY)
    file(RELATIVE_PATH REL_PROTO_DIR "${CMAKE_CURRENT_SOURCE_DIR}" "${FIL_DIR}")
    if(NOT REL_PROTO_DIR)
      set(REL_PROTO_DIR ".")
    endif()
    set(GEN_DIR "${PROTO_OUT}/${REL_PROTO_DIR}")

    list(APPEND ${SRCS} "${GEN_DIR}/${FIL_WE}.pb.cc" "${GEN_DIR}/${FIL_WE}.grpc.pb.cc")
    list(APPEND ${HDRS} "${GEN_DIR}/${FIL_WE}.pb.h" "${GEN_DIR}/${FIL_WE}.grpc.pb.h")

    add_custom_command(
      OUTPUT "${GEN_DIR}/${FIL_WE}.pb.cc"
             "${GEN_DIR}/${FIL_WE}.pb.h"
             "${GEN_DIR}/${FIL_WE}.grpc.pb.cc"
             "${GEN_DIR}/${FIL_WE}.grpc.pb.h"
      COMMAND ${CMAKE_COMMAND} -E make_directory "${GEN_DIR}"
      COMMAND ${Protobuf_PROTOC_EXECUTABLE}
      ARGS --cpp_out=${PROTO_OUT}
           -I${CMAKE_CURRENT_SOURCE_DIR}
           -I${FIL_DIR}
           ${ABS_FIL}
      COMMAND ${Protobuf_PROTOC_EXECUTABLE}
      ARGS --grpc_out=${PROTO_OUT}
           --plugin=protoc-gen-grpc=${GRPC_CPP_PLUGIN}
           -I${CMAKE_CURRENT_SOURCE_DIR}
           -I${FIL_DIR}
           ${ABS_FIL}
      DEPENDS ${ABS_FIL}
      COMMENT "Generating protobuf and gRPC code for ${FIL_WE}")
  endforeach()
  set(${SRCS} ${${SRCS}} PARENT_SCOPE)
  set(${HDRS} ${${HDRS}} PARENT_SCOPE)
endfunction()

set(PROTO_FILE "${CMAKE_CURRENT_SOURCE_DIR}/proto/qemu_boot_images.proto")
protobuf_generate_grpc_cpp(PROTO_SRCS PROTO_HDRS ${PROTO_FILE})

add_executable(QemuBootImagesControlService
  src/main.cpp
  src/iso_service_impl.cpp
  src/config.cpp
  src/logger.cpp
  src/rate_limiter.cpp
  src/http_server.cpp
  src/move_operation.cpp
  ${PROTO_SRCS}
)

target_include_directories(QemuBootImagesControlService PRIVATE
  ${CMAKE_CURRENT_BINARY_DIR}
  ${CMAKE_CURRENT_BINARY_DIR}/proto
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${httplib_SOURCE_DIR}
  ${json_SOURCE_DIR}/single_include
)

target_link_libraries(QemuBootImagesControlService PRIVATE
  gRPC::grpc++
  protobuf::libprotobuf
  Threads::Threads
  OpenSSL::Crypto
)

find_package(GTest QUIET)
if(GTest_FOUND)
  add_executable(QemuBootImagesControlService_tests
    tests/test_iso_service.cpp
    tests/test_move_operation.cpp
    tests/test_rate_limiter.cpp
    tests/test_config.cpp
    src/iso_service_impl.cpp
    src/config.cpp
    src/logger.cpp
    src/rate_limiter.cpp
    src/move_operation.cpp
    ${PROTO_SRCS}
  )

  target_include_directories(QemuBootImagesControlService_tests PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}/proto
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/src
  )

  target_link_libraries(QemuBootImagesControlService_tests PRIVATE
    GTest::gtest
    GTest::gtest_main
    gRPC::grpc++
    protobuf::libprotobuf
    Threads::Threads
  )

  enable_testing()
  add_test(NAME QemuBootImagesControlService_tests COMMAND QemuBootImagesControlService_tests)
endif()

install(TARGETS QemuBootImagesControlService
  RUNTIME DESTINATION bin
)
