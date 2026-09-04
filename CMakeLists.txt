cmake_minimum_required(VERSION 3.27)

project(KartPad VERSION 0.2.0 LANGUAGES C CXX)

include(CTest)

add_executable(kartpad_semantics_contract runtime/tests/semantics_contract.cpp)
target_include_directories(kartpad_semantics_contract PRIVATE runtime/include)
target_compile_features(kartpad_semantics_contract PRIVATE cxx_std_20)
target_compile_options(kartpad_semantics_contract PRIVATE
  -Wall -Wextra -Wpedantic -Werror -fno-fast-math -ffp-contract=off -ffp-model=strict
)
add_test(NAME kartpad_semantics_contract COMMAND kartpad_semantics_contract)

add_executable(kartpad_android_gamepad_contract
  runtime/tests/android_gamepad_contract_tests.cpp)
target_include_directories(kartpad_android_gamepad_contract PRIVATE runtime/include)
target_compile_features(kartpad_android_gamepad_contract PRIVATE cxx_std_20)
target_compile_options(kartpad_android_gamepad_contract PRIVATE
  -Wall -Wextra -Wpedantic -Werror)
add_test(NAME kartpad.android.gamepad-contract
  COMMAND kartpad_android_gamepad_contract)

option(MKW_PRODUCT_BASE "Build the original-disc base product" ON)
option(MKW_PRODUCT_RETRO_REWIND "Build the Retro Rewind product" OFF)
option(MKW_BUILD_MACOS "Build the native macOS host" OFF)
option(MKW_BUILD_IOS_SIMULATOR "Build the iOS Simulator host" OFF)
option(MKW_BUILD_IOS_DEVICE "Build the physical iOS/iPadOS host" OFF)
option(MKW_BUILD_AURORA_G7_FIXTURES "Build the pinned Aurora/Dawn G7 validation fixtures" OFF)
option(MKW_GUEST_MEMORY_FLAT "Select the flat guest-memory backend" OFF)
option(MKW_GUEST_MEMORY_CHECKED "Select the checked guest-memory backend" ON)

if(APPLE AND CMAKE_SYSTEM_NAME MATCHES "^(Darwin|iOS)$")
  set(MKW_HOST_DARWIN ON)
  set(MKW_HOST_WINDOWS OFF)
  if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    if(MKW_BUILD_IOS_SIMULATOR OR MKW_BUILD_IOS_DEVICE)
      message(FATAL_ERROR "iOS host options require an iOS toolchain/sysroot")
    endif()
    set(MKW_BUILD_MACOS ON)
  else()
    set(MKW_BUILD_MACOS OFF)
    if(MKW_BUILD_IOS_SIMULATOR AND MKW_BUILD_IOS_DEVICE)
      message(FATAL_ERROR "Select exactly one iOS host kind")
    endif()
    if(NOT MKW_BUILD_IOS_SIMULATOR AND NOT MKW_BUILD_IOS_DEVICE)
      message(FATAL_ERROR
        "Select MKW_BUILD_IOS_SIMULATOR or MKW_BUILD_IOS_DEVICE for iOS")
    endif()
  endif()
elseif(WIN32)
  set(MKW_HOST_DARWIN OFF)
  set(MKW_HOST_WINDOWS ON)
else()
  message(FATAL_ERROR "KartPad currently supports Darwin and Windows host graphs only")
endif()

set(MKW_HOST_PROCESSOR "${CMAKE_SYSTEM_PROCESSOR}")
if(NOT MKW_HOST_PROCESSOR AND CMAKE_OSX_ARCHITECTURES)
  list(LENGTH CMAKE_OSX_ARCHITECTURES MKW_OSX_ARCHITECTURE_COUNT)
  if(NOT MKW_OSX_ARCHITECTURE_COUNT EQUAL 1)
    message(FATAL_ERROR "KartPad requires one explicit Apple architecture")
  endif()
  set(MKW_HOST_PROCESSOR "${CMAKE_OSX_ARCHITECTURES}")
