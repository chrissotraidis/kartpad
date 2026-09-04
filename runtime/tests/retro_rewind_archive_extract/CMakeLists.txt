cmake_minimum_required(VERSION 3.24)
project(kartpad_archive_extract_test LANGUAGES C CXX)

if(NOT DEFINED KARTPAD_REPO_ROOT OR NOT DEFINED MINIZIP_SOURCE_DIR)
  message(FATAL_ERROR "KARTPAD_REPO_ROOT and MINIZIP_SOURCE_DIR are required")
endif()

set(MZ_COMPAT OFF CACHE BOOL "" FORCE)
set(MZ_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(MZ_BUILD_UNIT_TESTS OFF CACHE BOOL "" FORCE)
set(MZ_BUILD_FUZZ_TESTS OFF CACHE BOOL "" FORCE)
set(MZ_CODE_COVERAGE OFF CACHE BOOL "" FORCE)
set(MZ_FETCH_LIBS OFF CACHE BOOL "" FORCE)
set(MZ_BZIP2 OFF CACHE BOOL "" FORCE)
set(MZ_LZMA OFF CACHE BOOL "" FORCE)
set(MZ_ZSTD OFF CACHE BOOL "" FORCE)
set(MZ_PKCRYPT OFF CACHE BOOL "" FORCE)
set(MZ_WZAES OFF CACHE BOOL "" FORCE)
set(MZ_OPENSSL OFF CACHE BOOL "" FORCE)
set(MZ_LIBBSD OFF CACHE BOOL "" FORCE)
set(MZ_ICONV OFF CACHE BOOL "" FORCE)
set(MZ_DECOMPRESS_ONLY ON CACHE BOOL "" FORCE)
set(SKIP_INSTALL_ALL ON CACHE BOOL "" FORCE)
add_subdirectory("${MINIZIP_SOURCE_DIR}" minizip-ng EXCLUDE_FROM_ALL)

add_executable(kartpad_archive_extract_test
  main.cpp
  "${KARTPAD_REPO_ROOT}/runtime/src/retro_rewind/archive_extract.cpp"
  "${KARTPAD_REPO_ROOT}/runtime/src/retro_rewind/archive_path.cpp"
  "${KARTPAD_REPO_ROOT}/runtime/src/retro_rewind/archive_scan.cpp")
target_compile_features(kartpad_archive_extract_test PRIVATE cxx_std_20)
target_compile_options(kartpad_archive_extract_test PRIVATE
  -Wall -Wextra -Werror -pedantic)
target_include_directories(kartpad_archive_extract_test PRIVATE
  "${KARTPAD_REPO_ROOT}/runtime/include")
target_link_libraries(kartpad_archive_extract_test PRIVATE MINIZIP::minizip)
