cmake_minimum_required(VERSION 3.24)
project(kartpad_android_fixture LANGUAGES C CXX)

if(NOT ANDROID OR NOT CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
  message(FATAL_ERROR "KartPad A0 supports Android arm64-v8a only")
endif()
if(NOT DEFINED DAWN_ANDROID_ROOT OR DAWN_ANDROID_ROOT STREQUAL "")
  message(FATAL_ERROR "DAWN_ANDROID_ROOT must name the prepared pinned Dawn package")
endif()

find_package(Threads REQUIRED)
find_package(SDL3 REQUIRED CONFIG)
# The Android toolchain intentionally roots package discovery inside the NDK
# and Prefab sysroots. Dawn is a separately hash-verified host path, so include
# its relocatable config directly rather than weakening global root modes.
include("${DAWN_ANDROID_ROOT}/lib/cmake/Dawn/DawnConfig.cmake")
if(NOT TARGET dawn::webgpu_dawn)
  message(FATAL_ERROR "Pinned Dawn config did not define dawn::webgpu_dawn")
endif()

add_library(main SHARED fixture_main.cpp guest_memory_fixture.cpp)
target_compile_features(main PRIVATE cxx_std_20)
target_compile_options(main PRIVATE -Wall -Wextra -Werror -fvisibility=hidden)
target_link_libraries(main PRIVATE SDL3::SDL3 dawn::webgpu_dawn android log dl)

set_target_properties(main PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN YES)