endif()

if(MKW_HOST_PROCESSOR MATCHES "^(arm64|aarch64|ARM64)$")
  set(MKW_HOST_ARM64 ON)
  set(MKW_HOST_X86_64 OFF)
elseif(MKW_HOST_PROCESSOR MATCHES "^(x86_64|AMD64|amd64)$")
  set(MKW_HOST_ARM64 OFF)
  set(MKW_HOST_X86_64 ON)
else()
  message(FATAL_ERROR "Unsupported host architecture: ${MKW_HOST_PROCESSOR}")
endif()

if(MKW_HOST_DARWIN)
  set(MKW_RENDER_METAL ON)
  set(MKW_RENDER_D3D12 OFF)
  set(MKW_RENDER_VULKAN OFF)
else()
  set(MKW_RENDER_METAL OFF)
  set(MKW_RENDER_D3D12 ON)
  set(MKW_RENDER_VULKAN OFF)
endif()

if(MKW_GUEST_MEMORY_FLAT AND MKW_GUEST_MEMORY_CHECKED)
  message(FATAL_ERROR "Select exactly one guest-memory backend")
endif()
if(NOT MKW_GUEST_MEMORY_FLAT AND NOT MKW_GUEST_MEMORY_CHECKED)
  message(FATAL_ERROR "Select exactly one guest-memory backend")
endif()

execute_process(
  COMMAND git rev-parse HEAD
  WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
  OUTPUT_VARIABLE KARTPAD_GIT_REVISION
  OUTPUT_STRIP_TRAILING_WHITESPACE
  ERROR_QUIET
)
if(NOT KARTPAD_GIT_REVISION)
  set(KARTPAD_GIT_REVISION "unknown")
endif()

set(KARTPAD_MANIFEST_DIR "${CMAKE_BINARY_DIR}/manifest")
file(MAKE_DIRECTORY "${KARTPAD_MANIFEST_DIR}")
configure_file(
  "${CMAKE_SOURCE_DIR}/cmake/build-manifest.json.in"
  "${KARTPAD_MANIFEST_DIR}/kartpad-build-manifest.json"
  @ONLY
)

add_library(kartpad_host STATIC)
if(MKW_HOST_DARWIN)
  enable_language(OBJCXX)
  target_sources(kartpad_host PRIVATE
    runtime/src/platform/host_clock.cpp
    runtime/src/platform/host_files.cpp
    runtime/src/platform/host_paths.cpp
  )
elseif(MKW_HOST_WINDOWS)
  target_sources(kartpad_host PRIVATE
    runtime/src/platform/host_clock_windows.cpp
    runtime/src/platform/host_files_windows.cpp
    runtime/src/platform/host_paths_windows.cpp
  )
endif()

add_library(kartpad_memory STATIC runtime/src/memory/checked_guest_memory.cpp)
target_include_directories(kartpad_memory PUBLIC runtime/include)
target_compile_features(kartpad_memory PUBLIC cxx_std_20)
target_compile_options(kartpad_memory PRIVATE -Wall -Wextra -Wpedantic -Werror)

add_executable(kartpad_translated_semantics_fixture
  runtime/generated/g6/func_80001000.cpp
  runtime/tests/translated_semantics_fixture.cpp
)
target_include_directories(kartpad_translated_semantics_fixture PRIVATE
  runtime/include runtime/translation_shim)
target_link_libraries(kartpad_translated_semantics_fixture PRIVATE kartpad_memory)
target_compile_features(kartpad_translated_semantics_fixture PRIVATE cxx_std_20)
target_compile_options(kartpad_translated_semantics_fixture PRIVATE
  -Wall -Wextra -Wpedantic -Werror -fno-fast-math -ffp-contract=off -ffp-model=strict)
add_test(NAME kartpad_translated_semantics_fixture COMMAND kartpad_translated_semantics_fixture)

add_library(kartpad_scheduler STATIC
  runtime/src/scheduler/guest_scheduler.cpp
  runtime/src/translation/scheduled_execution.cpp)
