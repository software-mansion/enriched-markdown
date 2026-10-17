import { useMemo } from 'react';
import type { ReactNode } from 'react';
import { StyleSheet } from 'react-native';
import EnrichedMarkdownBlockSlotNativeComponent from '../EnrichedMarkdownBlockSlotNativeComponent';
import { renderBlock } from '../blockRenderers';
import NativeEnrichedMarkdownParser, {
  type NativeMd4cFlags,
  type NativeStreamingOptions,
} from '../NativeEnrichedMarkdownParser';
import type {
  MarkdownBlock,
  MarkdownBlockPlacement,
  MarkdownImageOccurrence,
  MarkdownImagePlacement,
  MarkdownRenderers,
} from '../types/MarkdownTextProps';

export interface CollectedMarkdown {
  blocks: ReadonlyArray<MarkdownBlock>;
  images: ReadonlyArray<MarkdownImageOccurrence>;
}

const EMPTY: CollectedMarkdown = { blocks: [], images: [] };

let warnedAboutModule = false;
let warnedAboutFlavor = false;

/** Whether any `renderers` entry is set, so `{}` does not cost a parse. */
export function hasRenderers(
  renderers: MarkdownRenderers | undefined
): boolean {
  if (renderers == null) return false;
  for (const key in renderers) {
    if (typeof renderers[key as keyof MarkdownRenderers] === 'function') {
      return true;
    }
  }
  return false;
}

/**
 * The blocks `renderers` may replace and the image occurrences
 * `resolveImageSource` is asked about, in document order, from one parse by
 * the C++ core. While streaming, the core applies the host's streaming filter
 * first, so nothing is collected for a block the host is not rendering yet.
 * Empty when disabled, when the module is unavailable (old architecture, web,
 * Jest) or when the flavor is not GitHub, where the native hosts place no slots.
 */
export function useCollectedMarkdown(
  markdown: string,
  flags: NativeMd4cFlags,
  isGFM: boolean,
  enabled: boolean,
  streaming: NativeStreamingOptions
): CollectedMarkdown {
  return useMemo(() => {
    if (!enabled) return EMPTY;
    if (!isGFM) {
      if (__DEV__ && !warnedAboutFlavor) {
        warnedAboutFlavor = true;
        console.warn(
          '[EnrichedMarkdownText] `renderers` and `resolveImageSource` only apply to flavor="github"; the CommonMark renderer keeps native images and videos.'
        );
      }
      return EMPTY;
    }
    if (NativeEnrichedMarkdownParser == null) {
      if (__DEV__ && !warnedAboutModule) {
        warnedAboutModule = true;
        console.warn(
          '[EnrichedMarkdownText] `renderers` and `resolveImageSource` need the EnrichedMarkdownParser TurboModule, which is only available on the New Architecture.'
        );
      }
      return EMPTY;
    }
    const collected = NativeEnrichedMarkdownParser.collect(
      markdown,
      flags,
      isGFM,
      streaming
    );
    return {
      blocks: collected.slots.map((slot): MarkdownBlock => {
        const placement = slot.placement as MarkdownBlockPlacement;
        switch (slot.kind) {
          case 'video':
            return { kind: 'video', id: slot.id, url: slot.url, placement };
          case 'link':
            return {
              kind: 'link',
              id: slot.id,
              url: slot.url,
              label: slot.altText,
              title: slot.title,
              placement,
            };
          default:
            return {
              kind: 'image',
              id: slot.id,
              url: slot.url,
              altText: slot.altText,
              title: slot.title,
              placement,
            };
        }
      }),
      images: collected.images.map((image) => ({
        id: image.id,
        url: image.url,
        altText: image.altText,
        title: image.title,
        placement: image.placement as MarkdownImagePlacement,
      })),
    };
  }, [markdown, flags, isGFM, enabled, streaming]);
}

/**
 * Runs `renderers` over the collected blocks and wraps every element they return
 * in a slot child keyed by the block id. Memoized on the renderer functions, so
 * keep them stable (`useCallback`) to avoid re-rendering every slot on each
 * parent render.
 */
export function useBlockSlots(
  blocks: ReadonlyArray<MarkdownBlock>,
  renderers: MarkdownRenderers | undefined
): ReactNode[] | null {
  const image = renderers?.image;
  const video = renderers?.video;
  const link = renderers?.link;
  return useMemo(() => {
    if (blocks.length === 0 || (image == null && video == null && link == null))
      return null;
    const slots: ReactNode[] = [];
    for (const block of blocks) {
      const element = renderBlock({ image, video, link }, block);
      if (element == null) continue;
      slots.push(
        <EnrichedMarkdownBlockSlotNativeComponent
          key={block.id}
          slotId={block.id}
          style={styles.slot}
        >
          {element}
        </EnrichedMarkdownBlockSlotNativeComponent>
      );
    }
    return slots.length > 0 ? slots : null;
  }, [blocks, image, video, link]);
}

const styles = StyleSheet.create({
  // The host's shadow node sizes and places each slot at the content width; the
  // slot itself only has to let its content report an intrinsic height.
  slot: { position: 'absolute', left: 0, top: 0 },
});
