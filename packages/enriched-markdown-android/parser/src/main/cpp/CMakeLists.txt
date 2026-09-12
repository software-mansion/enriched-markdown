cmake_minimum_required(VERSION 3.13)
project(enriched_markdown_parser)

set(CPP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../core/cpp")

if(NOT EXISTS "${CPP_ROOT}/md4c/md4c.c")
  message(FATAL_ERROR "EnrichedMarkdown C++ sources not found at ${CPP_ROOT}")
endif()

file(GLOB MD4C_SOURCES "${CPP_ROOT}/md4c/*.c")
file(GLOB PARSER_SOURCES "${CPP_ROOT}/parser/*.cpp")

add_library(md4c_lib STATIC ${MD4C_SOURCES})
target_include_directories(md4c_lib PUBLIC "${CPP_ROOT}/md4c")
target_compile_definitions(md4c_lib PRIVATE MD4C_USE_UTF8=1)
set_target_properties(md4c_lib PROPERTIES
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
  "${CPP_ROOT}/md4c"
  "${CPP_ROOT}/parser"
)

target_compile_definitions(enriched_markdown_parser PRIVATE MD4C_USE_UTF8=1)

find_package(fbjni REQUIRED CONFIG)
find_library(LOG_LIB log)

target_link_libraries(
  enriched_markdown_parser
  md4c_lib
  fbjni::fbjni
  ${LOG_LIB}
)
