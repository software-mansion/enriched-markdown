#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct EMCParseResult EMCParseResult;

EMCParseResult *em_parse_markdown(const char *markdown, int underline, int latexMath, int superscript, int subscript,
                                  int highlight, int permissiveAutolinks);

void em_parse_result_release(EMCParseResult *result);

const void *em_ast_root(const EMCParseResult *result);

int em_ast_node_type(const void *node);
const char *em_ast_node_content(const void *node);
size_t em_ast_node_child_count(const void *node);
const void *em_ast_node_child_at(const void *node, size_t index);

typedef struct EMASTAttributeIterator EMASTAttributeIterator;

EMASTAttributeIterator *em_ast_node_attribute_iterator_create(const void *node);
int em_ast_node_attribute_iterator_next(EMASTAttributeIterator *iterator, const char **key, const char **value);
void em_ast_node_attribute_iterator_release(EMASTAttributeIterator *iterator);

#ifdef __cplusplus
}
#endif
