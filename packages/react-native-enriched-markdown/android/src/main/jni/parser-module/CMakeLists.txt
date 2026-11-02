cmake_minimum_required(VERSION 3.13)

# Autolinking entry for the pure C++ EnrichedMarkdownParser TurboModule
# (react-native.config.js cxxModule* keys). The class itself is compiled into
# react_codegen_EnrichedMarkdownTextSpec next to the parser it wraps, so this
# target only forwards that link and the include paths the generated
# autolinking.cpp needs for `#include <EnrichedMarkdownParser.h>`. It has to be
# a real library (not INTERFACE): React Native's app CMake links common flags
# into every autolinked target without the INTERFACE keyword.
set(LIB_ANDROID_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../..)

add_library(EnrichedMarkdownParser STATIC ${CMAKE_CURRENT_SOURCE_DIR}/EnrichedMarkdownParserAutolink.cpp)

# Only the spec's own folder is exposed, by name, so no generated header (Props.h,
# States.h, ...) becomes reachable as a bare include from other autolinked targets.
target_include_directories(
  EnrichedMarkdownParser
  PUBLIC
  ${LIB_ANDROID_DIR}/../common
  ${LIB_ANDROID_DIR}/generated/jni/react/renderer/components
)

# Plain signature: React Native links its common flags into this target the same way.
target_link_libraries(EnrichedMarkdownParser react_codegen_EnrichedMarkdownTextSpec)
