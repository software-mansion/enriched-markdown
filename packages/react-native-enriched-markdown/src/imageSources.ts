import { useEffect, useMemo, useRef, useState } from 'react';
import type {
  EnrichedMarkdownTextProps,
  MarkdownImageOccurrence,
  MarkdownImageSource,
} from './types/MarkdownTextProps';

export type ImageSourceResolver = NonNullable<
  EnrichedMarkdownTextProps['resolveImageSource']
>;

/**
 * What the resolver decided for one occurrence: a source, `null` for "keep the
 * Markdown URL", or `undefined` while its promise is still pending.
 */
export type ResolvedImageSource = MarkdownImageSource | null | undefined;

type SourcePromise = Promise<MarkdownImageSource | null | undefined>;

function isPromise(value: unknown): value is Promise<unknown> {
  return (
    value != null && typeof (value as Promise<unknown>).then === 'function'
  );
}

/**
 * Runs `resolveImageSource` once per image occurrence id for the lifetime of
 * the component, shared by the native and web implementations.
 *
 * Results are cached by id, so a streaming append or an edit elsewhere in the
 * document neither re-asks the resolver nor drops an image that already
 * resolved. A promise makes its image pending (`undefined`, the host shows the
 * placeholder) until it settles; a rejection or a thrown error logs in dev and
 * keeps the placeholder. The resolver is read through a ref, like an event
 * handler: changing the function does not re-run it. Remount with a `key` to
 * resolve everything again.
 */
export function useResolvedImageSources(
  occurrences: ReadonlyArray<MarkdownImageOccurrence>,
  resolver: ImageSourceResolver | undefined,
  enabled: boolean
): ReadonlyMap<string, ResolvedImageSource> | undefined {
  const resolverRef = useRef(resolver);
  resolverRef.current = resolver;

  // Every result so far and every promise in flight, by id. Refs rather than
  // state so sync results fold in during render and apply in the same commit
  // as the markdown; the guard below makes the fill idempotent across React's
  // dev double-render.
  const cacheRef = useRef(new Map<string, ResolvedImageSource>());
  const pendingRef = useRef(new Map<string, SourcePromise>());
  const [settledCount, setSettledCount] = useState(0);

  // The promises this occurrence set started, for the effect to subscribe to.
  const newPromises = useMemo(() => {
    const resolve = resolverRef.current;
    if (!enabled || !resolve) return null;
    const cache = cacheRef.current;
    const pending = pendingRef.current;
    const started = new Map<string, SourcePromise>();
    for (const image of occurrences) {
      if (cache.has(image.id) || pending.has(image.id)) continue;
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
        cache.set(image.id, undefined);
        continue;
      }
      if (isPromise(result)) {
        pending.set(image.id, result);
        started.set(image.id, result);
      } else {
        cache.set(image.id, result ?? null);
      }
    }
    return started;
  }, [occurrences, enabled]);

  useEffect(() => {
    if (!newPromises || newPromises.size === 0) return;
    let active = true;
    for (const [id, promise] of newPromises) {
      const settle = (source: ResolvedImageSource) => {
        // The cache outlives this effect: a result landing after the
        // occurrences changed is still the answer for that id.
        if (pendingRef.current.get(id) !== promise) return;
        pendingRef.current.delete(id);
        cacheRef.current.set(id, source);
        if (active) setSettledCount((count) => count + 1);
      };
      promise.then(
        (source) => settle(source ?? null),
        (error) => {
          if (__DEV__) {
            console.error(
              '[EnrichedMarkdownText] resolveImageSource rejected:',
              error
            );
          }
          settle(undefined);
        }
      );
    }
    return () => {
      active = false;
    };
  }, [newPromises]);

  // The current occurrences' entries; a pending id maps to undefined.
  return useMemo(() => {
    if (newPromises === null) return undefined;
    const result = new Map<string, ResolvedImageSource>();
    for (const image of occurrences) {
      result.set(image.id, cacheRef.current.get(image.id));
    }
    return result;
    // settledCount is what re-runs this once an async result lands.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [newPromises, occurrences, settledCount]);
}
