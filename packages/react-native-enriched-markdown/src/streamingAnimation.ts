import { processColor } from 'react-native';
import type { ProcessedColorValue } from 'react-native';
import type { StreamingAnimation } from './types/MarkdownTextProps';

/** `streamingConfig.animation` as the native views take it. */
export interface NormalizedStreamingAnimation {
  animation: string;
  animationDuration: number;
  animationLength: number;
  animationStartColor: ProcessedColorValue | null | undefined;
  animationEndColor: ProcessedColorValue | null | undefined;
}

const PRESETS = new Set(['fade', 'gradient', 'none']);
const warned = new Set<string>();

export function normalizeStreamingAnimation(
  animation: StreamingAnimation | undefined
): NormalizedStreamingAnimation {
  const options = typeof animation === 'object' ? animation : undefined;
  let type: string =
    options?.type ?? (typeof animation === 'string' ? animation : 'fade');
  // An effect this version does not know shows new content at once.
  if (!PRESETS.has(type)) {
    if (__DEV__ && !warned.has(type)) {
      warned.add(type);
      console.warn(
        `[react-native-enriched-markdown] Unknown streamingConfig.animation '${type}'; showing new content without one.`
      );
    }
    type = 'none';
  }
  const duration = options?.type === 'fade' ? (options.duration ?? 200) : 200;
  const length = options?.type === 'gradient' ? (options.length ?? 20) : 20;
  // A fade over no time, or a gradient over no characters, is no animation.
  if (duration <= 0 || length <= 0) {
    type = 'none';
  }
  return {
    animation: type,
    animationDuration: duration,
    animationLength: length,
    // Colors nested in a prop are not processed for native on their own.
    animationStartColor:
      options?.type === 'gradient' && options.startColor != null
        ? processColor(options.startColor)
        : undefined,
    animationEndColor:
      options?.type === 'gradient' && options.endColor != null
        ? processColor(options.endColor)
        : undefined,
  };
}
