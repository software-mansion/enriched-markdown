#import "ENRMInputEventEmitter.h"

using namespace facebook::react;

#define ENRM_GUARD_EMITTER(name)                                                                                       \
  auto name = [self emitter];                                                                                          \
  if (name == nullptr) {                                                                                               \
    return;                                                                                                            \
  }

@implementation ENRMInputEventEmitter {
  __weak id<ENRMInputEventEmitterDataSource> _dataSource;

  struct {
    BOOL bold, italic, underline, strikethrough, spoiler, link, initialized;
    NSInteger headingLevel;
    BOOL unorderedList;
    NSInteger unorderedListDepth;
    BOOL orderedList;
    NSInteger orderedListDepth;
  } _prevState;

  std::optional<CGRect> _prevCaretRect;
}

- (instancetype)initWithDataSource:(id<ENRMInputEventEmitterDataSource>)dataSource
{
  self = [super init];
  if (self) {
    _dataSource = dataSource;
  }
  return self;
}

#pragma mark - Private

- (std::shared_ptr<EnrichedMarkdownTextInputEventEmitter const>)emitter
{
  return [_dataSource fabricEventEmitter];
}

#pragma mark - Simple emitters

- (void)emitOnChangeText
{
  ENRM_GUARD_EMITTER(emitter);
  NSString *plainText = [_dataSource plainText];
  emitter->onChangeText({.value = std::string([plainText UTF8String] ?: "")});
}

/// Maps the replacement text of a pending edit to RN TextInput's
/// `onKeyPress` key names: empty text means deletion ("Backspace"), and
/// leading \n, \t and ESC map to "Enter", "Tab" and "Escape".
- (void)emitOnKeyPress:(NSString *)text
{
  ENRM_GUARD_EMITTER(emitter);
  NSString *key;
  if (text.length == 0) {
    key = @"Backspace";
  } else {
    switch ([text characterAtIndex:0]) {
      case '\n':
        key = @"Enter";
        break;
      case '\t':
        key = @"Tab";
        break;
      case 0x1B:
        key = @"Escape";
        break;
      default:
        key = text;
        break;
    }
  }
  emitter->onInputKeyPress({.key = std::string([key UTF8String] ?: "")});
}

- (void)emitOnChangeMarkdown
{
  ENRM_GUARD_EMITTER(emitter);
  NSString *markdown = [_dataSource currentMarkdown];
  emitter->onChangeMarkdown({.value = std::string([markdown UTF8String] ?: "")});
}

- (void)emitOnChangeSelection
{
  ENRM_GUARD_EMITTER(emitter);
  NSRange selection = [_dataSource selectedRange];
  emitter->onChangeSelection({
      .start = static_cast<int>(selection.location),
      .end = static_cast<int>(NSMaxRange(selection)),
  });
}

- (void)emitOnFocus
{
  ENRM_GUARD_EMITTER(emitter);
  emitter->onInputFocus({});
}

- (void)emitOnBlur
{
  ENRM_GUARD_EMITTER(emitter);
  emitter->onInputBlur({});
}

- (void)emitOnLinkDetectedWithText:(NSString *)text url:(NSString *)url range:(NSRange)range
{
  ENRM_GUARD_EMITTER(emitter);
  emitter->onLinkDetected({
      .text = std::string([text UTF8String] ?: ""),
      .url = std::string([url UTF8String] ?: ""),
      .start = static_cast<int>(range.location),
      .end = static_cast<int>(range.location + range.length),
  });
}

- (void)emitOnStartMention:(NSString *)indicator
{
  ENRM_GUARD_EMITTER(emitter);
  emitter->onStartMention({.indicator = std::string([indicator UTF8String] ?: "")});
}

- (void)emitOnChangeMentionWithIndicator:(NSString *)indicator text:(NSString *)text
{
  ENRM_GUARD_EMITTER(emitter);
  emitter->onChangeMention({
      .indicator = std::string([indicator UTF8String] ?: ""),
      .text = std::string([text UTF8String] ?: ""),
  });
}

