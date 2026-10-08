cmake_minimum_required(VERSION 3.13)
project(display_benchmark_parser)

# The library's native code, the vendored MD4C-fork parser behind Parser.nativeParseMarkdown included,
# is not built by the library module: autolinking compiles its jni/CMakeLists.txt into
# the app's native build, together with the Fabric codegen that needs ReactAndroid's
# prefab. This module has no app, so it builds the plain-JNI part alone, under the
# library name Parser/CodeBlockHighlighter/CodeBlockNode load.
#
# Syntax highlighting stays compiled out (the stub CodeBlockHighlighter.cpp). That does
# not change what is measured: the only fenced language the fixtures use is kotlin,
# for which no grammar exists, so the app build would not highlight it either.

set(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../..")
set(CPP_ROOT "${REPO_ROOT}/packages/core/cpp")
set(LIB_ANDROID_CPP_DIR "${REPO_ROOT}/packages/react-native-enriched-markdown/android/src/main/cpp")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

file(GLOB ENRMRKD_SOURCES "${CPP_ROOT}/enrmrkd/*.c")
file(GLOB PARSER_SOURCES "${CPP_ROOT}/parser/*.cpp")
file(GLOB HIGHLIGHT_SOURCES "${CPP_ROOT}/highlight/*.cpp")

add_library(enrmrkd_lib STATIC ${ENRMRKD_SOURCES})
target_include_directories(enrmrkd_lib PUBLIC "${CPP_ROOT}/enrmrkd")
target_compile_definitions(enrmrkd_lib PRIVATE ENRMRKD_USE_UTF8=1)
set_target_properties(enrmrkd_lib PROPERTIES
  C_STANDARD 11
  C_STANDARD_REQUIRED ON
  POSITION_INDEPENDENT_CODE ON
)

add_library(
  react_codegen_EnrichedMarkdownTextSpec
  SHARED
  ${PARSER_SOURCES}
  ${HIGHLIGHT_SOURCES}
  "${LIB_ANDROID_CPP_DIR}/jni-adapter.cpp"
)

target_include_directories(
  react_codegen_EnrichedMarkdownTextSpec
  PRIVATE
  "${CPP_ROOT}/enrmrkd"
  "${CPP_ROOT}/parser"
  "${CPP_ROOT}/highlight"
)

target_compile_definitions(react_codegen_EnrichedMarkdownTextSpec PRIVATE ENRMRKD_USE_UTF8=1)

find_library(LOG_LIB log)
target_link_libraries(react_codegen_EnrichedMarkdownTextSpec ${LOG_LIB} enrmrkd_lib)
