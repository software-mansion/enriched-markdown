export { default as EnrichedMarkdownText } from './native/EnrichedMarkdownText';
export type {
  EnrichedMarkdownTextProps,
  StreamingConfig,
  MarkdownStyle,
  Md4cFlags,
  ContextMenuItem as TextContextMenuItem,
  SelectionMenuConfig as TextSelectionMenuConfig,
  SelectionMenuPluralLabels as TextSelectionMenuPluralLabels,
} from './native/EnrichedMarkdownText';
export type {
  LinkPressEvent,
  LinkLongPressEvent,
  TaskListItemPressEvent,
  CopyPressEvent,
} from './types/events';
export type {
  AccessibilityLabels,
  ResolvedAccessibilityLabels,
} from './types/AccessibilityLabels';
export {
  DEFAULT_ACCESSIBILITY_LABELS,
  resolveAccessibilityLabels,
} from './accessibilityLabelDefaults';

export { EnrichedMarkdownTextInput } from './EnrichedMarkdownTextInput';
export type {
  EnrichedMarkdownTextInputProps,
  EnrichedMarkdownTextInputInstance,
  MarkdownTextInputStyle,
  StyleState,
  ContextMenuItem,
  InputSelectionMenuConfig,
  FormatMenuConfig,
  OnKeyPressEvent,
  OnLinkDetected,
  OnStartMentionEvent,
  OnChangeMentionEvent,
  OnEndMentionEvent,
  CaretRect,
  HeadingLevel,
  HeadingStyle,
} from './EnrichedMarkdownTextInput';