- (void)emitOnEndMention:(NSString *)indicator
{
  ENRM_GUARD_EMITTER(emitter);
  emitter->onEndMention({.indicator = std::string([indicator UTF8String] ?: "")});
}

#pragma mark - Stateful emitters

- (void)emitOnChangeState
{
  ENRM_GUARD_EMITTER(emitter);

  NSUInteger cursor = [_dataSource selectedRange].location;
  BOOL boldActive = [_dataSource isEffectiveStyleActive:ENRMInputStyleTypeStrong atPosition:cursor];
  BOOL italicActive = [_dataSource isEffectiveStyleActive:ENRMInputStyleTypeEmphasis atPosition:cursor];
  BOOL underlineActive = [_dataSource isEffectiveStyleActive:ENRMInputStyleTypeUnderline atPosition:cursor];
  BOOL strikethroughActive = [_dataSource isEffectiveStyleActive:ENRMInputStyleTypeStrikethrough atPosition:cursor];
  BOOL spoilerActive = [_dataSource isEffectiveStyleActive:ENRMInputStyleTypeSpoiler atPosition:cursor];
  BOOL linkActive = [_dataSource isEffectiveStyleActive:ENRMInputStyleTypeLink atPosition:cursor];

  NSInteger headingLevel = [_dataSource headingLevelForCursorParagraph];

  NSInteger listDepth = 0;
  ENRMBlockRange *emitListBlock = [_dataSource listBlockForCursorParagraph];
  BOOL unorderedListActive = emitListBlock != nil && emitListBlock.type == ENRMInputBlockTypeUnorderedListItem;
  BOOL orderedListActive = emitListBlock != nil && emitListBlock.type == ENRMInputBlockTypeOrderedListItem;
  if (emitListBlock != nil) {
    listDepth = emitListBlock.level;
  }

  if (_prevState.initialized && _prevState.bold == boldActive && _prevState.italic == italicActive &&
      _prevState.underline == underlineActive && _prevState.strikethrough == strikethroughActive &&
      _prevState.spoiler == spoilerActive && _prevState.link == linkActive && _prevState.headingLevel == headingLevel &&
      _prevState.unorderedList == unorderedListActive && _prevState.unorderedListDepth == listDepth &&
      _prevState.orderedList == orderedListActive && _prevState.orderedListDepth == listDepth) {
    return;
  }

  _prevState.bold = boldActive;
  _prevState.italic = italicActive;
  _prevState.underline = underlineActive;
  _prevState.strikethrough = strikethroughActive;
  _prevState.spoiler = spoilerActive;
  _prevState.link = linkActive;
  _prevState.headingLevel = headingLevel;
  _prevState.unorderedList = unorderedListActive;
  _prevState.unorderedListDepth = listDepth;
  _prevState.orderedList = orderedListActive;
  _prevState.orderedListDepth = listDepth;
  _prevState.initialized = YES;

  emitter->onChangeState({
      .bold = {.isActive = boldActive},
      .italic = {.isActive = italicActive},
      .underline = {.isActive = underlineActive},
      .strikethrough = {.isActive = strikethroughActive},
      .spoiler = {.isActive = spoilerActive},
      .link = {.isActive = linkActive},
      .heading = {.isActive = headingLevel > 0, .level = static_cast<int>(headingLevel)},
      .unorderedList = {.isActive = unorderedListActive,
                        .depth = static_cast<int>(unorderedListActive ? listDepth : 0)},
      .orderedList = {.isActive = orderedListActive, .depth = static_cast<int>(orderedListActive ? listDepth : 0)},
  });
}

- (void)emitCaretRectChangeIfNeeded
{
  ENRM_GUARD_EMITTER(emitter);

  CGRect caretRect = [_dataSource computeCaretRect];

  if (_prevCaretRect.has_value() && CGRectEqualToRect(_prevCaretRect.value(), caretRect)) {
    return;
  }

  _prevCaretRect = caretRect;

  emitter->onCaretRectChange({
      .x = caretRect.origin.x,
      .y = caretRect.origin.y,
      .width = caretRect.size.width,
      .height = caretRect.size.height,
  });
}

