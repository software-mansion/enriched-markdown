import { useMemo } from 'react';
import {
  useResolvedImageSources,
  type ImageSourceResolver,
} from '../imageSources';
import type {
  MarkdownImageOccurrence,
  MarkdownImageSource,
} from '../types/MarkdownTextProps';

/** One entry per image occurrence, as the native component takes it. */
export interface NativeImageSource {
  id: string;
  /** `""` keeps the placeholder and skips the request. */
  uri: string;
  headers: ReadonlyArray<{ name: string; value: string }>;
}

const NO_HEADERS: NativeImageSource['headers'] = [];

function toNativeHeaders(
  headers: Record<string, string> | undefined
): NativeImageSource['headers'] {
  if (!headers) return NO_HEADERS;
  return Object.entries(headers)
    .map(([name, value]) => ({ name, value }))
    .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
}

/**
 * The `imageSources` prop for the collected occurrences: resolved sources as
 * given, pending ones as empty uris, and no entry for images that keep their
 * Markdown URL. See `useResolvedImageSources` for the resolution rules.
 */
export function useImageSources(
  occurrences: ReadonlyArray<MarkdownImageOccurrence>,
  resolver: ImageSourceResolver | undefined,
  enabled: boolean
): ReadonlyArray<NativeImageSource> | undefined {
  const resolved = useResolvedImageSources(occurrences, resolver, enabled);
  return useMemo(() => {
    if (!resolved) return undefined;
    const result: NativeImageSource[] = [];
    for (const [id, source] of resolved) {
      if (source === null) continue;
      if (source === undefined) {
        result.push({ id, uri: '', headers: NO_HEADERS });
        continue;
      }
      const uri = typeof source.uri === 'string' ? source.uri : '';
      result.push({ id, uri, headers: toNativeHeaders(source.headers) });
    }
    return result;
  }, [resolved]);
}

export type { MarkdownImageSource };
