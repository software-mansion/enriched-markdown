#import "MarkdownASTSerializer.h"
#import "ENRMCodeBlockContent.h"
#import "MarkdownASTNode.h"

static void serializeNode(MarkdownASTNode *node, NSMutableString *buffer);
static void serializeChildren(MarkdownASTNode *node, NSMutableString *buffer);
static void appendBlockNode(MarkdownASTNode *node, NSMutableString *buffer);
static void appendPlainText(MarkdownASTNode *node, NSMutableString *buffer, BOOL linksAsMarkdown);

static void serializeChildren(MarkdownASTNode *node, NSMutableString *buffer)
{
  for (MarkdownASTNode *child in node.children) {
    serializeNode(child, buffer);
  }
}

static void serializeNode(MarkdownASTNode *node, NSMutableString *buffer)
{
  if (!node)
    return;

  switch (node.type) {
    case MarkdownNodeTypeText:
      [buffer appendString:node.content ?: @""];
      break;

    case MarkdownNodeTypeLineBreak:
      [buffer appendString:@"\\\n"];
      break;

    case MarkdownNodeTypeSoftBreak:
      [buffer appendString:@"\n"];
      break;

    case MarkdownNodeTypeStrong:
      [buffer appendString:@"**"];
      serializeChildren(node, buffer);
      [buffer appendString:@"**"];
      break;

    case MarkdownNodeTypeEmphasis:
      [buffer appendString:@"*"];
      serializeChildren(node, buffer);
      [buffer appendString:@"*"];
      break;

    case MarkdownNodeTypeStrikethrough:
      [buffer appendString:@"~~"];
      serializeChildren(node, buffer);
      [buffer appendString:@"~~"];
      break;

    case MarkdownNodeTypeUnderline:
      [buffer appendString:@"__"];
      serializeChildren(node, buffer);
      [buffer appendString:@"__"];
      break;

    case MarkdownNodeTypeSuperscript:
      [buffer appendString:@"^"];
      serializeChildren(node, buffer);
      [buffer appendString:@"^"];
      break;

    case MarkdownNodeTypeSubscript:
      [buffer appendString:@"~"];
      serializeChildren(node, buffer);
      [buffer appendString:@"~"];
      break;

    case MarkdownNodeTypeHighlight:
      [buffer appendString:@"=="];
      serializeChildren(node, buffer);
      [buffer appendString:@"=="];
      break;

    case MarkdownNodeTypeLatexMathInline:
      [buffer appendString:@"$"];
      serializeChildren(node, buffer);
      [buffer appendString:@"$"];
      break;

    case MarkdownNodeTypeCode:
      [buffer appendString:@"`"];
      serializeChildren(node, buffer);
      [buffer appendString:@"`"];
      break;

    case MarkdownNodeTypeLink: {
      if ([node.attributes[@"recognizedLink"] isEqualToString:@"true"]) {
        serializeChildren(node, buffer);
        break;
      }
      NSString *url = node.attributes[@"url"] ?: @"";
      [buffer appendString:@"["];
      serializeChildren(node, buffer);
      [buffer appendFormat:@"](%@)", url];
      break;
    }

    case MarkdownNodeTypeImage: {
      NSString *alt = node.attributes[@"alt"] ?: @"";
      NSString *url = node.attributes[@"url"] ?: @"";
      [buffer appendFormat:@"![%@](%@)", alt, url];
      break;
    }

    case MarkdownNodeTypeVideo: {
      NSString *url = node.attributes[@"url"] ?: @"";
      if ([url containsString:@"\""]) {
        [buffer appendFormat:@"<video src='%@' />", url];
      } else {
        [buffer appendFormat:@"<video src=\"%@\" />", url];
      }
      break;
    }

    case MarkdownNodeTypeParagraph:
    default:
      serializeChildren(node, buffer);
      break;
  }
}

// --- Block-level serialization ---

static void serializeBlockChildren(MarkdownASTNode *node, NSMutableString *buffer)
{
  NSArray<MarkdownASTNode *> *children = node.children;
  for (NSUInteger i = 0; i < children.count; i++) {
    MarkdownASTNode *child = children[i];
    appendBlockNode(child, buffer);
    if (i < children.count - 1 && ENRMIsTopLevelBlockType(child.type)) {
      [buffer appendString:@"\n"];
    }
  }
}

