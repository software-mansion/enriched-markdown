#pragma once

#import "ENRMLinkRegexConfig.h"
#import "MarkdownASTNode.h"

#ifdef __cplusplus
extern "C" {
#endif

// Mutates only the freshly parsed AST. Existing links and block code are opaque.
void ENRMRecognizeTextLinks(MarkdownASTNode *ast, ENRMLinkRegexConfig *linkRegex,
                            ENRMLinkRegexConfig *inlineCodeLinkRegex);

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
// Props share EnrichedMarkdownTextInput's native regex transport.
template <typename RegexProps>
static inline ENRMLinkRegexConfig *ENRMTextLinkRegexConfigFromProps(const RegexProps &props)
{
  if (props.isDisabled || props.isDefault || props.pattern.empty())
    return nil;
  return [[ENRMLinkRegexConfig alloc] initWithPattern:[NSString stringWithUTF8String:props.pattern.c_str()]
                                      caseInsensitive:props.caseInsensitive
                                               dotAll:props.dotAll
                                           isDisabled:props.isDisabled
                                            isDefault:props.isDefault];
}
#endif
