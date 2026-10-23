cmake_minimum_required(VERSION 3.25)
project(KartPadControllerPanelDependencies LANGUAGES C CXX)
# Use the production archive pin and SDL patches without configuring game sources.
get_filename_component(repo "${CMAKE_CURRENT_SOURCE_DIR}/../../.." ABSOLUTE)
set(runtime "${repo}/vendor/runtimes/macos")
file(READ "${runtime}/runtime/CMakeLists.txt" runtime_cmake)
string(REGEX MATCH "FetchContent_Declare\\(SDL[ \r\n]+URL ([^ \r\n]+)[ \r\n]+URL_HASH (SHA256=[a-f0-9]+)" matched "${runtime_cmake}")
if(NOT matched)
  message(FATAL_ERROR "Could not read the production SDL URL and checksum")
endif()
set(sdl_url "${CMAKE_MATCH_1}")
set(sdl_hash "${CMAKE_MATCH_2}")
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST OFF CACHE BOOL "" FORCE)
include(FetchContent)
FetchContent_Declare(SDL URL "${sdl_url}" URL_HASH "${sdl_hash}"
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  PATCH_COMMAND "${CMAKE_COMMAND}" -DSDL_SOURCE_DIR=<SOURCE_DIR>
    -P "${runtime}/aurora-main/cmake/AuroraSDL3Patches.cmake"
  EXCLUDE_FROM_ALL)
FetchContent_MakeAvailable(SDL)
