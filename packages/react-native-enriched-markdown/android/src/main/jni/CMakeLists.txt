cmake_minimum_required(VERSION 3.13)
set(CMAKE_VERBOSE_MAKEFILE ON)

set(LIB_LITERAL EnrichedMarkdownTextSpec)
set(LIB_TARGET_NAME react_codegen_${LIB_LITERAL})

set(LIB_ANDROID_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../..)
set(LIB_ANDROID_GENERATED_JNI_DIR ${LIB_ANDROID_DIR}/generated/jni)
set(LIB_ANDROID_GENERATED_COMPONENTS_DIR ${LIB_ANDROID_GENERATED_JNI_DIR}/react/renderer/components/${LIB_LITERAL})

# cpp/ is a symlink to packages/core/cpp in the monorepo; published tarballs
# ship real files (materialized at prepack). Use paths relative to this file —
# Android's cross-compile CMake pass cannot access absolute paths outside the
# module via symlinks or REALPATH.
set(CPP_IN_PACKAGE "${CMAKE_CURRENT_SOURCE_DIR}/../../../../cpp")
set(CPP_IN_MONOREPO "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../core/cpp")

if(EXISTS "${CPP_IN_PACKAGE}/md4c/md4c.c")
  set(CPP_ROOT "${CPP_IN_PACKAGE}")
elseif(EXISTS "${CPP_IN_MONOREPO}/md4c/md4c.c")
  set(CPP_ROOT "${CPP_IN_MONOREPO}")
else()
  message(FATAL_ERROR "EnrichedMarkdown C++ sources not found. Expected cpp/ or packages/core/cpp.")
endif()

set(ANDROID_CPP_DIR "${LIB_ANDROID_DIR}/src/main/cpp")

file(GLOB MD4C_SOURCES "${CPP_ROOT}/md4c/*.c")
file(GLOB PARSER_SOURCES "${CPP_ROOT}/parser/*.cpp")
file(GLOB HIGHLIGHT_SOURCES "${CPP_ROOT}/highlight/*.cpp")

# md4c is C code, build as separate static library with C flags
add_library(md4c_lib STATIC ${MD4C_SOURCES})
target_include_directories(md4c_lib PUBLIC ${CPP_ROOT}/md4c)
target_compile_definitions(md4c_lib PRIVATE MD4C_USE_UTF8=1)
set_target_properties(md4c_lib PROPERTIES
  C_STANDARD 11
  C_STANDARD_REQUIRED ON
)

file(GLOB LIB_CODEGEN_SRCS CONFIGURE_DEPENDS ${LIB_ANDROID_GENERATED_JNI_DIR}/*.cpp ${LIB_ANDROID_GENERATED_COMPONENTS_DIR}/*.cpp)
file(GLOB LIB_CUSTOM_JNI_SRCS CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp ${CMAKE_CURRENT_SOURCE_DIR}/react/renderer/components/${LIB_LITERAL}/*.cpp)

add_library(
  ${LIB_TARGET_NAME}
  SHARED
  ${LIB_CODEGEN_SRCS}
  ${LIB_CUSTOM_JNI_SRCS}
  ${PARSER_SOURCES}
  ${HIGHLIGHT_SOURCES}
  ${ANDROID_CPP_DIR}/jni-adapter.cpp
)

target_include_directories(
  ${LIB_TARGET_NAME}
  PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/react/renderer/components/${LIB_LITERAL}
  ${LIB_ANDROID_GENERATED_JNI_DIR}
  ${LIB_ANDROID_GENERATED_COMPONENTS_DIR}
  ${CPP_ROOT}/md4c
  ${CPP_ROOT}/parser
  ${CPP_ROOT}/highlight
)

target_compile_definitions(${LIB_TARGET_NAME} PRIVATE MD4C_USE_UTF8=1)

find_package(fbjni REQUIRED CONFIG)
find_package(ReactAndroid REQUIRED CONFIG)
find_library(LOG_LIB log)

target_link_libraries(
  ${LIB_TARGET_NAME}
  ${LOG_LIB}
  md4c_lib
  fbjni::fbjni
  ReactAndroid::jsi
  ReactAndroid::reactnative
)

target_include_directories(
  ${CMAKE_PROJECT_NAME}
  PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}
)

target_compile_reactnative_options(${LIB_TARGET_NAME} PRIVATE)
