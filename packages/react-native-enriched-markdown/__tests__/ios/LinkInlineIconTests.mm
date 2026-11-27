#import "../../ios/attachments/ENRMLinkIconAttachment.h"
#import "../../ios/attachments/ENRMLinkPillAttachment.h"
#import "../../ios/attachments/ENRMLinkPillText.h"
#include "../../ios/internals/MeasurementCache.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/HTMLGenerator.h"
#import <XCTest/XCTest.h>
#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>

@interface ENRMLinkInlineIconTests : XCTestCase
@end

@implementation ENRMLinkInlineIconTests {
  StyleConfig *_config;
  NSAttributedString *_text;
}

// "See [title](app://t/1) and [pill](app://p/1)." as rendered: an inline icon (placeholder and word joiner)
// before "title", and a pill placeholder for "pill". Built here rather than rendered: the test bundle
// links its own copy of the library, and NSClassFromString gives the classes the library code checks.
- (void)setUp
{
  NSString *iconPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"enrm-inline-icon.png"];
  UIImage *image = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(4, 4)]
      imageWithActions:^(UIGraphicsImageRendererContext *context) { [context fillRect:CGRectMake(0, 0, 4, 4)]; }];
  [UIImagePNGRepresentation(image) writeToFile:iconPath atomically:YES];
  UIFont *font = [UIFont systemFontOfSize:16];
  NSDictionary *attributes = @{NSFontAttributeName : font};

  ENRMLinkIconAttachment *icon = [[NSClassFromString(@"ENRMLinkIconAttachment") alloc] initWithIconUri:iconPath
                                                                                         iconTintColor:nil
                                                                                                  font:font
                                                                                        requestHeaders:nil];
  LinkVariantConfig *pillVariant = [NSClassFromString(@"LinkVariantConfig") new];
  pillVariant.pill = [NSClassFromString(@"LinkPillConfig") new];
  ENRMLinkPillAttachment *pill = [[NSClassFromString(@"ENRMLinkPillAttachment") alloc]
      initWithOriginalText:[[NSAttributedString alloc] initWithString:@"pill" attributes:attributes]
                   variant:pillVariant
                     label:nil
                   iconUri:nil
             iconTintColor:nil
                      font:font
            requestHeaders:nil];

  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"See " attributes:attributes];
  [text appendAttributedString:[NSAttributedString attributedStringWithAttachment:icon]];
  NSMutableDictionary *joiner = [attributes mutableCopy];
  joiner[ENRMLinkIconJoinerAttributeName] = @YES;
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u2060" attributes:joiner]];
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"title and " attributes:attributes]];
  [text appendAttributedString:[NSAttributedString attributedStringWithAttachment:pill]];
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"." attributes:attributes]];
  _text = text;
  _config = [[StyleConfig alloc] init];
}

- (NSRange)rangeOf:(NSString *)needle
{
  return [_text.string rangeOfString:needle];
}

// The icon is a placeholder and a word joiner in storage; neither leaves the view, and the pill is its text again.
- (void)testCopiedTextHasNoIconCharacters
{
  XCTAssertTrue([_text.string containsString:@"\uFFFC\u2060title"], @"%@", _text.string);
  XCTAssertEqualObjects(ENRMStringByExpandingLinkPills(_text), @"See title and pill.");
  NSString *html = generateHTML(_text, _config);
  XCTAssertFalse([html containsString:@"\uFFFC"], @"%@", html);
  XCTAssertFalse([html containsString:@"\u2060"], @"%@", html);
}

// A selection maps to the same text once the icon is gone and the pill is expanded.
- (void)testSelectionRangesMapAcrossTheIconAndAPill
{
  NSUInteger icon = [self rangeOf:@"\uFFFC\u2060"].location;
  NSUInteger pill = NSMaxRange([self rangeOf:@" and "]);
  NSString *expected[] = {@"title", @"title", @"title and pill"};
  NSRange selections[] = {
      NSMakeRange(icon, NSMaxRange([self rangeOf:@"title"]) - icon),         // starts at the icon
      NSMakeRange(icon + 1, NSMaxRange([self rangeOf:@"title"]) - icon - 1), // starts between icon and joiner
      NSMakeRange(icon, pill + 1 - icon),                                    // spans the icon and the pill
  };
  for (int i = 0; i < 3; i++) {
    NSRange range = selections[i];
    NSAttributedString *expanded = ENRMAttributedStringByExpandingLinkPills(_text, &range);
    XCTAssertEqualObjects([expanded.string substringWithRange:range], expected[i], @"selection %d", i);
  }
}

// Selection reads only the selected slice, which can start between the icon and its joiner.
- (void)testASliceStartingAtTheWordJoinerDropsIt
{
  NSUInteger joiner = [self rangeOf:@"\u2060"].location;
  NSRange title = [self rangeOf:@"title"];
  NSAttributedString *slice = [_text attributedSubstringFromRange:NSMakeRange(joiner, NSMaxRange(title) - joiner)];
  XCTAssertEqualObjects(ENRMStringByExpandingLinkPills(slice), @"title");
}

// onTextPress reports the text without icon characters, and the tapped character's index in it.
- (void)testATextPressIndexMapsIntoTheExpandedText
{
  NSUInteger index = [self rangeOf:@"."].location;
  NSString *text = ENRMStringByExpandingLinkPillsAtIndex(_text, &index);
  XCTAssertEqualObjects(text, @"See title and pill.");
  XCTAssertEqual([text characterAtIndex:index], '.');

  // A press on the icon reports the link's first character.
  index = [self rangeOf:@"\u2060"].location;
  ENRMStringByExpandingLinkPillsAtIndex(_text, &index);
  XCTAssertEqual([text characterAtIndex:index], 't');
}

// A new icon changes the measured width, so it must change the cached-measurement key.
- (void)testTheStyleFingerprintFollowsTheInlineIcon
{
  facebook::react::EnrichedMarkdownTextMarkdownStyleStruct style{};
  style.linkVariants.push_back({});
  style.linkVariants[0].inlineIcon.iconUri = "a.png";
  size_t first = facebook::react::computeStyleFingerprint(style);
  style.linkVariants[0].inlineIcon.iconUri = "b.png";
  XCTAssertNotEqual(first, facebook::react::computeStyleFingerprint(style));
}

@end
