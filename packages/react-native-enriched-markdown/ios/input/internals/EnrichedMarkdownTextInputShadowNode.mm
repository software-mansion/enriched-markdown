#import "EnrichedMarkdownTextInputShadowNode.h"
#import "ENRMEditSession.h"
#import "EnrichedMarkdownTextInput.h"
#import <react/utils/ManagedObjectWrapper.h>
#import <yoga/Yoga.h>

namespace facebook::react {

extern const char EnrichedMarkdownTextInputComponentName[] = "EnrichedMarkdownTextInput";

EnrichedMarkdownTextInputShadowNode::EnrichedMarkdownTextInputShadowNode(const ShadowNodeFragment &fragment,
                                                                         const ShadowNodeFamily::Shared &family,
                                                                         ShadowNodeTraits traits)
    : ConcreteViewShadowNode(fragment, family, traits)
{
}

EnrichedMarkdownTextInputShadowNode::EnrichedMarkdownTextInputShadowNode(const ShadowNode &sourceShadowNode,
                                                                         const ShadowNodeFragment &fragment)
    : ConcreteViewShadowNode(sourceShadowNode, fragment)
{
  dirtyLayoutIfNeeded();
}

void EnrichedMarkdownTextInputShadowNode::dirtyLayoutIfNeeded()
{
  const auto state = this->getStateData();
  const int receivedCounter = state.getHeightRecalculationCounter();

  if (receivedCounter > localHeightRecalculationCounter_) {
    localHeightRecalculationCounter_ = receivedCounter;
    YGNodeMarkDirty(&yogaNode_);
  }
}

id EnrichedMarkdownTextInputShadowNode::setupMockInputView_(CGFloat width) const
{
  EnrichedMarkdownTextInput *mockView =
      [[EnrichedMarkdownTextInput alloc] initWithFrame:CGRectMake(20000, 20000, width, 1000)];

  [mockView.editSession enterPhase:ENRMEditPhaseImporting];

  const auto props = this->getProps();
  [mockView updateProps:props oldProps:nullptr];

  return mockView;
}

Size EnrichedMarkdownTextInputShadowNode::measureContent(const LayoutContext &layoutContext,
                                                         const LayoutConstraints &layoutConstraints) const
{
  CGFloat maxWidth = layoutConstraints.maximumSize.width;

  RCTInternalGenericWeakWrapper *weakWrapper =
      (RCTInternalGenericWeakWrapper *)unwrapManagedObject(getStateData().getComponentViewRef());
  EnrichedMarkdownTextInput *view = weakWrapper ? (EnrichedMarkdownTextInput *)weakWrapper.object : nil;

  __block Float clampedWidth;
  __block Float clampedHeight;

  void (^measureBlock)(void) = ^{
    CGSize size;
    if (view) {
      size = [view measureSize:maxWidth];
    } else {
      EnrichedMarkdownTextInput *mockView = setupMockInputView_(maxWidth);
      size = [mockView measureSize:maxWidth];
    }

    clampedWidth = std::max((Float)size.width, layoutConstraints.minimumSize.width);
    clampedWidth = std::min(clampedWidth, layoutConstraints.maximumSize.width);
    clampedHeight = std::max((Float)size.height, layoutConstraints.minimumSize.height);
    if (std::isfinite(layoutConstraints.maximumSize.height)) {
      clampedHeight = std::min(clampedHeight, layoutConstraints.maximumSize.height);
    }

    [view didMeasureWithMaxHeight:layoutConstraints.maximumSize.height measuredHeight:clampedHeight];
  };

  if ([NSThread isMainThread]) {
    measureBlock();
  } else {
    dispatch_sync(dispatch_get_main_queue(), measureBlock);
  }

  return {clampedWidth, clampedHeight};
}

} // namespace facebook::react
