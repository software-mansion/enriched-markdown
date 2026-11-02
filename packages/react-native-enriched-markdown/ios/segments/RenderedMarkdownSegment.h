#pragma once

#import <Foundation/Foundation.h>

@class ENRMRenderResult;
@class MarkdownASTNode;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ENRMSegmentKind) {
  ENRMSegmentKindText,
  ENRMSegmentKindTable,
  ENRMSegmentKindMath,
  ENRMSegmentKindCodeBlock,
  ENRMSegmentKindBlockquote,
  ENRMSegmentKindVideo,
  ENRMSegmentKindBlockSlot
};

typedef NS_ENUM(NSInteger, ENRMBlockSlotKind) {
  ENRMBlockSlotKindImage,
  ENRMBlockSlotKindVideo,
  ENRMBlockSlotKindLink,
};

@interface ENRMTextSegment : NSObject
@property (nonatomic, strong) NSArray<MarkdownASTNode *> *nodes;
+ (instancetype)segmentWithNodes:(NSArray<MarkdownASTNode *> *)nodes;
@end

@interface ENRMTableSegment : NSObject
@property (nonatomic, strong) MarkdownASTNode *tableNode;
+ (instancetype)segmentWithTableNode:(MarkdownASTNode *)node;
@end

@interface ENRMMathSegment : NSObject
@property (nonatomic, strong) NSString *latex;
+ (instancetype)segmentWithLatex:(NSString *)latex;
@end

@interface ENRMCodeBlockSegment : NSObject
@property (nonatomic, strong) MarkdownASTNode *codeBlockNode;
+ (instancetype)segmentWithCodeBlockNode:(MarkdownASTNode *)node;
@end

@interface ENRMBlockquoteSegment : NSObject
@property (nonatomic, strong) MarkdownASTNode *blockquoteNode;
+ (instancetype)segmentWithBlockquoteNode:(MarkdownASTNode *)node;
@end

@interface ENRMVideoSegment : NSObject
@property (nonatomic, strong) MarkdownASTNode *videoNode;
+ (instancetype)segmentWithVideoNode:(MarkdownASTNode *)node;
@end

// A block a React child stands in for (see BlockSlots.hpp): the image paragraph or
// video node carrying the `blockSlotId` attribute. The host reserves its height and
// Fabric places the child there.
@interface ENRMBlockSlotSegment : NSObject
@property (nonatomic, copy) NSString *slotId;
@property (nonatomic, assign) ENRMBlockSlotKind kind;
+ (instancetype)segmentWithSlotId:(NSString *)slotId kind:(ENRMBlockSlotKind)kind;
@end

@interface ENRMRenderedSegment : NSObject
@property (nonatomic, assign) ENRMSegmentKind kind;
@property (nonatomic, assign) uint64_t signature;
@property (nonatomic, strong, nullable) ENRMRenderResult *textResult;
@property (nonatomic, strong, nullable) ENRMTableSegment *tableSegment;
@property (nonatomic, strong, nullable) ENRMMathSegment *mathSegment;
@property (nonatomic, strong, nullable) ENRMCodeBlockSegment *codeBlockSegment;
@property (nonatomic, strong, nullable) ENRMBlockquoteSegment *blockquoteSegment;
@property (nonatomic, strong, nullable) ENRMVideoSegment *videoSegment;
@property (nonatomic, strong, nullable) ENRMBlockSlotSegment *blockSlotSegment;
+ (instancetype)textSegmentWithResult:(ENRMRenderResult *)result signature:(uint64_t)signature;
+ (instancetype)tableSegmentWithSegment:(ENRMTableSegment *)segment signature:(uint64_t)signature;
+ (instancetype)mathSegmentWithSegment:(ENRMMathSegment *)segment signature:(uint64_t)signature;
+ (instancetype)codeBlockSegmentWithSegment:(ENRMCodeBlockSegment *)segment signature:(uint64_t)signature;
+ (instancetype)blockquoteSegmentWithSegment:(ENRMBlockquoteSegment *)segment signature:(uint64_t)signature;
+ (instancetype)videoSegmentWithSegment:(ENRMVideoSegment *)segment signature:(uint64_t)signature;
+ (instancetype)blockSlotSegmentWithSegment:(ENRMBlockSlotSegment *)segment signature:(uint64_t)signature;
@end

#ifdef __cplusplus
extern "C" {
#endif

uint64_t ENRMSignatureForNode(MarkdownASTNode *_Nullable node);
uint64_t ENRMSignatureForNodes(NSArray<MarkdownASTNode *> *nodes);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
