#import "../../ios/attachments/ENRMLinkPillAttachment.h"
#import "../../ios/attachments/ENRMLinkPillTextStorage.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/CodeBackground.h"
#import "../../ios/utils/ENRMTextViewSetup.h"
#import "../../ios/utils/MarkdownExtractor.h"
#import "../../ios/utils/ParagraphStyleUtils.h"
#import <XCTest/XCTest.h>

@interface ENRMCountingPill : ENRMLinkPillAttachment
@property (nonatomic) NSUInteger boundsCalls;
@property (nonatomic) NSUInteger imageCalls;
@end

@implementation ENRMCountingPill
- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)container
                      proposedLineFragment:(CGRect)fragment
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)index
{
  self.boundsCalls++;
  return [super attachmentBoundsForTextContainer:container
                            proposedLineFragment:fragment
                                   glyphPosition:position
                                  characterIndex:index];
}
- (UIImage *)imageForBounds:(CGRect)bounds textContainer:(NSTextContainer *)container characterIndex:(NSUInteger)index
{
  UIImage *image = [super imageForBounds:bounds textContainer:container characterIndex:index];
  if (image)
    self.imageCalls++;
  return image;
}
@end

// Captures the real delegate's glyph writes without asking TextKit to generate a different input run.
@interface ENRMPillGlyphRecorder : NSLayoutManager
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *writtenGlyphs;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *writtenProperties;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *sourceIndexes;
@property (nonatomic) NSUInteger surroundingGlyphReads;
@end

@implementation ENRMPillGlyphRecorder
- (instancetype)init
{
  self = [super init];
  if (self) {
    _writtenGlyphs = [NSMutableDictionary new];
    _writtenProperties = [NSMutableDictionary new];
    _sourceIndexes = [NSMutableDictionary new];
  }
  return self;
}
- (void)setGlyphs:(const CGGlyph *)glyphs
          properties:(const NSGlyphProperty *)properties
    characterIndexes:(const NSUInteger *)indexes
                font:(UIFont *)font
       forGlyphRange:(NSRange)range
{
  for (NSUInteger i = 0; i < range.length; i++) {
    NSNumber *index = @(range.location + i);
    self.writtenGlyphs[index] = @(glyphs[i]);
    self.writtenProperties[index] = @(properties[i]);
    self.sourceIndexes[index] = @(indexes[i]);
  }
}
- (NSUInteger)characterIndexForGlyphAtIndex:(NSUInteger)index
{
  self.surroundingGlyphReads++;
  NSNumber *source = self.sourceIndexes[@(index)];
  return source ? source.unsignedIntegerValue : NSNotFound;
}
@end

@interface ENRMPillQueryStorage : ENRMLinkPillTextStorage
@property (nonatomic) NSUInteger longestAttachmentQueries;
@end
@implementation ENRMPillQueryStorage
- (id)attribute:(NSAttributedStringKey)name
                  atIndex:(NSUInteger)index
    longestEffectiveRange:(NSRangePointer)range
                  inRange:(NSRange)limit
{
  if ([name isEqualToString:NSAttachmentAttributeName])
    self.longestAttachmentQueries++;
  return [super attribute:name atIndex:index longestEffectiveRange:range inRange:limit];
}
@end

@interface ENRMLinkPillTextStorageTests : XCTestCase
@end

@implementation ENRMLinkPillTextStorageTests
- (ENRMCountingPill *)pill
{
  LinkVariantConfig *variant = [LinkVariantConfig new];
  variant.pill = YES;
  variant.label = @"file.ts";
  variant.color = UIColor.blackColor;
  variant.backgroundColor = UIColor.greenColor;
  variant.borderColor = UIColor.clearColor;
  variant.borderRadius = 8;
  variant.paddingHorizontal = 6;
  variant.paddingVertical = 2;
  return [[ENRMCountingPill alloc] initWithLinkText:@"src/a/long/original/path/file.ts"
                                            variant:variant
                                               font:[UIFont systemFontOfSize:16]];
}

- (NSMutableAttributedString *)labelWithPill:(ENRMLinkPillAttachment *)pill
{
  return [[NSMutableAttributedString alloc] initWithString:@"src/a/long/original/path/file.ts"
                                                attributes:@{
                                                  NSFontAttributeName : [UIFont systemFontOfSize:16],
                                                  NSForegroundColorAttributeName : UIColor.blueColor,
                                                  NSLinkAttributeName : @"https://example.com/original/file",
                                                  CodeAttributeName : @YES,
                                                  NSAttachmentAttributeName : pill,
                                                }];
}

