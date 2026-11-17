import NativeEnrichedMarkdownParser from './NativeEnrichedMarkdownParser';
import { setNativeMarkdownStreams } from './markdownStream';

// Streams keep their text in the parser module's C++ buffers. Set here, in the package's entry,
// so a stream created before any view has rendered has it too; the web entry never sets it.
setNativeMarkdownStreams(NativeEnrichedMarkdownParser);

export type { LinkVariantStyle, LinkPillStyle } from './types/MarkdownStyle';
export type { LinkPillContent } from './types/MarkdownTextProps';
export type {
  LinkContextMenuItem,
  LinkRecognition,
} from './types/MarkdownTextProps';
export { default as EnrichedMarkdownText } from './native/EnrichedMarkdownText';
export type {
  EnrichedMarkdownTextProps,
  StreamingConfig,
  StreamingAnimation,
  StreamingFade,
  StreamingGradient,
  MarkdownStyle,
  Md4cFlags,
  ContextMenuItem as TextContextMenuItem,
  SelectionMenuConfig as TextSelectionMenuConfig,
  SelectionMenuPluralLabels as TextSelectionMenuPluralLabels,
  MarkdownBlockPlacement,
  MarkdownSlotBlock,
  MarkdownMediaBlock,
  MarkdownImageBlock,
  MarkdownVideoBlock,
  MarkdownLinkBlock,
  MarkdownCodeBlock,
  MarkdownBlock,
  MarkdownRenderers,
  MarkdownImagePlacement,
  MarkdownImageOccurrence,
  MarkdownImageSource,
  MarkdownLinkOccurrence,
} from './native/EnrichedMarkdownText';
export type {
  LinkPressEvent,
  LinkLongPressEvent,
  ImagePressEvent,
  TextPressEvent,
  TaskListItemPressEvent,
  CopyPressEvent,
  LatexErrorEvent,
  CodeBlockPressEvent,
  SelectionCopyEvent,
} from './types/events';
export type {
  AccessibilityLabels,
  ResolvedAccessibilityLabels,
} from './types/AccessibilityLabels';
export {
  DEFAULT_ACCESSIBILITY_LABELS,
  resolveAccessibilityLabels,
} from './accessibilityLabelDefaults';
export { createMarkdownStream } from './markdownStream';
export type { MarkdownStream } from './markdownStream';

export { EnrichedMarkdownTextInput } from './EnrichedMarkdownTextInput';
export type {
  EnrichedMarkdownTextInputProps,
  EnrichedMarkdownTextInputInstance,
  MarkdownTextInputStyle,
  StyleState,
  HistoryState,
  ContextMenuItem,
  InputSelectionMenuConfig,
  FormatMenuConfig,
  MarkdownShortcutsConfig,
  OnKeyPressEvent,
  OnLinkDetected,
  OnStartMentionEvent,
  OnChangeMentionEvent,
  OnEndMentionEvent,
  CaretRect,
  HeadingLevel,
  HeadingStyle,
} from './EnrichedMarkdownTextInput';
