#import "ENRMNestedSegmentViewRegistry.h"
#import "ENRMBlockSlotSegmentView.h"
#import "ENRMBlockquoteContainerView.h"
#import "ENRMCodeBlockContainerView.h"
#import "ENRMFeatureFlags.h"
#import "ENRMListContainerView.h"
#import "ENRMTextRenderer.h"
#import "EnrichedMarkdownInternalText.h"
#import "TableContainerView.h"
#if ENRICHED_MARKDOWN_MATH
#import "ENRMMathContainerView.h"
#endif
#if ENRICHED_MARKDOWN_VIDEO
#import "ENRMVideoContainerView.h"
#endif

void ENRMConfigureNestedHost(id<ENRMNestedSegmentHost> child, id<ENRMNestedSegmentHost> parent)
{
  ENRMSetWritingDirection(child, parent.writingDirectionMode, parent.resolvedLayoutDirection);
  child.onSelectionCopy = parent.onSelectionCopy;
  child.allowFontScaling = parent.allowFontScaling;
  child.lineBreakStrategy = parent.lineBreakStrategy;
  child.dynamicProps = parent.dynamicProps;
  child.accessibilityLabels = parent.accessibilityLabels;
  child.onLinkPress = parent.onLinkPress;
  child.onLinkLongPress = parent.onLinkLongPress;
  child.onImagePress = parent.onImagePress;
  child.onTextPress = parent.onTextPress;
  child.onCopyPress = parent.onCopyPress;
  child.onCodeBlockPress = parent.onCodeBlockPress;
  child.onTaskListItemPress = parent.onTaskListItemPress;
  child.createLeafView = parent.createLeafView;
  child.updateLeafView = parent.updateLeafView;
}

ENRMSegmentViewRegistry *ENRMCreateNestedSegmentRegistry(id<ENRMNestedSegmentHost> host)
{
  StyleConfig *config = host.config;
  __weak id<ENRMNestedSegmentHost> weakSelf = host;
  NSMutableArray<ENRMSegmentViewHandler *> *handlers = [NSMutableArray array];

  [handlers
      addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindText
                    matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                      return [view isKindOfClass:[EnrichedMarkdownInternalText class]];
                    }
                    createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                      id<ENRMNestedSegmentHost> strongSelf = weakSelf;
                      EnrichedMarkdownInternalText *view = [[EnrichedMarkdownInternalText alloc] initWithConfig:config];
                      view.onSelectionCopy = strongSelf.onSelectionCopy;
                      view.lastElementMarginBottom = segment.textResult.lastElementMarginBottom;
                      view.accessibilityInfo = segment.textResult.accessibilityInfo;
                      view.accessibilityLabels = strongSelf.accessibilityLabels;
                      [view applyAttributedText:segment.textResult.attributedText context:segment.textResult.context];
                      if (strongSelf) {
                        [strongSelf configureNestedTextView:view];
                      }
                      return view;
                    }
                    updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                      EnrichedMarkdownInternalText *textView = (EnrichedMarkdownInternalText *)view;
                      textView.lastElementMarginBottom = segment.textResult.lastElementMarginBottom;
                      textView.accessibilityInfo = segment.textResult.accessibilityInfo;
                      [textView applyAttributedText:segment.textResult.attributedText
                                            context:segment.textResult.context];
                    }]];

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindTable
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[TableContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            TableContainerView *view = [[TableContainerView alloc] initWithConfig:config];
                            id<ENRMNestedSegmentHost> strongSelf = weakSelf;
                            if (strongSelf) {
                              ENRMSetWritingDirection(view, strongSelf.writingDirectionMode,
                                                      strongSelf.resolvedLayoutDirection);
                              view.dynamicProps = strongSelf.dynamicProps;
                              view.accessibilityLabels = strongSelf.accessibilityLabels;
                              view.onLinkPress = ^(NSString *url) {
                                id<ENRMNestedSegmentHost> s = weakSelf;
                                if (s.onLinkPress && url)
                                  s.onLinkPress(url);
                              };
                              view.onLinkLongPress = ^(NSString *url) {
                                id<ENRMNestedSegmentHost> s = weakSelf;
                                if (s.onLinkLongPress && url)
                                  s.onLinkLongPress(url);
                              };
                              view.onImagePress = ^(NSString *url, NSString *altText) {
                                id<ENRMNestedSegmentHost> s = weakSelf;
                                if (s.onImagePress && url)
                                  s.onImagePress(url, altText);
                              };
                            }
                            [view applyTableNode:segment.tableSegment.tableNode];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            [(TableContainerView *)view applyTableNode:segment.tableSegment.tableNode];
                          }]];

  [handlers
      addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindCodeBlock
                    matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                      return [view isKindOfClass:[ENRMCodeBlockContainerView class]];
                    }
                    createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                      ENRMCodeBlockContainerView *view = [[ENRMCodeBlockContainerView alloc] initWithConfig:config];
                      id<ENRMNestedSegmentHost> strongSelf = weakSelf;
                      view.dynamicProps = strongSelf.dynamicProps;
                      view.accessibilityLabels = strongSelf.accessibilityLabels;
                      view.onCopyPress = ^(NSString *code, NSString *language) {
                        id<ENRMNestedSegmentHost> s = weakSelf;
                        if (s.onCopyPress)
                          s.onCopyPress(code, language);
                      };
                      view.onCodeBlockPress = ^(NSString *code, NSString *language) {
                        id<ENRMNestedSegmentHost> s = weakSelf;
                        if (s.onCodeBlockPress)
                          s.onCodeBlockPress(code, language);
                      };
                      [view applyCodeBlockNode:segment.codeBlockSegment.codeBlockNode];
                      return view;
                    }
                    updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                      [(ENRMCodeBlockContainerView *)view applyCodeBlockNode:segment.codeBlockSegment.codeBlockNode];
                    }]];

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindList
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMListContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            ENRMListContainerView *view = [[ENRMListContainerView alloc] initWithConfig:config];
                            id<ENRMNestedSegmentHost> parent = weakSelf;
                            if (parent)
                              ENRMConfigureNestedHost(view, parent);
                            [view applyListSegment:segment.listSegment];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            [(ENRMListContainerView *)view applyListSegment:segment.listSegment];
                          }]];

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindBlockquote
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMBlockquoteContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            ENRMBlockquoteContainerView *view =
                                [[ENRMBlockquoteContainerView alloc] initWithConfig:config];
                            view.nested = weakSelf.childrenInsideBlockquote;
                            id<ENRMNestedSegmentHost> strongSelf = weakSelf;
                            if (strongSelf)
                              ENRMConfigureNestedHost(view, strongSelf);
                            view.listContext = segment.blockquoteSegment.listContext;
                            [view applyBlockquoteNode:segment.blockquoteSegment.blockquoteNode
                                      taskIndexOffset:segment.blockquoteSegment.taskIndexOffset];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            ((ENRMBlockquoteContainerView *)view).listContext = segment.blockquoteSegment.listContext;
                            [(ENRMBlockquoteContainerView *)view
                                applyBlockquoteNode:segment.blockquoteSegment.blockquoteNode
                                    taskIndexOffset:segment.blockquoteSegment.taskIndexOffset];
                          }]];