- (void)testOrdinaryTextStorageReproducesLostPillAttribute
{
  NSTextStorage *storage = [[NSTextStorage alloc] initWithAttributedString:[self labelWithPill:self.pill]];
  [storage fixAttributesInRange:NSMakeRange(0, storage.length)];
  XCTAssertNil([storage attribute:NSAttachmentAttributeName atIndex:0 effectiveRange:NULL]);
  XCTAssertEqualObjects(storage.string, @"src/a/long/original/path/file.ts");
}

- (void)testPillSurvivesAutomaticAndExplicitFixingWithoutChangingSemanticText
{
  ENRMCountingPill *pill = self.pill;
  NSMutableAttributedString *label = [self labelWithPill:pill];
  NSRange range = NSMakeRange(0, label.length);
  NSString *markdown = extractMarkdownFromAttributedString(label, range);
  ENRMLinkPillTextStorage *storage = [[ENRMLinkPillTextStorage alloc] initWithAttributedString:label];
  [storage ensureAttributesAreFixedInRange:range];
  [storage fixAttributesInRange:range];
  XCTAssertEqualObjects(storage.string, label.string);
  XCTAssertFalse([storage.string containsString:@"\uFFFC"]);
  for (NSUInteger i = 0; i < storage.length; i++) {
    XCTAssertEqual([storage attribute:NSAttachmentAttributeName atIndex:i effectiveRange:NULL], pill);
    XCTAssertEqualObjects([storage attribute:NSLinkAttributeName atIndex:i effectiveRange:NULL],
                          @"https://example.com/original/file");
    XCTAssertEqualObjects([storage attribute:CodeAttributeName atIndex:i effectiveRange:NULL], @YES);
  }
  XCTAssertEqualObjects(extractMarkdownFromAttributedString(storage, range), markdown);
  [storage beginEditing];
  [storage addAttribute:NSForegroundColorAttributeName value:UIColor.redColor range:range];
  [storage endEditing];
  [storage ensureAttributesAreFixedInRange:range];
  XCTAssertEqual([storage attribute:NSAttachmentAttributeName atIndex:0 effectiveRange:NULL], pill);
  // Ordinary malformed attachments still get the standard Foundation fix.
  [storage appendAttributedString:[[NSAttributedString alloc]
                                      initWithString:@"X"
                                          attributes:@{NSAttachmentAttributeName : [NSTextAttachment new]}]];
  [storage ensureAttributesAreFixedInRange:NSMakeRange(0, storage.length)];
  XCTAssertNil([storage attribute:NSAttachmentAttributeName atIndex:storage.length - 1 effectiveRange:NULL]);
}

- (void)testPartialEditBeforePillPreservesAttachmentsThroughoutParagraph
{
  ENRMCountingPill *pill = self.pill;
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"Before "];
  [text appendAttributedString:[self labelWithPill:pill]];
  ENRMLinkPillTextStorage *storage = [[ENRMLinkPillTextStorage alloc] initWithAttributedString:text];
  [storage addAttribute:NSForegroundColorAttributeName value:UIColor.redColor range:NSMakeRange(0, 3)];
  [storage fixAttributesInRange:NSMakeRange(0, 3)];
  [storage ensureAttributesAreFixedInRange:NSMakeRange(0, storage.length)];
  for (NSUInteger i = @"Before ".length; i < storage.length; i++)
    XCTAssertEqual([storage attribute:NSAttachmentAttributeName atIndex:i effectiveRange:NULL], pill);
  XCTAssertEqualObjects(storage.string, text.string);
}

- (void)testRemovalAndReintroductionOfPillsPreservesFoundationFixingAndSource
{
  ENRMCountingPill *pill = self.pill;
  ENRMLinkPillTextStorage *storage =
      [[ENRMLinkPillTextStorage alloc] initWithAttributedString:[self labelWithPill:pill]];
  [storage removeAttribute:NSAttachmentAttributeName range:NSMakeRange(0, storage.length)];
  [storage replaceCharactersInRange:NSMakeRange(0, storage.length) withString:@"ordinary"];
  [storage addAttribute:NSAttachmentAttributeName value:[NSTextAttachment new] range:NSMakeRange(0, 1)];
  [storage fixAttributesInRange:NSMakeRange(0, storage.length)];
  XCTAssertNil([storage attribute:NSAttachmentAttributeName atIndex:0 effectiveRange:NULL]);
  XCTAssertEqualObjects(storage.string, @"ordinary");
  [storage setAttributedString:[self labelWithPill:pill]];
  [storage replaceCharactersInRange:NSMakeRange(1, 2) withString:@"expanded"];
  [storage fixAttributesInRange:NSMakeRange(0, storage.length)];
  for (NSUInteger index = 0; index < storage.length; index++)
    XCTAssertEqual([storage attribute:NSAttachmentAttributeName atIndex:index effectiveRange:NULL], pill);
  XCTAssertFalse([storage.string containsString:@"\uFFFC"]);
}

