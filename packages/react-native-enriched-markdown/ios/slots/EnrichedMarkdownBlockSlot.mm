#import "EnrichedMarkdownBlockSlot.h"
#import "ENRMBlockSlotReveal.h"

#import <ReactNativeEnrichedMarkdown/ComponentDescriptors.h>
#import <ReactNativeEnrichedMarkdown/Props.h>
#import <ReactNativeEnrichedMarkdown/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

using namespace facebook::react;

@interface EnrichedMarkdownBlockSlot () <RCTEnrichedMarkdownBlockSlotViewProtocol>
@end

@implementation EnrichedMarkdownBlockSlot {
  CGFloat _revealOffset;
  CGFloat _revealClipHeight;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<EnrichedMarkdownBlockSlotComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const EnrichedMarkdownBlockSlotProps>();
    _props = defaultProps;
    _slotId = @"";
    _revealClipHeight = ENRMBlockSlotNoClip;
  }
  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<EnrichedMarkdownBlockSlotProps const>(props);
  _slotId = [[NSString alloc] initWithUTF8String:newViewProps.slotId.c_str()] ?: @"";
  [super updateProps:props oldProps:oldProps];
}

- (void)finalizeUpdates:(RNComponentViewUpdateMask)updateMask
{
  // Fabric resets the layer mask when it updates the layer.
  [super finalizeUpdates:updateMask];
  [self applyReveal];
}

#if !TARGET_OS_OSX
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  // So does a trait change (dark mode).
  [super traitCollectionDidChange:previousTraitCollection];
  [self applyReveal];
}
#endif

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  _slotId = @"";
  [self setRevealOffset:0 clipHeight:ENRMBlockSlotNoClip];
}

- (void)setRevealOffset:(CGFloat)offset clipHeight:(CGFloat)clipHeight
{
  if (offset == _revealOffset && clipHeight == _revealClipHeight) {
    return;
  }
  _revealOffset = offset;
  _revealClipHeight = clipHeight;
  [self applyReveal];
}

// The slot root never gets a transform, overflow or border style, so the
// transform and the mask are ours alone.
- (void)applyReveal
{
  ENRMApplyBlockSlotReveal(self.layer, _revealOffset, _revealClipHeight);
}

#if !TARGET_OS_OSX
// A growing slot keeps its full height, overlapping the text below what shows,
// so it takes no touches until it is in.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  return _revealClipHeight == ENRMBlockSlotNoClip ? [super hitTest:point withEvent:event] : nil;
}
#endif

@end

Class<RCTComponentViewProtocol> EnrichedMarkdownBlockSlotCls(void)
{
  return EnrichedMarkdownBlockSlot.class;
}
