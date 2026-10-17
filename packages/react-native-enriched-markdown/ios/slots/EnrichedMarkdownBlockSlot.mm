#import "EnrichedMarkdownBlockSlot.h"

#import <ReactNativeEnrichedMarkdown/ComponentDescriptors.h>
#import <ReactNativeEnrichedMarkdown/Props.h>
#import <ReactNativeEnrichedMarkdown/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

using namespace facebook::react;

@interface EnrichedMarkdownBlockSlot () <RCTEnrichedMarkdownBlockSlotViewProtocol>
@end

@implementation EnrichedMarkdownBlockSlot

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
  }
  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newViewProps = *std::static_pointer_cast<EnrichedMarkdownBlockSlotProps const>(props);
  _slotId = [[NSString alloc] initWithUTF8String:newViewProps.slotId.c_str()] ?: @"";
  [super updateProps:props oldProps:oldProps];
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  _slotId = @"";
}

@end

Class<RCTComponentViewProtocol> EnrichedMarkdownBlockSlotCls(void)
{
  return EnrichedMarkdownBlockSlot.class;
}