- (void)testAccessibleNameIncludesVisibleLabelAndRetainsOriginalLinkText
{
  ENRMCountingPill *pill = self.pill;
  XCTAssertEqualObjects(pill.linkAccessibilityLabel, @"file.ts, src/a/long/original/path/file.ts");
  LinkVariantConfig *variant = [LinkVariantConfig new];
  variant.label = @"original";
  ENRMLinkPillAttachment *same = [[ENRMLinkPillAttachment alloc] initWithLinkText:@"original" variant:variant font:nil];
  XCTAssertEqualObjects(same.linkAccessibilityLabel, @"original");
  variant.label = @"";
  ENRMLinkPillAttachment *fallback = [[ENRMLinkPillAttachment alloc] initWithLinkText:@"original"
                                                                              variant:variant
                                                                                 font:nil];
  XCTAssertEqualObjects(fallback.linkAccessibilityLabel, @"original");
}

- (void)testViewFreePillMeasurementUsesTheSameNoLeadingMetricsAsVisibleText
{
  NSMutableAttributedString *text = [self labelWithPill:self.pill];
  UIFont *font = [UIFont fontWithName:@"GeezaPro" size:40] ?: [UIFont systemFontOfSize:40];
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:@" السلام عليكم\nالسلام عليكم"
                                                               attributes:@{NSFontAttributeName : font}]];
  ENRMLinkPillTextStorage *storage = [[ENRMLinkPillTextStorage alloc] initWithAttributedString:text];
  NSLayoutManager *reference = [NSLayoutManager new];
  reference.usesFontLeading = NO;
  reference.delegate = ENRMLinkPillLayoutDelegate.shared;
  [storage addLayoutManager:reference];
  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(300, CGFLOAT_MAX)];
  container.lineFragmentPadding = 0;
  [reference addTextContainer:container];
  [reference ensureLayoutForTextContainer:container];
  CGRect expected = [reference usedRectForTextContainer:container];
  CGRect actual = ENRMLinkPillTextBounds(text, 300);
  XCTAssertEqualWithAccuracy(actual.size.height, expected.size.height, 0.01);
  XCTAssertEqualWithAccuracy(actual.size.width, expected.size.width, 0.01);
  [storage removeLayoutManager:reference];
}

- (CGRect)drawStorage:(NSTextStorage *)storage pill:(ENRMCountingPill *)pill usePillDelegate:(BOOL)usePillDelegate
{
  NSLayoutManager *manager = [NSLayoutManager new];
  manager.usesFontLeading = NO;
  if (usePillDelegate)
    manager.delegate = ENRMLinkPillLayoutDelegate.shared;
  [storage addLayoutManager:manager];
  NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(140, 200)];
  container.lineFragmentPadding = 0;
  [manager addTextContainer:container];
  [manager ensureLayoutForTextContainer:container];
  CGRect bounds = [manager usedRectForTextContainer:container];
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(140, 200)];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    [manager drawGlyphsForGlyphRange:[manager glyphRangeForTextContainer:container] atPoint:CGPointZero];
  }];
  XCTAssertNotNil(image.CGImage ? image : nil);
  size_t width = CGImageGetWidth(image.CGImage), height = CGImageGetHeight(image.CGImage);
  NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  CGContextRef bitmap = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, space,
                                              kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
  CGColorSpaceRelease(space);
  XCTAssertNotEqual(bitmap, NULL);
  if (bitmap) {
    CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), image.CGImage);
    CGContextRelease(bitmap);
    const uint8_t *bytes = (const uint8_t *)pixels.bytes;
    BOOL paintedGreen = NO;
    for (size_t offset = 0; offset < pixels.length; offset += 4)
      if (bytes[offset] == 0 && bytes[offset + 1] == 255 && bytes[offset + 2] == 0 && bytes[offset + 3] == 255)
        paintedGreen = YES;
    XCTAssertTrue(paintedGreen, @"The attachment must paint the pill background, not ordinary colored text");
  }
  XCTAssertGreaterThan(pill.boundsCalls, 0u);
  XCTAssertGreaterThan(pill.imageCalls, 0u);
  XCTAssertGreaterThan(bounds.size.width, 0);
  XCTAssertGreaterThanOrEqual(bounds.size.height, pill.boxHeight);
  [storage removeLayoutManager:manager];
  return bounds;
}

