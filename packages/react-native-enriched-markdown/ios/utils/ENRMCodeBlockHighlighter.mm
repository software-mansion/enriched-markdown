#import "ENRMCodeBlockHighlighter.h"
#include "CodeBlockHighlighter.hpp"
#import "ENRMUIKit.h"

static RCTUIColor *ENRMHexColor(uint32_t rgb)
{
  return [RCTUIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                            green:((rgb >> 8) & 0xFF) / 255.0
                             blue:(rgb & 0xFF) / 255.0
                            alpha:1.0];
}

// TODO: provisional palette (GitHub light scheme); replace with themable
// per-token colors on the code block style when the highlighting module lands.
static RCTUIColor *ENRMColorForToken(Markdown::HighlightTokenType type)
{
  switch (type) {
    case Markdown::HighlightTokenType::Keyword:
      return ENRMHexColor(0xCF222E);
    case Markdown::HighlightTokenType::String:
      return ENRMHexColor(0x0A3069);
    case Markdown::HighlightTokenType::Number:
    case Markdown::HighlightTokenType::Constant:
    case Markdown::HighlightTokenType::Property:
    case Markdown::HighlightTokenType::Attribute:
      return ENRMHexColor(0x0550AE);
    case Markdown::HighlightTokenType::Comment:
      return ENRMHexColor(0x6E7781);
    case Markdown::HighlightTokenType::Function:
      return ENRMHexColor(0x8250DF);
    case Markdown::HighlightTokenType::Type:
      return ENRMHexColor(0x953800);
    case Markdown::HighlightTokenType::Tag:
      return ENRMHexColor(0x116329);
    default:
      return nil;
  }
}

NSAttributedString *ENRMHighlightedAttributedCode(NSAttributedString *plainCode, NSString *code,
                                                  NSString *_Nullable language)
{
  if (code.length == 0) {
    return nil;
  }

  std::vector<Markdown::HighlightToken> tokens;
  try {
    tokens = Markdown::highlightCode(code.UTF8String ?: "", language.UTF8String ?: "");
  } catch (...) {
    return nil;
  }
  if (tokens.empty()) {
    return nil;
  }

  NSMutableAttributedString *highlighted = [plainCode mutableCopy];
  NSUInteger length = highlighted.length;
  BOOL applied = NO;
  for (const auto &token : tokens) {
    RCTUIColor *color = ENRMColorForToken(token.type);
    if (!color || token.end <= token.start || token.end > length) {
      continue;
    }
    [highlighted addAttribute:NSForegroundColorAttributeName
                        value:color
                        range:NSMakeRange(token.start, token.end - token.start)];
    applied = YES;
  }
  return applied ? highlighted : nil;
}
