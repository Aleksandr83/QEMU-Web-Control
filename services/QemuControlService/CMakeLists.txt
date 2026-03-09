cmake_minimum_required(VERSION 3.15)
project(QemuControlService VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

include(FetchContent)
FetchContent_Declare(
  httplib
  GIT_REPOSITORY https://github.com/yhirose/cpp-httplib.git
  GIT_TAG v0.14.3
  GIT_SHALLOW TRUE
)
set(HTTPLIB_USE_OPENSSL_IF_AVAILABLE OFF CACHE BOOL "" FORCE)
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

set(PROTO_FILE "${CMAKE_CURRENT_SOURCE_DIR}/proto/qemu_control.proto")
protobuf_generate_grpc_cpp(PROTO_SRCS PROTO_HDRS ${PROTO_FILE})

add_executable(QemuControlService
  src/main.cpp
  src/config.cpp
  src/logger.cpp
  src/qemu_service_impl.cpp
  src/http_server.cpp
  src/vnc_proxy.cpp
  ${PROTO_SRCS}
)

target_include_directories(QemuControlService PRIVATE
  ${CMAKE_CURRENT_BINARY_DIR}
  ${CMAKE_CURRENT_BINARY_DIR}/proto
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${httplib_SOURCE_DIR}
  ${json_SOURCE_DIR}/single_include
)

target_link_libraries(QemuControlService PRIVATE
  gRPC::grpc++
  protobuf::libprotobuf
  Threads::Threads
)

install(TARGETS QemuControlService
  RUNTIME DESTINATION bin
)

FetchContent_Declare(
  googletest
  GIT_REPOSITORY https://github.com/google/googletest.git
  GIT_TAG v1.14.0
  GIT_SHALLOW TRUE
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

enable_testing()

add_executable(QemuControlService_test
  tests/config_test.cpp
  tests/http_api_test.cpp
)

target_include_directories(QemuControlService_test PRIVATE
  ${CMAKE_CURRENT_BINARY_DIR}
  ${CMAKE_CURRENT_BINARY_DIR}/proto
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/src
  ${httplib_SOURCE_DIR}
  ${json_SOURCE_DIR}/single_include
)

target_link_libraries(QemuControlService_test PRIVATE
  GTest::gtest_main
  gRPC::grpc++
  protobuf::libprotobuf
  Threads::Threads
)

target_sources(QemuControlService_test PRIVATE
  src/config.cpp
  src/logger.cpp
  src/qemu_service_impl.cpp
  src/http_server.cpp
  src/vnc_proxy.cpp
  ${PROTO_SRCS}
)

include(GoogleTest)
gtest_discover_tests(QemuControlService_test)
