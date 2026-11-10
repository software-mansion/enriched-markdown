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
# Layout: one subdirectory per area of the core (repair/, latex/, later
# parser/, highlight/ ...), each compiled into its own test executable by
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

# -DCORE_SANITIZE=address,undefined builds the libraries and tests with those
# sanitizers. CI runs this on Linux; on macOS AddressSanitizer can deadlock
# during its own start-up, so use undefined alone there.
set(CORE_SANITIZE "" CACHE STRING "Comma-separated list for -fsanitize=, empty for none")
if(CORE_SANITIZE)
  add_compile_options(-fsanitize=${CORE_SANITIZE} -fno-omit-frame-pointer)
  add_link_options(-fsanitize=${CORE_SANITIZE})
endif()

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

file(GLOB LATEX_SOURCES CONFIGURE_DEPENDS "${CPP_ROOT}/latex/*.cpp")
add_library(enriched_markdown_latex STATIC ${LATEX_SOURCES})
target_include_directories(enriched_markdown_latex PUBLIC "${CPP_ROOT}/latex")
target_compile_options(enriched_markdown_latex PRIVATE -Wall -Wextra -Wpedantic)

# --- Test areas --------------------------------------------------------------

add_core_test(repair enriched_markdown_repair)
add_core_test(latex enriched_markdown_latex)

# --- Code-block syntax highlighting -----------------------------------------
#
# Needs the gitignored tree-sitter runtime and grammars, restored by
# `node vendor/vendor-grammars.mjs`. Only the grammars these tests exercise are
# compiled, through a registry generated for exactly that set.
set(CORE_HIGHLIGHT_LANGUAGES "python;swift;kotlin;dart;sql" CACHE STRING
  "Grammar ids compiled into highlight_tests")
set(HIGHLIGHT_ROOT "${CPP_ROOT}/highlight")
set(HIGHLIGHT_VENDOR "${HIGHLIGHT_ROOT}/vendor")
if(EXISTS "${HIGHLIGHT_VENDOR}/tree-sitter/src/lib.c")
  enable_language(C)
  set(CMAKE_C_STANDARD 11)
  find_program(NODE_EXECUTABLE node REQUIRED)
  set(HIGHLIGHT_REGISTRY_DIR "${CMAKE_CURRENT_BINARY_DIR}/highlight-registry")
  list(JOIN CORE_HIGHLIGHT_LANGUAGES "," HIGHLIGHT_LANGUAGE_LIST)
  execute_process(
    COMMAND "${NODE_EXECUTABLE}" "${CPP_ROOT}/../../../vendor/gen-registry.mjs"
      --vendor-dir "${HIGHLIGHT_VENDOR}" --languages "${HIGHLIGHT_LANGUAGE_LIST}" --out "${HIGHLIGHT_REGISTRY_DIR}"
    RESULT_VARIABLE HIGHLIGHT_REGISTRY_RESULT)
  if(NOT HIGHLIGHT_REGISTRY_RESULT EQUAL 0)
    message(FATAL_ERROR "gen-registry.mjs failed for [${HIGHLIGHT_LANGUAGE_LIST}]; run node vendor/vendor-grammars.mjs")
  endif()

  set(HIGHLIGHT_GRAMMAR_SOURCES "")
  foreach(lang IN LISTS CORE_HIGHLIGHT_LANGUAGES)
    set(gdir "${HIGHLIGHT_VENDOR}/grammars/${lang}")
    set(gsrcs "${gdir}/parser.c")
    if(EXISTS "${gdir}/scanner.c")
      list(APPEND gsrcs "${gdir}/scanner.c")
    endif()
    add_library(ts_grammar_${lang} OBJECT ${gsrcs})
    target_include_directories(ts_grammar_${lang} PRIVATE "${gdir}")
    # Generated parser tables are not ours to warn about, and their size makes
    # sanitizer instrumentation the slowest part of the build for no benefit.
    target_compile_options(ts_grammar_${lang} PRIVATE -w -fno-sanitize=all)
    list(APPEND HIGHLIGHT_GRAMMAR_SOURCES $<TARGET_OBJECTS:ts_grammar_${lang}>)
  endforeach()

  add_library(enriched_markdown_highlight STATIC
    "${HIGHLIGHT_VENDOR}/tree-sitter/src/lib.c"
    "${HIGHLIGHT_ROOT}/CodeBlockHighlighter.cpp"
    "${HIGHLIGHT_ROOT}/CodeBlockLanguages.cpp"
    "${HIGHLIGHT_REGISTRY_DIR}/generated_registry.cpp"
    ${HIGHLIGHT_GRAMMAR_SOURCES})
  set_source_files_properties("${HIGHLIGHT_VENDOR}/tree-sitter/src/lib.c" PROPERTIES COMPILE_OPTIONS "-w")
  target_include_directories(enriched_markdown_highlight
    PUBLIC "${HIGHLIGHT_ROOT}" "${HIGHLIGHT_VENDOR}/tree-sitter/include"
    PRIVATE "${HIGHLIGHT_VENDOR}/tree-sitter/src" "${HIGHLIGHT_REGISTRY_DIR}")
  target_compile_definitions(enriched_markdown_highlight PRIVATE ENRICHED_MARKDOWN_CODE_HIGHLIGHT=1)

  add_core_test(highlight enriched_markdown_highlight)
  set_tests_properties(highlight_tests PROPERTIES
    ENVIRONMENT "LSAN_OPTIONS=suppressions=${CMAKE_CURRENT_SOURCE_DIR}/highlight/lsan.supp")
else()
  message(STATUS "highlight_tests skipped: tree-sitter is not vendored; run node vendor/vendor-grammars.mjs")
endif()
