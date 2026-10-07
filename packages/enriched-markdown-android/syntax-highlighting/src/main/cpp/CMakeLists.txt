cmake_minimum_required(VERSION 3.13)
project(enriched_markdown_highlight)

set(HIGHLIGHT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../core/cpp/highlight")
set(TS_VENDOR "${HIGHLIGHT_ROOT}/vendor")
set(HIGHLIGHT_GENERATED_DIR "${TS_VENDOR}/generated")

# Fixed language set, the same as iOS. Grammar ids double as tree_sitter_<id> symbol names.
set(HIGHLIGHT_LANGUAGES
  bash c css go html java javascript json markdown python rust tsx typescript yaml)

if(NOT EXISTS "${HIGHLIGHT_ROOT}/CodeBlockHighlighter.cpp")
  message(FATAL_ERROR "EnrichedMarkdown highlight sources not found at ${HIGHLIGHT_ROOT}")
endif()
if(NOT EXISTS "${TS_VENDOR}/tree-sitter/src/lib.c" OR NOT EXISTS "${HIGHLIGHT_GENERATED_DIR}/generated_registry.cpp")
  message(FATAL_ERROR "tree-sitter sources not vendored. From the repository root run: "
    "yarn install && node vendor/vendor-grammars.mjs")
endif()

# The generated registry must declare exactly the grammars compiled below.
file(READ "${HIGHLIGHT_GENERATED_DIR}/generated_registry.cpp" REGISTRY_SOURCE)
string(REGEX MATCHALL "tree_sitter_[a-z_]+\\(void\\)" REGISTRY_DECLS "${REGISTRY_SOURCE}")
set(REGISTRY_LANGUAGES "")
foreach(decl IN LISTS REGISTRY_DECLS)
  string(REGEX REPLACE "^tree_sitter_([a-z_]+)\\(void\\)$" "\\1" lang "${decl}")
  list(APPEND REGISTRY_LANGUAGES "${lang}")
endforeach()
set(EXPECTED_LANGUAGES ${HIGHLIGHT_LANGUAGES})
list(SORT REGISTRY_LANGUAGES)
list(SORT EXPECTED_LANGUAGES)
if(NOT REGISTRY_LANGUAGES STREQUAL EXPECTED_LANGUAGES)
  message(FATAL_ERROR "generated_registry.cpp declares [${REGISTRY_LANGUAGES}] but this module compiles "
    "[${EXPECTED_LANGUAGES}]. Regenerate the default registry: node vendor/vendor-grammars.mjs --force")
endif()

add_library(tree_sitter_runtime STATIC "${TS_VENDOR}/tree-sitter/src/lib.c")
target_include_directories(tree_sitter_runtime
  PRIVATE "${TS_VENDOR}/tree-sitter/src"
  PUBLIC "${TS_VENDOR}/tree-sitter/include")
set_target_properties(tree_sitter_runtime PROPERTIES
  C_STANDARD 11 C_STANDARD_REQUIRED ON POSITION_INDEPENDENT_CODE ON)
target_compile_options(tree_sitter_runtime PRIVATE -fvisibility=hidden)

# One OBJECT lib per grammar, each in its own include dir so grammar parser.h files never collide.
set(GRAMMAR_OBJECTS "")
foreach(lang IN LISTS HIGHLIGHT_LANGUAGES)
  set(gdir "${TS_VENDOR}/grammars/${lang}")
  set(gsrcs "${gdir}/parser.c")
  if(EXISTS "${gdir}/scanner.c")
    list(APPEND gsrcs "${gdir}/scanner.c")
  endif()
  add_library(ts_grammar_${lang} OBJECT ${gsrcs})
  target_include_directories(ts_grammar_${lang} PRIVATE "${gdir}")
  set_target_properties(ts_grammar_${lang} PROPERTIES
    C_STANDARD 11 C_STANDARD_REQUIRED ON POSITION_INDEPENDENT_CODE ON)
  target_compile_options(ts_grammar_${lang} PRIVATE -fvisibility=hidden)
  list(APPEND GRAMMAR_OBJECTS $<TARGET_OBJECTS:ts_grammar_${lang}>)
endforeach()

add_library(
  enriched_markdown_highlight
  SHARED
  "${HIGHLIGHT_ROOT}/CodeBlockHighlighter.cpp"
  "${HIGHLIGHT_ROOT}/CodeBlockLanguages.cpp"
  "${HIGHLIGHT_GENERATED_DIR}/generated_registry.cpp"
  ${GRAMMAR_OBJECTS}
  jni/HighlightJni.cpp
)

target_include_directories(
  enriched_markdown_highlight
  PRIVATE
  "${HIGHLIGHT_ROOT}"
  "${HIGHLIGHT_GENERATED_DIR}"
)

# JNIEXPORT keeps the entry point visible; the seam stays private to this library so it never
# interposes with the copy linked into the React Native package.
target_compile_options(enriched_markdown_highlight PRIVATE -fvisibility=hidden)
target_compile_definitions(enriched_markdown_highlight PRIVATE ENRICHED_MARKDOWN_CODE_HIGHLIGHT=1)
target_link_libraries(enriched_markdown_highlight tree_sitter_runtime)