// Table markdown reconstruction from raw AST nodes. This parallels
// TableContainerView's buildMarkdownFromRows which works from processed
// TableCellData; both must produce the same pipe-table format.
static void appendTableMarkdown(MarkdownASTNode *node, NSMutableString *buffer)
{
  BOOL headerDone = NO;
  for (MarkdownASTNode *section in node.children) {
    for (MarkdownASTNode *row in section.children) {
      if (row.type != MarkdownNodeTypeTableRow)
        continue;
      NSMutableArray<NSString *> *cells = [NSMutableArray arrayWithCapacity:row.children.count];
      for (MarkdownASTNode *cell in row.children) {
        [cells addObject:markdownFromTableCellNode(cell)];
      }
      [buffer appendFormat:@"| %@ |\n", [cells componentsJoinedByString:@" | "]];
      if (!headerDone) {
        BOOL isHeader = NO;
        for (MarkdownASTNode *cell in row.children) {
          if (cell.type == MarkdownNodeTypeTableHeaderCell) {
            isHeader = YES;
            break;
          }
        }
        if (isHeader) {
          NSMutableArray<NSString *> *sep = [NSMutableArray arrayWithCapacity:row.children.count];
          for (MarkdownASTNode *cell in row.children) {
            NSString *align = cell.attributes[@"align"];
            if ([align isEqualToString:@"center"])
              [sep addObject:@":---:"];
            else if ([align isEqualToString:@"right"])
              [sep addObject:@"---:"];
            else
              [sep addObject:@"---"];
          }
          [buffer appendFormat:@"| %@ |\n", [sep componentsJoinedByString:@" | "]];
          headerDone = YES;
        }
      }
    }
  }
}

static void appendListMarkdown(MarkdownASTNode *node, NSMutableString *buffer, BOOL ordered)
{
  NSUInteger number = 1;
  if (ordered) {
    NSString *startAttr = node.attributes[@"start"];
    if (startAttr != nil) {
      NSInteger parsed = startAttr.integerValue;
      number = (NSUInteger)MAX(0, parsed);
    }
  }
  for (MarkdownASTNode *item in node.children) {
    if (item.type != MarkdownNodeTypeListItem)
      continue;
    NSString *prefix = ordered ? [NSString stringWithFormat:@"%lu. ", (unsigned long)number] : @"- ";
    NSMutableString *content = [NSMutableString string];
    serializeBlockChildren(item, content);
    NSString *trimmed =
        content.length > 0 ? [content stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] : @"";
    NSArray<NSString *> *lines = [trimmed componentsSeparatedByString:@"\n"];
    NSString *indent = [@"" stringByPaddingToLength:prefix.length withString:@" " startingAtIndex:0];
    for (NSUInteger l = 0; l < lines.count; l++) {
      [buffer appendString:(l == 0) ? prefix : indent];
      [buffer appendString:lines[l]];
      [buffer appendString:@"\n"];
    }
    if (ordered)
      number++;
  }
}

static void appendBlockNode(MarkdownASTNode *node, NSMutableString *buffer)
{
  if (!node)
    return;

  switch (node.type) {
    case MarkdownNodeTypeParagraph:
      serializeChildren(node, buffer);
      [buffer appendString:@"\n"];
      break;

    case MarkdownNodeTypeHeading: {
      NSInteger level = [node.attributes[@"level"] integerValue];
      if (level < 1)
        level = 1;
      for (NSInteger i = 0; i < level; i++)
        [buffer appendString:@"#"];
      [buffer appendString:@" "];
      serializeChildren(node, buffer);
      [buffer appendString:@"\n"];
      break;
    }

    case MarkdownNodeTypeCodeBlock: {
      NSString *code = ENRMCodeBlockExtractCode(node);
      NSString *language = ENRMCodeBlockLanguage(node);
      NSString *fenceChar = ENRMCodeBlockFenceChar(node);
      [buffer appendString:ENRMCodeBlockFencedMarkdown(code, language, fenceChar)];
      [buffer appendString:@"\n"];
      break;
    }

    case MarkdownNodeTypeBlockquote:
    case MarkdownNodeTypeAdmonition:
      [buffer appendString:markdownFromBlockquoteNode(node)];
      break;

    case MarkdownNodeTypeThematicBreak:
      [buffer appendString:@"---\n"];
      break;

    case MarkdownNodeTypeBlankLine: {
      NSInteger count = [node.attributes[@"count"] integerValue];
      for (NSInteger i = 0; i < count; i++) {
        [buffer appendString:@"\n"];
      }
      break;
    }

    case MarkdownNodeTypeTable:
      appendTableMarkdown(node, buffer);
      break;

    case MarkdownNodeTypeUnorderedList:
      appendListMarkdown(node, buffer, NO);
      break;

    case MarkdownNodeTypeOrderedList:
      appendListMarkdown(node, buffer, YES);
      break;

    case MarkdownNodeTypeLatexMathDisplay:
      [buffer appendString:@"$$\n"];
      serializeChildren(node, buffer);
      [buffer appendString:@"\n$$\n"];
      break;

    default:
      serializeChildren(node, buffer);
      break;
  }
}

static NSString *ENRMEscaped(NSString *text, NSString *pattern)
{
  return [text stringByReplacingOccurrencesOfString:pattern
                                         withString:@"\\\\$0"
                                            options:NSRegularExpressionSearch
                                              range:NSMakeRange(0, text.length)];
}