target_include_directories(kartpad_scheduler PUBLIC runtime/include PRIVATE runtime/translation_shim)
target_compile_features(kartpad_scheduler PUBLIC cxx_std_20)
target_compile_options(kartpad_scheduler PRIVATE -Wall -Wextra -Wpedantic -Werror)

if(MKW_HOST_DARWIN)
  add_library(kartpad_g7_translated STATIC
    runtime/generated/g7/func_80001000.cpp
    runtime/src/translation/fixture_runtime.cpp
  )
  target_include_directories(kartpad_g7_translated
    PUBLIC runtime/include runtime/translation_shim)
  target_link_libraries(kartpad_g7_translated PUBLIC kartpad_memory)
  target_compile_features(kartpad_g7_translated PUBLIC cxx_std_20)
  target_compile_options(kartpad_g7_translated PRIVATE
    -Wall -Wextra -Wpedantic -Werror -fno-fast-math -ffp-contract=off)

  if(MKW_BUILD_MACOS)
    add_executable(KartPadG7Frame MACOSX_BUNDLE runtime/apps/KartPadG7Frame.mm)
    target_include_directories(KartPadG7Frame PRIVATE runtime/translation_shim)
    target_link_libraries(KartPadG7Frame PRIVATE kartpad_g7_translated)
    target_compile_features(KartPadG7Frame PRIVATE cxx_std_20)
    target_compile_options(KartPadG7Frame PRIVATE -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
    foreach(framework IN ITEMS AppKit Foundation Metal QuartzCore ImageIO UniformTypeIdentifiers)
      find_library(G7_${framework}_FRAMEWORK ${framework} REQUIRED)
      target_link_libraries(KartPadG7Frame PRIVATE "${G7_${framework}_FRAMEWORK}")
    endforeach()
    set_target_properties(KartPadG7Frame PROPERTIES
      MACOSX_BUNDLE_BUNDLE_NAME "KartPad G7 Frame"
      MACOSX_BUNDLE_GUI_IDENTIFIER "com.kartpad.g7-frame"
      MACOSX_BUNDLE_SHORT_VERSION_STRING "0.1"
      MACOSX_BUNDLE_BUNDLE_VERSION "1"
    )
  endif()

  if(MKW_BUILD_MACOS AND MKW_BUILD_AURORA_G7_FIXTURES)
    set(AURORA_ENABLE_GX ON CACHE BOOL "Enable Aurora GX" FORCE)
    set(AURORA_ENABLE_CARD OFF CACHE BOOL "Disable CARD for the G7 graphics fixture" FORCE)
    set(AURORA_ENABLE_DVD OFF CACHE BOOL "Disable DVD for the G7 graphics fixture" FORCE)
    set(AURORA_DAWN_PROVIDER package CACHE STRING "Use the pinned Dawn package" FORCE)
    set(AURORA_DAWN_VERSION v20260603.191052 CACHE STRING "Pinned Dawn version" FORCE)
    set(AURORA_DAWN_PACKAGE_URL
      "https://github.com/encounter/dawn-build/releases/download/v20260603.191052/dawn-darwin-arm64.tar.gz"
      CACHE STRING "Pinned Darwin arm64 Dawn package")
    set(AURORA_DAWN_PACKAGE_URL_HASH
      "SHA256=084ffd2ef500d614e443e3d494738272134628867bad3270d67ee8b0fb5f0838"
      CACHE STRING "Pinned Darwin arm64 Dawn package digest" FORCE)
    set(AURORA_SDL3_PROVIDER system CACHE STRING "Use the host SDL3 package" FORCE)

    add_subdirectory(ref/upstream/Wiicompiled/aurora-main
      "${CMAKE_BINARY_DIR}/aurora" EXCLUDE_FROM_ALL)

    add_executable(kartpad_g7_aurora_host_frame runtime/apps/g7_aurora_host_frame.cpp)
    target_link_libraries(kartpad_g7_aurora_host_frame PRIVATE
      aurora::core aurora::gx aurora::main aurora::vi)
    target_compile_features(kartpad_g7_aurora_host_frame PRIVATE cxx_std_20)
    target_compile_options(kartpad_g7_aurora_host_frame PRIVATE
      -Wall -Wextra -Wpedantic -Werror)

    add_executable(kartpad_g7_aurora_translated_gx
      runtime/apps/g7_aurora_translated_gx.cpp)
    target_include_directories(kartpad_g7_aurora_translated_gx PRIVATE
      runtime/translation_shim)
    target_link_libraries(kartpad_g7_aurora_translated_gx PRIVATE
      kartpad_g7_translated aurora::core aurora::gx aurora::main aurora::vi)
    target_compile_features(kartpad_g7_aurora_translated_gx PRIVATE cxx_std_20)
    target_compile_options(kartpad_g7_aurora_translated_gx PRIVATE
      -Wall -Wextra -Wpedantic -Werror -fno-fast-math -ffp-contract=off)
  endif()
endif()
target_include_directories(kartpad_host PUBLIC runtime/include)
target_compile_features(kartpad_host PUBLIC cxx_std_20)
target_compile_options(kartpad_host PRIVATE -Wall -Wextra -Wpedantic -Werror)

foreach(capability IN ITEMS
    MKW_HOST_WINDOWS MKW_HOST_DARWIN MKW_HOST_X86_64 MKW_HOST_ARM64
    MKW_RENDER_D3D12 MKW_RENDER_VULKAN MKW_RENDER_METAL
    MKW_PRODUCT_BASE MKW_PRODUCT_RETRO_REWIND
    MKW_BUILD_MACOS MKW_BUILD_IOS_SIMULATOR MKW_BUILD_IOS_DEVICE
    MKW_GUEST_MEMORY_FLAT MKW_GUEST_MEMORY_CHECKED)
  if(${capability})
    target_compile_definitions(kartpad_host PUBLIC ${capability}=1)
  else()
    target_compile_definitions(kartpad_host PUBLIC ${capability}=0)
  endif()
endforeach()

if(MKW_HOST_WINDOWS)
  # Windows libraries stay isolated here. Apple targets never see or link them.
  target_link_libraries(kartpad_host PRIVATE shell32)
endif()

if(MKW_BUILD_IOS_SIMULATOR OR MKW_BUILD_IOS_DEVICE)
  set(KARTPAD_IOS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/apple/ios")
  set(KARTPAD_SUNPAD_DIR "${CMAKE_CURRENT_SOURCE_DIR}/apple/third_party/sunpad")
  set(KARTPAD_APP_ICON_CATALOG "${KARTPAD_IOS_DIR}/Assets.xcassets")
  set(KARTPAD_PRIVACY_MANIFEST "${KARTPAD_IOS_DIR}/PrivacyInfo.xcprivacy")

  add_executable(KartPad MACOSX_BUNDLE
    "${KARTPAD_IOS_DIR}/KartPadAppDelegate.mm"
    "${KARTPAD_IOS_DIR}/KartPadShellViewController.mm"
    "${CMAKE_CURRENT_SOURCE_DIR}/apple/shared/KartPadMiiManager.mm"
    "${CMAKE_CURRENT_SOURCE_DIR}/apple/mobile/KartPadCoreBridge.mm"
    "${CMAKE_CURRENT_SOURCE_DIR}/apple/mobile/KartPadClassicInput.mm"
    "${CMAKE_CURRENT_SOURCE_DIR}/apple/mobile/KartPadMotionSteering.mm"
    "${KARTPAD_SUNPAD_DIR}/SunPadGameOverlay.mm"
    "${KARTPAD_SUNPAD_DIR}/SunPadInputMixer.mm"
    "${KARTPAD_SUNPAD_DIR}/SunPadSettings.mm"
    "${KARTPAD_SUNPAD_DIR}/SunPadDiagnostics.mm"
    "${KARTPAD_APP_ICON_CATALOG}"
    "${KARTPAD_PRIVACY_MANIFEST}")
  target_include_directories(KartPad PRIVATE
    "${KARTPAD_IOS_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/apple/mobile"
    "${CMAKE_CURRENT_SOURCE_DIR}/apple/shared"
    "${KARTPAD_SUNPAD_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/runtime/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/runtime/translation_shim")
  target_link_libraries(KartPad PRIVATE
    kartpad_host kartpad_scheduler kartpad_g7_translated)
  target_compile_features(KartPad PRIVATE cxx_std_20)
  target_compile_options(KartPad PRIVATE
    -fobjc-arc -Wall -Wextra
    "-ffile-prefix-map=${CMAKE_CURRENT_SOURCE_DIR}=.")
  foreach(framework IN ITEMS
      Foundation UIKit CoreGraphics QuartzCore Metal GameController CoreMotion UniformTypeIdentifiers)
    find_library(KARTPAD_IOS_${framework}_FRAMEWORK ${framework} REQUIRED)
    target_link_libraries(KartPad PRIVATE "${KARTPAD_IOS_${framework}_FRAMEWORK}")
  endforeach()
  set_source_files_properties(
    "${KARTPAD_APP_ICON_CATALOG}" "${KARTPAD_PRIVACY_MANIFEST}"
    PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
  set_target_properties(KartPad PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${KARTPAD_IOS_DIR}/Info.plist"
    XCODE_ATTRIBUTE_ARCHS arm64
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME AppIcon
    XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD "c++20"
    XCODE_ATTRIBUTE_CURRENT_PROJECT_VERSION 3
    XCODE_ATTRIBUTE_GENERATE_INFOPLIST_FILE NO
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET 16.0
    XCODE_ATTRIBUTE_MARKETING_VERSION 0.2.0
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER dev.kartpad.app
    XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "iphonesimulator iphoneos"
    XCODE_ATTRIBUTE_SUPPORTS_MACCATALYST NO
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2")
endif()

if(BUILD_TESTING)
  add_executable(kartpad_retro_rewind_archive_path_tests
    runtime/tests/retro_rewind_archive_path_tests.cpp
    runtime/src/retro_rewind/archive_path.cpp)
  target_include_directories(kartpad_retro_rewind_archive_path_tests PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/runtime/include")
  target_compile_features(kartpad_retro_rewind_archive_path_tests PRIVATE cxx_std_20)
  target_compile_options(kartpad_retro_rewind_archive_path_tests PRIVATE
    -Wall -Wextra -Wpedantic -Werror)
  add_test(NAME kartpad.retro-rewind.archive-path
    COMMAND kartpad_retro_rewind_archive_path_tests)

  add_executable(kartpad_mii_database_tests runtime/tests/mii_database_tests.cpp)
  target_include_directories(kartpad_mii_database_tests PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/runtime/include")
  target_compile_features(kartpad_mii_database_tests PRIVATE cxx_std_20)
  add_test(NAME kartpad_mii_database_tests COMMAND kartpad_mii_database_tests)

  add_executable(kartpad_host_contract_tests runtime/tests/host_contract_tests.cpp)
  target_link_libraries(kartpad_host_contract_tests PRIVATE kartpad_host)
  target_compile_features(kartpad_host_contract_tests PRIVATE cxx_std_20)
  target_compile_options(kartpad_host_contract_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
  add_test(NAME kartpad.host.contracts COMMAND kartpad_host_contract_tests)

  add_executable(kartpad_checked_memory_tests runtime/tests/checked_guest_memory_tests.cpp)
  target_link_libraries(kartpad_checked_memory_tests PRIVATE kartpad_memory)
  target_compile_features(kartpad_checked_memory_tests PRIVATE cxx_std_20)
  target_compile_options(kartpad_checked_memory_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
  add_test(NAME kartpad.memory.checked COMMAND kartpad_checked_memory_tests)

  add_executable(kartpad_scheduler_tests runtime/tests/guest_scheduler_tests.cpp)
  target_include_directories(kartpad_scheduler_tests PRIVATE runtime/translation_shim)
  target_link_libraries(kartpad_scheduler_tests PRIVATE kartpad_scheduler)
  target_compile_features(kartpad_scheduler_tests PRIVATE cxx_std_20)
  target_compile_options(kartpad_scheduler_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
  add_test(NAME kartpad.scheduler.portable COMMAND kartpad_scheduler_tests)

  add_executable(kartpad_blocking_stream_wait_tests
    runtime/tests/blocking_stream_wait_tests.cpp)
  target_include_directories(kartpad_blocking_stream_wait_tests PRIVATE runtime/include)
  target_compile_features(kartpad_blocking_stream_wait_tests PRIVATE cxx_std_20)
  target_compile_options(kartpad_blocking_stream_wait_tests PRIVATE
    -Wall -Wextra -Wpedantic -Werror)
  add_test(NAME kartpad.network.blocking-stream-wait
    COMMAND kartpad_blocking_stream_wait_tests)

  if(MKW_BUILD_MACOS)
    add_executable(kartpad_darwin_vm_probe runtime/tests/darwin_vm_probe.cpp)
    target_compile_features(kartpad_darwin_vm_probe PRIVATE cxx_std_20)
    target_compile_options(kartpad_darwin_vm_probe PRIVATE -Wall -Wextra -Wpedantic -Werror)
    add_test(NAME kartpad.memory.darwin-vm-probe COMMAND kartpad_darwin_vm_probe)

    add_executable(kartpad_apple_subsystem_smoke runtime/tests/apple_subsystem_smoke.mm)
    target_link_libraries(kartpad_apple_subsystem_smoke PRIVATE kartpad_host)
    target_compile_features(kartpad_apple_subsystem_smoke PRIVATE cxx_std_20)
    target_compile_options(kartpad_apple_subsystem_smoke PRIVATE
      -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
    foreach(framework IN ITEMS Foundation Metal AudioToolbox AudioUnit GameController)
      find_library(${framework}_FRAMEWORK ${framework} REQUIRED)
      target_link_libraries(kartpad_apple_subsystem_smoke PRIVATE "${${framework}_FRAMEWORK}")
    endforeach()
    add_test(NAME kartpad.subsystems.apple-smoke COMMAND kartpad_apple_subsystem_smoke)

    add_executable(kartpad_apple_secure_transport_tests
      runtime/tests/apple_secure_transport_tests.cpp)
    target_include_directories(kartpad_apple_secure_transport_tests PRIVATE runtime/include)
    target_compile_features(kartpad_apple_secure_transport_tests PRIVATE cxx_std_20)
    target_compile_options(kartpad_apple_secure_transport_tests PRIVATE
      -Wall -Wextra -Wpedantic -Werror
      -Wno-deprecated-declarations)
    find_library(SECURITY_FRAMEWORK Security REQUIRED)
    target_link_libraries(kartpad_apple_secure_transport_tests PRIVATE
      "${SECURITY_FRAMEWORK}")
    add_test(NAME kartpad.network.apple-secure-transport
      COMMAND kartpad_apple_secure_transport_tests)

    add_executable(kartpad_local_wfc_test_route_tests
      runtime/tests/local_wfc_test_route_tests.cpp)
    target_include_directories(kartpad_local_wfc_test_route_tests PRIVATE runtime/include)
    target_compile_features(kartpad_local_wfc_test_route_tests PRIVATE cxx_std_20)
    target_compile_options(kartpad_local_wfc_test_route_tests PRIVATE
      -Wall -Wextra -Wpedantic -Werror)
    add_test(NAME kartpad.network.local-wfc-test-route
      COMMAND kartpad_local_wfc_test_route_tests)

    add_executable(kartpad_seed_mii_database_tests
      runtime/tests/seed_mii_database_tests.cpp)
    target_include_directories(kartpad_seed_mii_database_tests PRIVATE runtime/include)
    target_compile_features(kartpad_seed_mii_database_tests PRIVATE cxx_std_20)
    target_compile_options(kartpad_seed_mii_database_tests PRIVATE
      -Wall -Wextra -Wpedantic -Werror)
    add_test(NAME kartpad.mii.seed-database
      COMMAND kartpad_seed_mii_database_tests)

    add_executable(kartpad_mobile_classic_input_tests
      runtime/tests/mobile_classic_input_tests.mm
      apple/mobile/KartPadClassicInput.mm)
    target_include_directories(kartpad_mobile_classic_input_tests PRIVATE
      apple/mobile apple/third_party/sunpad)
    target_compile_features(kartpad_mobile_classic_input_tests PRIVATE cxx_std_20)
    target_compile_options(kartpad_mobile_classic_input_tests PRIVATE
      -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
    find_library(MOBILE_FOUNDATION_FRAMEWORK Foundation REQUIRED)
    target_link_libraries(kartpad_mobile_classic_input_tests PRIVATE
      "${MOBILE_FOUNDATION_FRAMEWORK}")
    add_test(NAME kartpad.mobile.classic-input COMMAND kartpad_mobile_classic_input_tests)

    add_executable(kartpad_mobile_physical_controller_tests
      runtime/tests/mobile_physical_controller_tests.mm
      apple/mobile/KartPadClassicInput.mm
      apple/mobile/KartPadPhysicalControllers.mm
      apple/third_party/sunpad/SunPadControllerMapping.mm
      apple/third_party/sunpad/SunPadInputMixer.mm
      apple/third_party/sunpad/SunPadDiagnostics.mm)
    target_include_directories(kartpad_mobile_physical_controller_tests PRIVATE
      apple/mobile apple/third_party/sunpad)
    target_compile_features(kartpad_mobile_physical_controller_tests PRIVATE cxx_std_20)
    target_compile_options(kartpad_mobile_physical_controller_tests PRIVATE
      -fobjc-arc -Wall -Wextra -Wpedantic -Werror
      -Wno-c99-extensions
      -Wno-gnu-statement-expression-from-macro-expansion
      -Wno-gnu-conditional-omitted-operand
      -Wno-missing-field-initializers)
    find_library(MOBILE_GAME_CONTROLLER_FRAMEWORK GameController REQUIRED)
    target_link_libraries(kartpad_mobile_physical_controller_tests PRIVATE
      "${MOBILE_FOUNDATION_FRAMEWORK}" "${MOBILE_GAME_CONTROLLER_FRAMEWORK}")
    add_test(NAME kartpad.mobile.physical-controller
      COMMAND kartpad_mobile_physical_controller_tests)

    add_executable(kartpad_mobile_motion_steering_tests
      runtime/tests/mobile_motion_steering_tests.mm
      apple/mobile/KartPadMotionSteering.mm
      apple/third_party/sunpad/SunPadDiagnostics.mm)
    target_include_directories(kartpad_mobile_motion_steering_tests PRIVATE
      apple/mobile apple/third_party/sunpad)
    target_compile_features(kartpad_mobile_motion_steering_tests PRIVATE cxx_std_20)
    target_compile_options(kartpad_mobile_motion_steering_tests PRIVATE
      -fobjc-arc -Wall -Wextra -Wpedantic -Werror
      -Wno-c99-extensions
      -Wno-gnu-statement-expression-from-macro-expansion
      -Wno-gnu-conditional-omitted-operand)
    find_library(MOBILE_CORE_MOTION_FRAMEWORK CoreMotion REQUIRED)
    target_link_libraries(kartpad_mobile_motion_steering_tests PRIVATE
      "${MOBILE_FOUNDATION_FRAMEWORK}" "${MOBILE_CORE_MOTION_FRAMEWORK}")
    add_test(NAME kartpad.mobile.motion-steering
      COMMAND kartpad_mobile_motion_steering_tests)
  endif()
endif()
