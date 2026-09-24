#import "ENRMTextLinkRecognizer.h"

static MarkdownASTNode *ENRMRecognizedLink(MarkdownASTNode *child, NSString *url)
{
  MarkdownASTNode *link = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeLink];
  [link setAttribute:@"url" value:url];
  [link setAttribute:@"recognizedLink" value:@"true"];
  [link addChild:child];
  return link;
}

static MarkdownASTNode *ENRMTextSlice(MarkdownASTNode *node, NSString *content)
{
  MarkdownASTNode *text = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeText];
  text.content = content;
  text.attributes = [node.attributes mutableCopy];
  return text;
}

static NSArray<MarkdownASTNode *> *ENRMRecognizeNode(MarkdownASTNode *node, NSRegularExpression *textRegex,
                                                     NSRegularExpression *codeRegex)
{
  switch (node.type) {
    case MarkdownNodeTypeLink:
    case MarkdownNodeTypeCodeBlock:
    case MarkdownNodeTypeImage:
    case MarkdownNodeTypeVideo:
    case MarkdownNodeTypeLatexMathInline:
    case MarkdownNodeTypeLatexMathDisplay:
      return @[ node ];

    case MarkdownNodeTypeCode: {
      NSMutableString *content = [NSMutableString string];
      for (MarkdownASTNode *child in node.children) {
        [content appendString:child.content ?: @""];
      }
      NSRange range = NSMakeRange(0, content.length);
      NSTextCheckingResult *match = [codeRegex firstMatchInString:content options:0 range:range];
      if (content.length > 0 && match && NSEqualRanges(match.range, range)) {
        return @[ ENRMRecognizedLink(node, content) ];
      }
      return @[ node ];
    }

    case MarkdownNodeTypeText: {
      if (!textRegex)
        return @[ node ];
      NSString *content = node.content ?: @"";
      NSMutableArray<MarkdownASTNode *> *result = [NSMutableArray array];
      NSUInteger offset = 0;
      for (NSTextCheckingResult *match in [textRegex matchesInString:content
                                                             options:0
                                                               range:NSMakeRange(0, content.length)]) {
        if (match.range.length == 0)
          continue;
        if (match.range.location > offset) {
          [result addObject:ENRMTextSlice(
                                node, [content substringWithRange:NSMakeRange(offset, match.range.location - offset)])];
        }
        NSString *matched = [content substringWithRange:match.range];
        [result addObject:ENRMRecognizedLink(ENRMTextSlice(node, matched), matched)];
        offset = NSMaxRange(match.range);
      }
      if (offset == 0)
        return @[ node ];
      if (offset < content.length) {
        [result addObject:ENRMTextSlice(node, [content substringFromIndex:offset])];
      }
      return result;
    }

    default: {
      NSMutableArray<MarkdownASTNode *> *children = [NSMutableArray array];
      for (MarkdownASTNode *child in node.children) {
        [children addObjectsFromArray:ENRMRecognizeNode(child, textRegex, codeRegex)];
      }
      node.children = children;
      return @[ node ];
    }
  }
}

void ENRMRecognizeTextLinks(MarkdownASTNode *ast, ENRMLinkRegexConfig *linkRegex,
                            ENRMLinkRegexConfig *inlineCodeLinkRegex)
{
  NSRegularExpression *textRegex = (!linkRegex.isDefault && !linkRegex.isDisabled) ? linkRegex.parsedRegex : nil;
  NSRegularExpression *codeRegex = nil;
  if (!inlineCodeLinkRegex.isDefault && !inlineCodeLinkRegex.isDisabled && inlineCodeLinkRegex.parsedRegex) {
    // Full-span matching, including alternatives that first match a shorter prefix.
    codeRegex = [NSRegularExpression
        regularExpressionWithPattern:[NSString stringWithFormat:@"\\A(?:%@)\\z", inlineCodeLinkRegex.pattern]
                             options:inlineCodeLinkRegex.parsedRegex.options
                               error:nil];
  }
  if (ast && (textRegex || codeRegex)) {
    ENRMRecognizeNode(ast, textRegex, codeRegex);
  }
}
