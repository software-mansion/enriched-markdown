cmake_minimum_required(VERSION 3.13)
project(display_benchmark_parser)

# The library's native code, the md4c parser behind Parser.nativeParseMarkdown included,
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

file(GLOB MD4C_SOURCES "${CPP_ROOT}/md4c/*.c")
file(GLOB PARSER_SOURCES "${CPP_ROOT}/parser/*.cpp")
file(GLOB HIGHLIGHT_SOURCES "${CPP_ROOT}/highlight/*.cpp")

add_library(md4c_lib STATIC ${MD4C_SOURCES})
target_include_directories(md4c_lib PUBLIC "${CPP_ROOT}/md4c")
target_compile_definitions(md4c_lib PRIVATE MD4C_USE_UTF8=1)
set_target_properties(md4c_lib PROPERTIES
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
  "${CPP_ROOT}/md4c"
  "${CPP_ROOT}/parser"
  "${CPP_ROOT}/highlight"
)

target_compile_definitions(react_codegen_EnrichedMarkdownTextSpec PRIVATE MD4C_USE_UTF8=1)

find_library(LOG_LIB log)
target_link_libraries(react_codegen_EnrichedMarkdownTextSpec ${LOG_LIB} md4c_lib)
