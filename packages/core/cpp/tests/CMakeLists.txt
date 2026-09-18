cmake_minimum_required(VERSION 3.14)
project(enriched_markdown_core_tests CXX)

# Host-only unit tests for the shared C++ core. Not part of any app build.
#
#   cmake -S packages/core/cpp/tests -B build/core-tests
#   cmake --build build/core-tests
#   ctest --test-dir build/core-tests --output-on-failure
#
# or simply `yarn core:test` from the repo root.
#
# Layout: one subdirectory per area of the core (repair/, later parser/,
# highlight/ ...), each compiled into its own test executable by
# add_core_test() below, all sharing TestMain.cpp.

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# The module ships inside optimised app builds, so that is the configuration
# tested by default. CI also runs a Debug leg so assert()s are exercised.
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

# doctest is a test-only dependency, fetched at configure time and pinned by
# checksum. For an offline build, point CMake at a local checkout with
# -DFETCHCONTENT_SOURCE_DIR_DOCTEST=/path/to/doctest-2.4.12.
include(FetchContent)
if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)  # extracted files get extraction-time timestamps
endif()
# doctest 2.4.12 declares cmake_minimum_required(3.0); tell CMake 4 it is fine.
set(CMAKE_POLICY_VERSION_MINIMUM 3.10)
FetchContent_Declare(doctest
  URL https://github.com/doctest/doctest/archive/refs/tags/v2.4.12.tar.gz
  URL_HASH SHA256=73381c7aa4dee704bd935609668cf41880ea7f19fa0504a200e13b74999c2d70
)
set(DOCTEST_WITH_TESTS OFF CACHE BOOL "" FORCE)
set(DOCTEST_NO_INSTALL ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(doctest)

set(CPP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/..")
enable_testing()

# add_core_test(<area> <library targets...>): builds every .cpp under
# tests/<area>/ into <area>_tests, linked against the given core libraries,
# and registers it with ctest.
function(add_core_test area)
  file(GLOB sources CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${area}/*.cpp")
  add_executable(${area}_tests ${sources} TestMain.cpp)
  target_include_directories(${area}_tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/${area}")
  target_link_libraries(${area}_tests PRIVATE ${ARGN} doctest::doctest)
  add_test(NAME ${area}_tests COMMAND ${area}_tests)
endfunction()

# --- Core libraries under test ---------------------------------------------

file(GLOB REPAIR_SOURCES CONFIGURE_DEPENDS "${CPP_ROOT}/repair/*.cpp")
add_library(enriched_markdown_repair STATIC ${REPAIR_SOURCES})
target_include_directories(enriched_markdown_repair PUBLIC "${CPP_ROOT}/repair")
target_compile_options(enriched_markdown_repair PRIVATE -Wall -Wextra -Wpedantic)

# --- Test areas --------------------------------------------------------------

add_core_test(repair enriched_markdown_repair)
