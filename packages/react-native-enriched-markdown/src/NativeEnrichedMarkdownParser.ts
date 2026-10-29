import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface NativeMd4cFlags {
  underline: boolean;
  latexMath: boolean;
  superscript: boolean;
  subscript: boolean;
  highlight: boolean;
  hardSoftBreaks: boolean;
  preserveBlankLines: boolean;
  admonitions: boolean;
}

export interface NativeBlockSlot {
  id: string;
  /** 'image' | 'video' | 'link' | 'code' */
  kind: string;
  /** `""` for code blocks. */
  url: string;
  /** The image's alt text or the link's label, `""` for other kinds. */
  altText: string;
  /** `""` for videos and code blocks. */
  title: string;
  /** 'root' | 'blockquote' | 'admonition' */
  placement: string;
  /** The image occurrence of an image block, `""` for other kinds. */
  occurrenceId: string;
  /** The code block's fence language, `""` when it has none or for other kinds. */
  language: string;
  /** The code block's text without trailing newlines, `""` for other kinds. */
  code: string;
  /** False only for the code block whose closing fence has not streamed in yet. */
  isComplete: boolean;
}

export interface NativeImageOccurrence {
  id: string;
  url: string;
  altText: string;
  title: string;
  /** 'root' | 'blockquote' | 'admonition' | 'inline' | 'list' | 'table' | 'link' */
  placement: string;
}

/** The host's streaming filter settings, applied before collecting when `enabled`. */
export interface NativeStreamingOptions {
  enabled: boolean;
  tableMode: string;
  codeBlockMode: string;
  mediaMode: string;
}

export interface NativeCollectedBlocks {
  slots: ReadonlyArray<NativeBlockSlot>;
  images: ReadonlyArray<NativeImageOccurrence>;
}

/**
 * Synchronous access to the C++ core's block collector, so the slot children
 * for `renderers` land in the same React commit as the markdown they belong to.
 * The filter and parse it runs are shared with the native measurement and
 * render of the same tick.
 */
export interface Spec extends TurboModule {
  collect(
    markdown: string,
    flags: NativeMd4cFlags,
    isGFM: boolean,
    streaming: NativeStreamingOptions
  ): NativeCollectedBlocks;
}

export default TurboModuleRegistry.get<Spec>('EnrichedMarkdownParser');
