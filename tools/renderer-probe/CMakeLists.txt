cmake_minimum_required(VERSION 3.22)
project(KartPadRendererProbe LANGUAGES CXX)
find_package(Python3 REQUIRED COMPONENTS Interpreter)
find_package(Threads REQUIRED)
find_package(Dawn REQUIRED CONFIG NO_CMAKE_FIND_ROOT_PATH)
set(KARTPAD_AURORA_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/../../vendor/runtimes/android/aurora-main" CACHE PATH "Pinned Aurora source")
add_custom_command(OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/shader_helpers.h"
  COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/generate_shader.py"
    "${KARTPAD_AURORA_SOURCE}/lib/gx/shader.cpp" "${CMAKE_CURRENT_BINARY_DIR}/shader_helpers.h"
  DEPENDS generate_shader.py "${KARTPAD_AURORA_SOURCE}/lib/gx/shader.cpp" VERBATIM)
if(ANDROID)
  add_library(kartpad_renderer_probe SHARED probe.cpp "${CMAKE_CURRENT_BINARY_DIR}/shader_helpers.h")
else()
  add_executable(kartpad_renderer_probe probe.cpp "${CMAKE_CURRENT_BINARY_DIR}/shader_helpers.h")
endif()
target_compile_features(kartpad_renderer_probe PRIVATE cxx_std_20)
target_include_directories(kartpad_renderer_probe PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(kartpad_renderer_probe PRIVATE dawn::webgpu_dawn)

if(ANDROID)
  # Same probe for authorized adb development, including when the screen is locked.
  # Excluded from the APK and default build; this reads only synthetic inputs.
  add_executable(kartpad_renderer_probe_cli EXCLUDE_FROM_ALL probe.cpp "${CMAKE_CURRENT_BINARY_DIR}/shader_helpers.h")
  target_compile_definitions(kartpad_renderer_probe_cli PRIVATE KARTPAD_PROBE_CLI=1)
  target_compile_features(kartpad_renderer_probe_cli PRIVATE cxx_std_20)
  target_include_directories(kartpad_renderer_probe_cli PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
  target_link_libraries(kartpad_renderer_probe_cli PRIVATE dawn::webgpu_dawn)
endif()
