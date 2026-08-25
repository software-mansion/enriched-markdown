#import "MarkdownASTSerializer.h"
#import "MarkdownASTNode.h"

static void serializeNode(MarkdownASTNode *node, NSMutableString *buffer);
static void serializeChildren(MarkdownASTNode *node, NSMutableString *buffer);

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

    case MarkdownNodeTypeCode:
      [buffer appendString:@"`"];
      serializeChildren(node, buffer);
      [buffer appendString:@"`"];
      break;

    case MarkdownNodeTypeLink: {
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

    case MarkdownNodeTypeParagraph:
    default:
      serializeChildren(node, buffer);
      break;
  }
}

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