// A destination with spaces or angle brackets goes in <...>; otherwise only \ and parentheses are escaped.
static NSString *ENRMLinkDestination(NSString *url)
{
  NSCharacterSet *needsBrackets = [NSCharacterSet characterSetWithCharactersInString:@"<> \t\n\r"];
  if ([url rangeOfCharacterFromSet:needsBrackets].location != NSNotFound ||
      [url rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) {
    return [NSString stringWithFormat:@"<%@>", ENRMEscaped(url, @"[\\\\<>]")];
  }
  return ENRMEscaped(url, @"[\\\\()]");
}

// `<https://x.dev>`, a bare URL, `www.x.dev` or an email, as the parser writes them: the label alone still
// pastes as the same link.
static BOOL ENRMIsAutolink(NSString *label, NSString *url)
{
  return [url isEqualToString:label] || [url isEqualToString:[@"mailto:" stringByAppendingString:label]] ||
         ([label hasPrefix:@"www."] && [url isEqualToString:[@"http://" stringByAppendingString:label]]);
}

NSString *ENRMMarkdownLink(NSString *label, NSString *url)
{
  if (ENRMIsAutolink(label, url))
    return label;
  return [NSString stringWithFormat:@"[%@](%@)", ENRMEscaped(label, @"[\\\\\\[\\]]"), ENRMLinkDestination(url)];
}

static void appendPlainText(MarkdownASTNode *node, NSMutableString *buffer, BOOL linksAsMarkdown)
{
  switch (node.type) {
    case MarkdownNodeTypeSoftBreak:
    case MarkdownNodeTypeLineBreak:
      [buffer appendString:@"\n"];
      break;
    case MarkdownNodeTypeBlankLine: {
      NSInteger count = [node.attributes[@"count"] integerValue];
      for (NSInteger i = 0; i < count; i++) {
        [buffer appendString:@"\n"];
      }
      break;
    }
    case MarkdownNodeTypeParagraph:
    case MarkdownNodeTypeHeading:
      for (MarkdownASTNode *child in node.children) {
        appendPlainText(child, buffer, linksAsMarkdown);
      }
      [buffer appendString:@"\n"];
      break;
    case MarkdownNodeTypeLink:
      if (linksAsMarkdown) {
        NSMutableString *label = [NSMutableString stringWithString:node.content ?: @""];
        for (MarkdownASTNode *child in node.children) {
          appendPlainText(child, label, linksAsMarkdown);
        }
        [buffer appendString:ENRMMarkdownLink(label, node.attributes[@"url"] ?: @"")];
        break;
      }
      // Without linksAsMarkdown a link is plain text like any other node.
      __attribute__((fallthrough));
    default:
      if (node.content.length > 0) {
        [buffer appendString:node.content];
      }
      for (MarkdownASTNode *child in node.children) {
        appendPlainText(child, buffer, linksAsMarkdown);
      }
      break;
  }
}

// --- Public API ---

NSString *markdownFromASTNode(MarkdownASTNode *node)
{
  if (!node)
    return @"";
  NSMutableString *buffer = [NSMutableString string];
  serializeNode(node, buffer);
  return [buffer copy];
}

NSString *markdownFromASTNodeChildren(MarkdownASTNode *node)
{
  if (!node)
    return @"";
  NSMutableString *buffer = [NSMutableString string];
  serializeChildren(node, buffer);
  return [buffer copy];
}

NSString *markdownFromTableCellNode(MarkdownASTNode *node)
{
  static NSCharacterSet *lineEndings;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ lineEndings = [NSCharacterSet characterSetWithCharactersInString:@"\r\n"]; });
  NSString *markdown = markdownFromASTNodeChildren(node);
  if ([markdown rangeOfCharacterFromSet:lineEndings].location == NSNotFound)
    return markdown;
  markdown = [markdown stringByReplacingOccurrencesOfString:@"(?<!\\\\)\\\\+(?=[\r\n])"
                                                 withString:@"$0$0"
                                                    options:NSRegularExpressionSearch
                                                      range:NSMakeRange(0, markdown.length)];
  markdown = [markdown stringByReplacingOccurrencesOfString:@"\r" withString:@"&#13;"];
  return [markdown stringByReplacingOccurrencesOfString:@"\n" withString:@"&#10;"];
}

NSString *markdownFromBlockquoteNode(MarkdownASTNode *node)
{
  if (!node)
    return @"";

  NSMutableString *result = [NSMutableString string];
  BOOL isAdmonition = (node.type == MarkdownNodeTypeAdmonition);

  if (isAdmonition) {
    NSString *type = node.attributes[@"admonitionType"];
    if (!type.length)
      type = @"note";
    [result appendFormat:@"> [!%@]\n", [type uppercaseString]];
  }

  NSMutableString *body = [NSMutableString string];
  serializeBlockChildren(node, body);

  NSString *trimmed = [body stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
  NSArray<NSString *> *lines = [trimmed componentsSeparatedByString:@"\n"];
  for (NSString *line in lines) {
    [result appendString:@"> "];
    [result appendString:line];
    [result appendString:@"\n"];
  }
  return [result copy];
}

static NSString *ENRMPlainText(MarkdownASTNode *node, BOOL linksAsMarkdown)
{
  if (!node)
    return @"";
  NSMutableString *buffer = [NSMutableString string];
  appendPlainText(node, buffer, linksAsMarkdown);
  return [[buffer copy] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

NSString *plainTextFromASTNode(MarkdownASTNode *node)
{
  return ENRMPlainText(node, NO);
}

NSString *plainTextWithMarkdownLinksFromASTNode(MarkdownASTNode *node)
{
  return ENRMPlainText(node, YES);
}
