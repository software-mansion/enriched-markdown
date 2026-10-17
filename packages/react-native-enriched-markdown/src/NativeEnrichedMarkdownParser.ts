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
  /** 'image' | 'video' */
  kind: string;
  url: string;
  /** `""` for videos. */
  altText: string;
  /** `""` for videos. */
  title: string;
  /** 'root' | 'blockquote' | 'admonition' */
  placement: string;
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
 * for `renderers` and the sources for `resolveImageSource` land in the same
 * React commit as the markdown they belong to. One parse serves both.
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