#if ENRICHED_MARKDOWN_MATH
#if !TARGET_OS_OSX
  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindMath
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMMathContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            ENRMMathContainerView *view = [[ENRMMathContainerView alloc] initWithConfig:config];
                            id<ENRMNestedSegmentHost> strongSelf = weakSelf;
                            view.dynamicProps = strongSelf.dynamicProps;
                            view.accessibilityLabels = strongSelf.accessibilityLabels;
                            [view applyLatex:segment.mathSegment.latex];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            [(ENRMMathContainerView *)view applyLatex:segment.mathSegment.latex];
                          }]];
#endif
#endif

  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindBlockSlot
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMBlockSlotSegmentView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            ENRMBlockSlotSegmentView *view = [[ENRMBlockSlotSegmentView alloc] init];
                            view.slotId = segment.blockSlotSegment.slotId;
                            view.kind = segment.blockSlotSegment.kind;
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            ENRMBlockSlotSegmentView *slotView = (ENRMBlockSlotSegmentView *)view;
                            slotView.slotId = segment.blockSlotSegment.slotId;
                            slotView.kind = segment.blockSlotSegment.kind;
                          }]];

#if ENRICHED_MARKDOWN_VIDEO
  __weak id<ENRMNestedSegmentHost> weakBQ = host;
  [handlers addObject:[ENRMSegmentViewHandler handlerWithKind:ENRMSegmentKindVideo
                          matchesView:^BOOL(RCTUIView *view, ENRMRenderedSegment *segment) {
                            return [view isKindOfClass:[ENRMVideoContainerView class]];
                          }
                          createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                            ENRMVideoContainerView *view = [[ENRMVideoContainerView alloc] initWithConfig:config];
                            id<ENRMNestedSegmentHost> bq = weakBQ;
                            if (bq) {
                              view.dynamicProps = bq.dynamicProps;
                            }
                            [view applyVideoNode:segment.videoSegment.videoNode];
                            return view;
                          }
                          updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                            [(ENRMVideoContainerView *)view applyVideoNode:segment.videoSegment.videoNode];
                          }]];
#endif

  NSMutableArray *configuredHandlers = [NSMutableArray arrayWithCapacity:handlers.count];
  for (ENRMSegmentViewHandler *handler in handlers) {
    [configuredHandlers addObject:[ENRMSegmentViewHandler handlerWithKind:handler.kind
                                      matchesView:handler.matchesView
                                      createView:^RCTUIView *(ENRMRenderedSegment *segment) {
                                        id<ENRMNestedSegmentHost> parent = weakSelf;
                                        RCTUIView *configured =
                                            parent.createLeafView ? parent.createLeafView(segment) : nil;
                                        return configured ?: handler.createView(segment);
                                      }
                                      updateView:^(RCTUIView *view, ENRMRenderedSegment *segment) {
                                        id<ENRMNestedSegmentHost> parent = weakSelf;
                                        if (!parent.updateLeafView || !parent.updateLeafView(view, segment))
                                          handler.updateView(view, segment);
                                      }]];
  }
  return [[ENRMSegmentViewRegistry alloc] initWithHandlers:configuredHandlers];
}