- (void)testOriginalLabelUsesSameAttachmentGeometryAsRealReplacementCharacter
{
  ENRMCountingPill *referencePill = self.pill;
  NSMutableAttributedString *reference = [self labelWithPill:referencePill];
  [reference replaceCharactersInRange:NSMakeRange(0, reference.length) withString:@"\uFFFC"];
  CGRect referenceBounds = [self drawStorage:[[NSTextStorage alloc] initWithAttributedString:reference]
                                        pill:referencePill
                             usePillDelegate:NO];
  ENRMCountingPill *pill = self.pill;
  ENRMLinkPillTextStorage *storage =
      [[ENRMLinkPillTextStorage alloc] initWithAttributedString:[self labelWithPill:pill]];
  CGRect originalBounds = [self drawStorage:storage pill:pill usePillDelegate:YES];
  XCTAssertEqualWithAccuracy(originalBounds.size.width, referenceBounds.size.width, 0.01);
  XCTAssertEqualWithAccuracy(originalBounds.size.height, referenceBounds.size.height, 0.01);
  XCTAssertEqualObjects(storage.string, @"src/a/long/original/path/file.ts");
}

- (void)testParagraphLineHeightFloorPreservesPillGeometryAndOriginalSource
{
  for (NSNumber *lineHeight in @[ @12, @64 ]) {
    ENRMCountingPill *referencePill = self.pill;
    NSMutableAttributedString *reference = [self labelWithPill:referencePill];
    [reference replaceCharactersInRange:NSMakeRange(0, reference.length) withString:@"\uFFFC"];
    applyLineHeight(reference, NSMakeRange(0, reference.length), lineHeight.doubleValue);
    applyBaselineOffset(reference, NSMakeRange(0, reference.length));
    CGRect referenceBounds = [self drawStorage:[[NSTextStorage alloc] initWithAttributedString:reference]
                                          pill:referencePill
                               usePillDelegate:NO];

    ENRMCountingPill *pill = self.pill;
    NSMutableAttributedString *label = [self labelWithPill:pill];
    NSRange range = NSMakeRange(0, label.length);
    NSString *markdown = extractMarkdownFromAttributedString(label, range);
    applyLineHeight(label, range, lineHeight.doubleValue);
    applyBaselineOffset(label, range);
    ENRMLinkPillTextStorage *storage = [[ENRMLinkPillTextStorage alloc] initWithAttributedString:label];
    CGRect bounds = [self drawStorage:storage pill:pill usePillDelegate:YES];
    XCTAssertGreaterThanOrEqual(bounds.size.height, lineHeight.doubleValue);
    XCTAssertEqualWithAccuracy(bounds.size.height, referenceBounds.size.height, 0.01);
    XCTAssertEqual(pill.imageCalls, referencePill.imageCalls);
    XCTAssertEqualObjects(storage.string, label.string);
    XCTAssertEqualObjects(extractMarkdownFromAttributedString(storage, range), markdown);
  }
}

- (void)fragmentLabelAttributes:(NSMutableAttributedString *)label
{
  [label beginEditing];
  for (NSUInteger i = 0; i < label.length; i++) {
    [label addAttribute:@"ENRMRegressionCharacter" value:@(i) range:NSMakeRange(i, 1)];
    [label addAttribute:NSForegroundColorAttributeName
                  value:i % 2 ? UIColor.redColor : UIColor.blueColor
                  range:NSMakeRange(i, 1)];
    [label addAttribute:NSFontAttributeName
                  value:i % 3 ? [UIFont italicSystemFontOfSize:16] : [UIFont systemFontOfSize:16]
                  range:NSMakeRange(i, 1)];
  }
  [label endEditing];
}

