cmake_minimum_required(VERSION 3.13)
project(enriched_markdown_parser)

set(CPP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../core/cpp")

if(NOT EXISTS "${CPP_ROOT}/enrmrkd/enrmrkd.c")
  message(FATAL_ERROR "EnrichedMarkdown C++ sources not found at ${CPP_ROOT}")
endif()

file(GLOB ENRMRKD_SOURCES "${CPP_ROOT}/enrmrkd/*.c")
file(GLOB PARSER_SOURCES "${CPP_ROOT}/parser/*.cpp")

add_library(enrmrkd_lib STATIC ${ENRMRKD_SOURCES})
target_include_directories(enrmrkd_lib PUBLIC "${CPP_ROOT}/enrmrkd")
target_compile_definitions(enrmrkd_lib PRIVATE ENRMRKD_USE_UTF8=1)
set_target_properties(enrmrkd_lib PROPERTIES
  C_STANDARD 11
  C_STANDARD_REQUIRED ON
)

add_library(
  enriched_markdown_parser
  SHARED
  ${PARSER_SOURCES}
  jni/ParserJni.cpp
)

target_include_directories(
  enriched_markdown_parser
  PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/jni"
  "${CPP_ROOT}/enrmrkd"
  "${CPP_ROOT}/parser"
)

target_compile_definitions(enriched_markdown_parser PRIVATE ENRMRKD_USE_UTF8=1)

find_package(fbjni REQUIRED CONFIG)
find_library(LOG_LIB log)

target_link_libraries(
  enriched_markdown_parser
  enrmrkd_lib
  fbjni::fbjni
  ${LOG_LIB}
)
