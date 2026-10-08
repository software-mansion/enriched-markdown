#import "PasteboardUtils.h"
#import "ENRMImageAttachment.h"
#import "ENRMLinkPillText.h"
#import "HTMLGenerator.h"
#import "MarkdownExtractor.h"
#import "RTFExportUtils.h"
#import "StyleConfig.h"
#include <TargetConditionals.h>
#if !TARGET_OS_OSX
#import <UIKit/UIPasteboard.h>
#endif

static NSString *const kUTIRTFD = @"com.apple.rtfd";
static NSString *const kUTIFlatRTFD = @"com.apple.flat-rtfd";
static NSString *const kUTIRTF = @"public.rtf";

#pragma mark - Private Helpers

static void addRTFData(NSMutableDictionary *items, NSAttributedString *attributedString, NSRange range,
                       NSString *documentType, NSString *uti)
{
  NSError *error = nil;
  NSData *data = [attributedString dataFromRange:range
                              documentAttributes:@{NSDocumentTypeDocumentAttribute : documentType}
                                           error:&error];
  if (data && !error) {
    items[uti] = data;
  }
}

static void addRTFDData(NSMutableDictionary *items, NSAttributedString *attributedString, NSRange range)
{
  NSError *error = nil;
  NSFileWrapper *wrapper =
      [attributedString fileWrapperFromRange:range
                          documentAttributes:@{NSDocumentTypeDocumentAttribute : NSRTFDTextDocumentType}
                                       error:&error];
  if (wrapper && !error) {
    NSData *data = [wrapper serializedRepresentation];
    if (data) {
      items[kUTIFlatRTFD] = data;
    }
  }
}

static void addHTMLData(NSMutableDictionary *items, NSAttributedString *attributedString, StyleConfig *styleConfig)
{
  NSString *html = generateHTML(attributedString, styleConfig);
  if (html) {
    NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
    if (data) {
      items[kUTIHTML] = data;
    }
  }
}

#pragma mark - Public API

static NSString *canonicalClipboardText(NSAttributedString *text, StyleConfig *config)
{
  NSDictionary *links = config.selectionClipboard[@"linkTextByUrl"];
  if (![links isKindOfClass:NSDictionary.class])
    return nil;
  NSMutableString *result = [text.string mutableCopy];
  __block BOOL matched = NO;
  [text enumerateAttribute:NSLinkAttributeName
                   inRange:NSMakeRange(0, text.length)
                   options:NSAttributedStringEnumerationReverse
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  NSString *replacement = value ? links[[value description]] : nil;
                  if ([replacement isKindOfClass:NSString.class]) {
                    [result replaceCharactersInRange:range withString:replacement];
                    matched = YES;
                  }
                }];
  return matched ? result : nil;
}

static NSString *escapeClipboardAttribute(NSString *value)
{
  return [[[[value stringByReplacingOccurrencesOfString:@"&"
                                             withString:@"&amp;"] stringByReplacingOccurrencesOfString:@"\""
                                                                                            withString:@"&quot;"]
      stringByReplacingOccurrencesOfString:@"<"
                                withString:@"&lt;"] stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
}

static void addSelectionMetadata(NSMutableDictionary *items, StyleConfig *config)
{
  NSDictionary *attributes = config.selectionClipboard[@"htmlAttributes"];
  NSMutableArray *encoded = [NSMutableArray array];
  if ([attributes isKindOfClass:NSDictionary.class]) {
    NSRegularExpression *validName = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z_][A-Za-z0-9:_-]*$"
                                                                               options:0
                                                                                 error:nil];
    for (id name in attributes) {
      id value = attributes[name];
      if ([name isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class] &&
          [validName numberOfMatchesInString:name options:0 range:NSMakeRange(0, [name length])] == 1)
        [encoded addObject:[NSString stringWithFormat:@"%@=\"%@\"", name, escapeClipboardAttribute(value)]];
    }
  }
  NSString *html = [[NSString alloc] initWithData:items[kUTIHTML] encoding:NSUTF8StringEncoding];
  if (html && encoded.count > 0)
    items[kUTIHTML] = [[NSString stringWithFormat:@"<div %@>%@</div>", [encoded componentsJoinedByString:@" "], html]
        dataUsingEncoding:NSUTF8StringEncoding];
#if !TARGET_OS_OSX
  NSDictionary *types = config.selectionClipboard[@"mimeTypes"];
  if ([types isKindOfClass:NSDictionary.class]) {
    for (id type in types) {
      id value = types[type];
      if ([type isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class] && !items[type])
        items[type] = [value dataUsingEncoding:NSUTF8StringEncoding];
    }
  }