- (void)testPerCharacterAttributesStillDrawOnePillAndCannotBreakInsideOriginalLabel
{
  ENRMCountingPill *referencePill = self.pill;
  NSMutableAttributedString *reference = [self labelWithPill:referencePill];
  [reference replaceCharactersInRange:NSMakeRange(0, reference.length) withString:@"\uFFFC"];
  CGRect referenceBounds = [self drawStorage:[[NSTextStorage alloc] initWithAttributedString:reference]
                                        pill:referencePill
                             usePillDelegate:NO];
  ENRMCountingPill *pill = self.pill;
  NSMutableAttributedString *label = [self labelWithPill:pill];
  [self fragmentLabelAttributes:label];
  ENRMLinkPillTextStorage *storage = [[ENRMLinkPillTextStorage alloc] initWithAttributedString:label];
  CGRect bounds = [self drawStorage:storage pill:pill usePillDelegate:YES];
  XCTAssertEqual(pill.imageCalls, referencePill.imageCalls);
  XCTAssertEqualWithAccuracy(bounds.size.width, referenceBounds.size.width, 0.01);
  XCTAssertEqualWithAccuracy(bounds.size.height, referenceBounds.size.height, 0.01);
  XCTAssertEqualObjects(storage.string, label.string);
  NSLayoutManager *manager = [NSLayoutManager new];
  [storage addLayoutManager:manager];
  for (NSUInteger i = 0; i < storage.length; i++)
    XCTAssertEqual([ENRMLinkPillLayoutDelegate.shared layoutManager:manager
                        shouldBreakLineByWordBeforeCharacterAtIndex:i],
                   i == 0);
  [storage removeLayoutManager:manager];
}

- (void)testGlyphChunksAndLigatureIndexesEmitExactlyOneVirtualAttachment
{
  ENRMCountingPill *pill = self.pill;
  NSMutableAttributedString *label = [self labelWithPill:pill];
  [self fragmentLabelAttributes:label];
  ENRMLinkPillTextStorage *storage = [[ENRMLinkPillTextStorage alloc] initWithAttributedString:label];
  ENRMPillGlyphRecorder *manager = [ENRMPillGlyphRecorder new];
  [storage addLayoutManager:manager];
  CGGlyph glyphs[] = {1, 2, 3, 4};
  NSGlyphProperty properties[] = {0, 0, 0, 0};
  NSUInteger first[] = {0};
  NSUInteger continuation[] = {0, 1, 2};
  // A ligature skips a character index; a decomposed character can have repeated indexes.
  NSUInteger ligatures[] = {3, 5, 5, 6};
  ENRMLinkPillLayoutDelegate *delegate = ENRMLinkPillLayoutDelegate.shared;
  XCTAssertEqual([delegate layoutManager:manager
                     shouldGenerateGlyphs:glyphs
                               properties:properties
                         characterIndexes:first
                                     font:[UIFont systemFontOfSize:16]
                            forGlyphRange:NSMakeRange(0, 1)],
                 1u);
  XCTAssertEqual([delegate layoutManager:manager
                     shouldGenerateGlyphs:glyphs
                               properties:properties
                         characterIndexes:continuation
                                     font:[UIFont italicSystemFontOfSize:16]
                            forGlyphRange:NSMakeRange(1, 3)],
                 3u);
  XCTAssertEqual([delegate layoutManager:manager
                     shouldGenerateGlyphs:glyphs
                               properties:properties
                         characterIndexes:ligatures
                                     font:[UIFont systemFontOfSize:16]
                            forGlyphRange:NSMakeRange(4, 4)],
                 4u);
  XCTAssertEqualObjects(manager.writtenGlyphs[@0], @(0xFFFC));
  XCTAssertEqualObjects(manager.writtenProperties[@0], @0);
  for (NSUInteger i = 1; i < 8; i++) {
    XCTAssertEqualObjects(manager.writtenGlyphs[@(i)], @0);
    XCTAssertEqualObjects(manager.writtenProperties[@(i)], @(NSGlyphPropertyNull));
  }
  XCTAssertEqualObjects(storage.string, label.string);
  XCTAssertFalse([storage.string containsString:@"\uFFFC"]);
  XCTAssertEqual(manager.surroundingGlyphReads, 0u);
  [storage removeLayoutManager:manager];
}