- (void)invalidateCachedState
{
  _prevState.initialized = NO;
  _prevCaretRect.reset();
}

- (void)emitContextMenuItemPress:(NSString *)itemText
{
  ENRM_GUARD_EMITTER(eventEmitter);

  NSRange selectedRange = [_dataSource selectedRange];
  NSString *selectedText = selectedRange.length > 0 ? [[_dataSource plainText] substringWithRange:selectedRange] : @"";

  auto isActive = [&](ENRMInputStyleType type) -> BOOL {
    if (selectedRange.length > 0) {
      return [_dataSource isStyleActive:type inRange:selectedRange];
    }
    return [_dataSource isEffectiveStyleActive:type atPosition:selectedRange.location];
  };

  BOOL boldActive = isActive(ENRMInputStyleTypeStrong);
  BOOL italicActive = isActive(ENRMInputStyleTypeEmphasis);
  BOOL underlineActive = isActive(ENRMInputStyleTypeUnderline);
  BOOL strikethroughActive = isActive(ENRMInputStyleTypeStrikethrough);
  BOOL spoilerActive = isActive(ENRMInputStyleTypeSpoiler);
  BOOL linkActive = isActive(ENRMInputStyleTypeLink);
  NSInteger headingLevel = [_dataSource headingLevelForCursorParagraph];
  NSInteger listDepth = 0;
  ENRMBlockRange *emitListBlock = [_dataSource listBlockForCursorParagraph];
  BOOL unorderedListActive = emitListBlock != nil && emitListBlock.type == ENRMInputBlockTypeUnorderedListItem;
  BOOL orderedListActive = emitListBlock != nil && emitListBlock.type == ENRMInputBlockTypeOrderedListItem;
  if (emitListBlock != nil) {
    listDepth = emitListBlock.level;
  }

  eventEmitter->onContextMenuItemPress({
      .itemText = std::string(itemText.UTF8String),
      .selectedText = std::string(selectedText.UTF8String),
      .selectionStart = static_cast<int>(selectedRange.location),
      .selectionEnd = static_cast<int>(NSMaxRange(selectedRange)),
      .styleState =
          {
              .bold = {.isActive = boldActive},
              .italic = {.isActive = italicActive},
              .underline = {.isActive = underlineActive},
              .strikethrough = {.isActive = strikethroughActive},
              .spoiler = {.isActive = spoilerActive},
              .link = {.isActive = linkActive},
              .heading = {.isActive = headingLevel > 0, .level = static_cast<int>(headingLevel)},
              .unorderedList = {.isActive = unorderedListActive,
                                .depth = static_cast<int>(unorderedListActive ? listDepth : 0)},
              .orderedList = {.isActive = orderedListActive,
                              .depth = static_cast<int>(orderedListActive ? listDepth : 0)},
          },
  });
}

#pragma mark - Compound helpers

- (void)emitFormattingChanged
{
  [self emitOnChangeState];
  if (_emitMarkdown) {
    [self emitOnChangeMarkdown];
  }
}

#pragma mark - Request-response

- (void)requestMarkdown:(NSInteger)requestId
{
  ENRM_GUARD_EMITTER(emitter);
  NSString *markdown = [_dataSource currentMarkdown];
  emitter->onRequestMarkdownResult({
      .requestId = static_cast<int>(requestId),
      .markdown = std::string([markdown UTF8String] ?: ""),
  });
}

- (void)requestCaretRect:(NSInteger)requestId
{
  ENRM_GUARD_EMITTER(emitter);

  CGRect caretRect = [_dataSource computeCaretRect];
  emitter->onRequestCaretRectResult({
      .requestId = static_cast<int>(requestId),
      .x = caretRect.origin.x,
      .y = caretRect.origin.y,
      .width = caretRect.size.width,
      .height = caretRect.size.height,
  });
}

@end