#endif
}

void copySelectionMarkdownToPasteboard(NSString *markdown, NSAttributedString *selection, StyleConfig *config)
{
  selection = ENRMAttributedStringByExpandingLinkPills(selection, NULL);
  if (!canonicalClipboardText(selection, config)) {
    copyStringToPasteboard(markdown);
    return;
  }
  NSMutableDictionary *items = [@{
    kUTIPlainText : markdown,
    kUTIMarkdown : markdown,
    kUTIHTML : [[NSString stringWithFormat:@"<pre>%@</pre>", escapeClipboardAttribute(markdown)]
        dataUsingEncoding:NSUTF8StringEncoding]
  } mutableCopy];
  addSelectionMetadata(items, config);
  copyItemsToPasteboard(items);
}

void copyStringToPasteboard(NSString *string)
{
#if !TARGET_OS_OSX
  [[UIPasteboard generalPasteboard] setString:string];
#else
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  [pasteboard setString:string forType:kUTIPlainText];
#endif
}

void copyItemsToPasteboard(NSDictionary<NSString *, id> *items)
{
#if !TARGET_OS_OSX
  [[UIPasteboard generalPasteboard] setItems:@[ items ]];
#else
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  for (NSString *type in items) {
    id value = items[type];
    if ([value isKindOfClass:[NSString class]]) {
      [pasteboard setString:value forType:type];
    } else if ([value isKindOfClass:[NSData class]]) {
      [pasteboard setData:value forType:type];
    }
  }
#endif
}

void copyAttributedStringToPasteboard(NSAttributedString *attributedString, NSString *_Nullable markdown,
                                      StyleConfig *_Nullable styleConfig)
{
  if (!attributedString || attributedString.length == 0)
    return;

  // Expanded once here for the plain-text flavor; the exporters below then have nothing left to expand.
  attributedString = ENRMAttributedStringByExpandingLinkPills(attributedString, NULL);

  NSMutableDictionary *items = [NSMutableDictionary dictionary];

  NSString *canonicalText = canonicalClipboardText(attributedString, styleConfig);
  items[kUTIPlainText] = canonicalText ?: attributedString.string;

  if (markdown.length > 0) {
    items[kUTIMarkdown] = markdown;
  }

  if (styleConfig) {
    addHTMLData(items, attributedString, styleConfig);
  }
  if (canonicalText)
    addSelectionMetadata(items, styleConfig);

  // RTF export requires preprocessing (backgrounds, markers, normalized spacing)
  NSAttributedString *rtfPrepared = prepareAttributedStringForRTFExport(attributedString, styleConfig);
  NSRange rtfRange = NSMakeRange(0, rtfPrepared.length);

  addRTFDData(items, rtfPrepared, rtfRange);
  addRTFData(items, rtfPrepared, rtfRange, NSRTFTextDocumentType, kUTIRTF);

  copyItemsToPasteboard(items);
}

#pragma mark - Content Extraction

NSString *_Nullable markdownForRange(NSAttributedString *attributedText, NSRange range,
                                     NSString *_Nullable cachedMarkdown)
{
  if (!cachedMarkdown || range.length == 0)
    return nil;

  if (!attributedText || range.location >= attributedText.length)
    return nil;

  range.length = MIN(range.length, attributedText.length - range.location);

  // Full selection: use cached markdown directly
  BOOL isFullSelection = (range.location == 0 && range.length >= attributedText.length - 1);
  if (isFullSelection) {
    return cachedMarkdown;
  }

  // Partial selection: reverse-engineer from attributes
  return extractMarkdownFromAttributedString(attributedText, range);
}

NSArray<NSString *> *imageURLsInRange(NSAttributedString *attributedText, NSRange range)
{
  if (!attributedText || range.location == NSNotFound || range.length == 0 || range.location >= attributedText.length) {
    return @[];
  }

  range.length = MIN(range.length, attributedText.length - range.location);

  NSMutableArray<NSString *> *urls = [NSMutableArray array];

  [attributedText enumerateAttribute:NSAttachmentAttributeName
                             inRange:range
                             options:0
                          usingBlock:^(id value, NSRange r, BOOL *stop) {
                            if (![value isKindOfClass:[ENRMImageAttachment class]])
                              return;

                            NSString *url = ((ENRMImageAttachment *)value).imageURL;
                            if ([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"]) {
                              [urls addObject:url];
                            }
                          }];

  return urls;
}