- (void)testOrdinaryAndUnrelatedAttachmentRunsAvoidLongestRangeQueriesAndGlyphReplacement
{
  for (NSNumber *hasOtherAttachment in @[ @NO, @YES ]) {
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:hasOtherAttachment.boolValue ? @"\uFFFC ordinary text" : @"ordinary text"];
    [self fragmentLabelAttributes:text];
    if (hasOtherAttachment.boolValue)
      [text addAttribute:NSAttachmentAttributeName value:[NSTextAttachment new] range:NSMakeRange(0, 1)];
    ENRMPillQueryStorage *storage = [[ENRMPillQueryStorage alloc] initWithAttributedString:text];
    ENRMPillGlyphRecorder *manager = [ENRMPillGlyphRecorder new];
    [storage addLayoutManager:manager];
    NSAttributedString *before = [storage copy];
    storage.longestAttachmentQueries = 0;
    CGGlyph glyphs[] = {1, 2, 3, 4};
    NSGlyphProperty properties[] = {0, 0, 0, 0};
    NSUInteger indexes[] = {0, 1, 2, 3};
    XCTAssertEqual([ENRMLinkPillLayoutDelegate.shared layoutManager:manager
                                               shouldGenerateGlyphs:glyphs
                                                         properties:properties
                                                   characterIndexes:indexes
                                                               font:[UIFont systemFontOfSize:16]
                                                      forGlyphRange:NSMakeRange(0, 4)],
                   0u);
    for (NSUInteger i = 0; i < 4; i++)
      XCTAssertTrue([ENRMLinkPillLayoutDelegate.shared layoutManager:manager
                         shouldBreakLineByWordBeforeCharacterAtIndex:i]);
    XCTAssertEqual(storage.longestAttachmentQueries, 0u);
    XCTAssertEqual(manager.writtenGlyphs.count, 0u);
    XCTAssertEqual(manager.surroundingGlyphReads, 0u);
    XCTAssertTrue([storage isEqualToAttributedString:before]);
    [storage removeLayoutManager:manager];
  }
}

- (void)testVisibleTextViewRetainsCustomStorageAcrossStreamingReplacements
{
  UITextView *view = ENRMCreateMarkdownTextView();
  ENRMAttachLayoutManager(view, [StyleConfig new]);
  for (NSUInteger pass = 0; pass < 3; pass++) {
    ENRMCountingPill *pill = self.pill;
    view.attributedText = [self labelWithPill:pill];
    XCTAssertTrue([view.textStorage isKindOfClass:ENRMLinkPillTextStorage.class]);
    view.textContainer.size = CGSizeMake(140, 200);
    [view.layoutManager ensureLayoutForTextContainer:view.textContainer];
    XCTAssertGreaterThan(pill.boundsCalls, 0u);
    XCTAssertEqual([view.textStorage attribute:NSAttachmentAttributeName atIndex:0 effectiveRange:NULL], pill);
    XCTAssertEqualObjects(view.text, @"src/a/long/original/path/file.ts");
  }
}

- (void)testVisibleTextViewMeasuresOriginalCharactersAsOnePillAcrossStreamingReplacements
{
  UITextView *referenceView = ENRMCreateMarkdownTextView();
  UITextView *view = ENRMCreateMarkdownTextView();
  ENRMAttachLayoutManager(referenceView, [StyleConfig new]);
  ENRMAttachLayoutManager(view, [StyleConfig new]);
  for (NSUInteger pass = 0; pass < 3; pass++) {
    NSMutableAttributedString *reference = [self labelWithPill:self.pill];
    [reference replaceCharactersInRange:NSMakeRange(0, reference.length) withString:@"\uFFFC"];
    referenceView.attributedText = reference;
    NSMutableAttributedString *original = [self labelWithPill:self.pill];
    [self fragmentLabelAttributes:original];
    view.attributedText = original;
    for (UITextView *textView in @[ referenceView, view ]) {
      textView.textContainer.size = CGSizeMake(140, 200);
      [textView.layoutManager ensureLayoutForTextContainer:textView.textContainer];
    }
    CGRect expected = [referenceView.layoutManager usedRectForTextContainer:referenceView.textContainer];
    CGRect actual = [view.layoutManager usedRectForTextContainer:view.textContainer];
    XCTAssertEqualWithAccuracy(actual.size.width, expected.size.width, 0.01);
    XCTAssertEqualWithAccuracy(actual.size.height, expected.size.height, 0.01);
    XCTAssertEqualObjects(view.text, original.string);
    XCTAssertEqualObjects(extractMarkdownFromAttributedString(view.textStorage, NSMakeRange(0, original.length)),
                          extractMarkdownFromAttributedString(original, NSMakeRange(0, original.length)));
  }
}
@end
