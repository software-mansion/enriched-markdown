import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import type { EnrichedMarkdownTextProps } from './types/MarkdownTextProps';
import type {
  MarkdownImageOccurrence,
  MarkdownImageSource,
} from './types/markdownBlocks';

export type ImageSourceResolver = NonNullable<
  EnrichedMarkdownTextProps['resolveImageSource']
>;

/** What the resolver decided for one occurrence, so far. */
export type ResolvedImageSource =
  | { state: 'pending' } // not answered yet, or failed: keep the placeholder
  | { state: 'markdown' } // load the Markdown URL
  | { state: 'resolved'; source: MarkdownImageSource };

const PENDING: ResolvedImageSource = { state: 'pending' };
const MARKDOWN: ResolvedImageSource = { state: 'markdown' };

// Untyped callers may answer with null; it means the same as undefined.
function resolution(
  source: MarkdownImageSource | null | undefined
): ResolvedImageSource {
  return source == null ? MARKDOWN : { state: 'resolved', source };
}

type SourcePromise = Promise<MarkdownImageSource | undefined>;

function isPromise(value: unknown): value is Promise<unknown> {
  return (
    value != null && typeof (value as Promise<unknown>).then === 'function'
  );
}

// The id hashes these, so an answer kept for the id is still for this image.
function sameImage(
  a: MarkdownImageOccurrence,
  b: MarkdownImageOccurrence
): boolean {
  return a.url === b.url && a.altText === b.altText && a.title === b.title;
}

function sameOccurrence(
  a: MarkdownImageOccurrence,
  b: MarkdownImageOccurrence
): boolean {
  return sameImage(a, b) && a.placement === b.placement;
}

interface CacheEntry {
  image: MarkdownImageOccurrence;
  source: ResolvedImageSource;
}

interface PendingEntry {
  image: MarkdownImageOccurrence;
  promise: SourcePromise;
}

/**
 * Runs `resolveImageSource` once per image while it stays in the document,
 * shared by the native and web implementations.
 *
 * The resolver runs after rendering (a layout effect), never during it, so a
 * render React throws away starts no request and a resolver may update other
 * state. Until it answers, the image is pending (the host shows the
 * placeholder and does not request the Markdown URL); a synchronous answer
 * lands before the frame is drawn.
 *
 * Answers are kept by occurrence id while the occurrence is unchanged, so a
 * streaming append or an edit elsewhere neither asks again nor drops an image
 * that already resolved; images that leave the document are forgotten. An
 * image that only moves to another placement (a paragraph streams on past it)
 * is asked again but keeps its answer until the new one lands. A
 * promise keeps its image pending until it settles; a rejection or a thrown
 * error logs in dev and keeps the placeholder. The resolver is read like an
 * event handler: changing the function does not run it again. Remount with a
 * `key` to resolve everything again.
 */
export function useResolvedImageSources(
  occurrences: ReadonlyArray<MarkdownImageOccurrence>,
  resolver: ImageSourceResolver | undefined,
  enabled: boolean
): ReadonlyMap<string, ResolvedImageSource> | undefined {
  const resolverRef = useRef(resolver);
  useLayoutEffect(() => {
    resolverRef.current = resolver;
  });

  const cacheRef = useRef(new Map<string, CacheEntry>());
  const pendingRef = useRef(new Map<string, PendingEntry>());
  const [version, setVersion] = useState(0);

  const mountedRef = useRef(true);
  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  const active = enabled && resolver != null;

  useLayoutEffect(() => {
    const resolve = resolverRef.current;
    if (!active || !resolve) return;
    const cache = cacheRef.current;
    const pending = pendingRef.current;
    const live = new Set<string>();
    let changed = false;

    const settle = (
      id: string,
      entry: PendingEntry,
      source: ResolvedImageSource
    ) => {
      // A newer request for the id, or the image left: this answer is stale.
      if (pendingRef.current.get(id) !== entry) return;
      pendingRef.current.delete(id);
      cacheRef.current.set(id, { image: entry.image, source });
      if (mountedRef.current) setVersion((value) => value + 1);
    };

    for (const image of occurrences) {
      live.add(image.id);
      const cached = cache.get(image.id);
      if (cached && sameOccurrence(cached.image, image)) continue;
      const inFlight = pending.get(image.id);
      if (inFlight && sameOccurrence(inFlight.image, image)) continue;
      if (cached && !sameImage(cached.image, image)) cache.delete(image.id);
      pending.delete(image.id);
      let result: ReturnType<ImageSourceResolver>;
      try {
        result = resolve(image);
      } catch (error) {
        if (__DEV__) {
          console.error(
            '[EnrichedMarkdownText] resolveImageSource threw:',
            error
          );
        }
        cache.set(image.id, { image, source: PENDING });
        changed = true;
        continue;
      }
      if (isPromise(result)) {
        const entry: PendingEntry = { image, promise: result };
        pending.set(image.id, entry);
        result.then(
          (source) => settle(image.id, entry, resolution(source)),
          (error) => {
            if (__DEV__) {
              console.error(
                '[EnrichedMarkdownText] resolveImageSource rejected:',
                error
              );
            }
            settle(image.id, entry, PENDING);
          }
        );
      } else {
        cache.set(image.id, { image, source: resolution(result) });
        changed = true;
      }
    }
    for (const id of cache.keys()) {
      if (!live.has(id)) cache.delete(id);
    }
    for (const id of pending.keys()) {
      if (!live.has(id)) pending.delete(id);
    }
    if (changed) setVersion((value) => value + 1);
  }, [occurrences, active]);

  // The current occurrences' answers; one not answered yet is pending.
  // The previous map is returned while every answer is the same, so a streaming
  // tick that adds no image changes no prop.
  const previousRef =
    useRef<ReadonlyMap<string, ResolvedImageSource>>(undefined);
  const resolved = useMemo(() => {
    if (!active) return undefined;
    const result = new Map<string, ResolvedImageSource>();
    for (const image of occurrences) {
      const cached = cacheRef.current.get(image.id);
      const current = cached && sameImage(cached.image, image);
      result.set(image.id, current ? cached.source : PENDING);
    }
    const previous = previousRef.current;
    return previous && sameEntries(previous, result) ? previous : result;
    // version is what re-runs this once an answer lands.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active, occurrences, version]);
  useLayoutEffect(() => {
    previousRef.current = resolved;
  });
  return resolved;
}

function sameEntries(
  a: ReadonlyMap<string, ResolvedImageSource>,
  b: ReadonlyMap<string, ResolvedImageSource>
): boolean {
  if (a.size !== b.size) return false;
  for (const [id, source] of b) {
    if (!a.has(id) || a.get(id) !== source) return false;
  }
  return true;
}
