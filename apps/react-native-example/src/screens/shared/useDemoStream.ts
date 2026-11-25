import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type {
  LayoutChangeEvent,
  NativeScrollEvent,
  NativeSyntheticEvent,
} from 'react-native';
import Animated, {
  scrollTo,
  useAnimatedRef,
  useFrameCallback,
  useScrollOffset,
  useSharedValue,
} from 'react-native-reanimated';

const TICK_MS = 34;
const CHARS_PER_TICK = 3;
// Code types faster than prose, the way a model emits it.
const CODE_CHARS_PER_TICK = 6;
const BLOCK_PAUSE_MS = 700;
const CODE_LINE_MS = 160;
// A typed code block's opening fence, so its cell settles in before the code.
const FENCE_PAUSE_MS = 450;
const PAUSE_MS = {
  tick: TICK_MS,
  line: CODE_LINE_MS,
  fence: FENCE_PAUSE_MS,
  block: BLOCK_PAUSE_MS,
};
const START_DELAY_MS = 900;
// Stiffness of the auto-scroll's critically damped spring towards the bottom,
// in rad/s: it starts from rest and settles in about 0.4 s, without overshoot,
// so a block landing glides the page up instead of jolting it.
const FOLLOW_OMEGA = 11;
// How close to the bottom a drag has to end to pick the follow up again.
const REJOIN_PX = 24;

// Stands in for #830 until the library closes open emphasis while streaming:
// the paragraph being written gets its `**`/`*` closed, so bold and italic
// grow in place instead of showing raw markers. A marker cut off at the tail,
// or a space before the closer (not right-flanking), waits for the next tick.
// Inside a code block a `*` is code, so it is left alone.
export function closeOpenEmphasis(text: string) {
  if ((text.match(FENCE)?.length ?? 0) % 2 === 1) return text;
  const body = text.replace(/\*+$/, '');
  const paragraph = body.slice(body.lastIndexOf('\n\n') + 1);
  const open: string[] = [];
  for (const [run] of paragraph.matchAll(/\*+/g)) {
    if (open[open.length - 1] === run) open.pop();
    else open.push(run);
  }
  return open.length === 0 ? body : body.trimEnd() + open.reverse().join('');
}

// Display math too: a formula renders once whole, so it never shows as LaTeX.
const BLOCK_LINE = /^\n*(!\[|\[|<video|\$\$)/;
const FENCE = /^```/gm;

function lineEnd(source: string, start: number) {
  const end = source.indexOf('\n', start);
  return end === -1 ? source.length : end + 1;
}

/**
 * How a code block streams in. Its fence lines always arrive whole, so a
 * fence's language never streams in letter by letter. `lines`: the code a
 * line at a time; `typed`: the code a few characters a tick, like prose;
 * `whole`: the block in one tick, opening fence to closing.
 */
export type FenceStreaming = 'lines' | 'typed' | 'whole';

/**
 * How prose streams in. `chars`: a few characters a tick; `words`: a word a
 * tick, at the same pace, so a word is laid out where it ends up from its
 * first frame, rather than starting at a line's end and jumping to the next.
 */
export type ProseStreaming = 'chars' | 'words';

// Lines that become a renderer arrive in one tick, like a model finishing a
// URL, and the stream breathes afterwards so the block can make its entrance.
export function nextCursor(
  source: string,
  cursor: number,
  fences: FenceStreaming = 'lines',
  prose: ProseStreaming = 'chars'
): { cursor: number; pause: keyof typeof PAUSE_MS | null; ms?: number } {
  let start = cursor;
  while (source[start] === '\n') start++;
  const atLineStart = start === 0 || source[start - 1] === '\n';
  if (atLineStart && BLOCK_LINE.test(source.slice(start))) {
    return { cursor: lineEnd(source, start), pause: 'block' as const };
  }
  const inFence = (source.slice(0, start).match(FENCE)?.length ?? 0) % 2 === 1;
  const fenceLine = atLineStart && source.startsWith('```', start);
  if (fences === 'typed' && inFence && !fenceLine) {
    // Up to the closing fence, which then arrives whole.
    const closing = source.indexOf('\n```', cursor);
    const limit = closing === -1 ? source.length : closing + 1;
    return {
      cursor: Math.min(cursor + CODE_CHARS_PER_TICK, limit),
      pause: null,
    };
  }
  if (fences === 'whole' && fenceLine && !inFence) {
    const closing = source.indexOf('\n```', lineEnd(source, start) - 1);
    return {
      cursor: closing === -1 ? source.length : lineEnd(source, closing + 1),
      pause: 'block' as const,
    };
  }
  if (atLineStart && (inFence || fenceLine)) {
    // The closing fence completes the block, which then gets its breath.
    const closing = inFence && fenceLine;
    const opening = fences === 'typed' && fenceLine && !inFence;
    return {
      cursor: lineEnd(source, start),
      pause: closing
        ? ('block' as const)
        : opening
          ? ('fence' as const)
          : ('line' as const),
    };
  }
  // Text stops at the start of a renderer line rather than stepping into it,
  // so the next tick takes the whole line.
  const word = source.slice(cursor).match(/^\s*\S+ ?/)?.[0].length;
  let end = Math.min(
    cursor + (prose === 'words' && word ? word : CHARS_PER_TICK),
    source.length
  );
  for (let i = source.indexOf('\n', cursor); i !== -1 && i < end; ) {
    if (
      BLOCK_LINE.test(source.slice(i + 1)) ||
      source.startsWith('```', i + 1)
    ) {
      end = i + 1;
      break;
    }
    i = source.indexOf('\n', i + 1);
  }
  return {
    cursor: end,
    pause: null,
    ms:
      prose === 'words'
        ? (TICK_MS * Math.max(end - cursor, 1)) / CHARS_PER_TICK
        : undefined,
  };
}

type ScrollEvent = NativeSyntheticEvent<NativeScrollEvent>;

// Keeps a scroll view following the bottom as its content grows, until the
// reader drags away; scrolling back to the bottom picks the follow up again.
// `enabled: false` leaves the scroll view to the reader alone.
export function useFollow(enabled = true, omega = FOLLOW_OMEGA) {
  const scrollRef = useAnimatedRef<Animated.ScrollView>();
  const following = useSharedValue(enabled);
  const viewport = useSharedValue(0);
  const target = useSharedValue(0);
  const offset = useSharedValue(0);
  const velocity = useSharedValue(0);
  const scrolled = useScrollOffset(scrollRef);
  const [detached, setDetached] = useState(false);

  // Springs towards the bottom on the UI thread, so the follow stays smooth
  // however often the stream ticks or a block grows the content.
  useFrameCallback(({ timeSincePreviousFrame }) => {
    if (!following.value) return;
    const gap = target.value - offset.value;
    if (Math.abs(gap) < 0.5 && Math.abs(velocity.value) < 5) {
      velocity.value = 0;
      return;
    }
    const dt = Math.min(timeSincePreviousFrame ?? 16, 50) / 1000;
    velocity.value += (omega * omega * gap - 2 * omega * velocity.value) * dt;
    offset.value += velocity.value * dt;
    scrollTo(scrollRef, 0, offset.value, false);
  });

  const follow = useCallback(() => {
    offset.value = scrolled.value;
    velocity.value = 0;
    following.value = true;
    setDetached(false);
  }, [offset, velocity, scrolled, following]);

  // The follow's own scrollTo ends a momentum scroll on iOS too, so only a
  // detached view rejoins.
  const rejoinAtBottom = useCallback(
    (event: ScrollEvent) => {
      const y = event.nativeEvent.contentOffset.y;
      if (enabled && !following.value && y >= target.value - REJOIN_PX) {
        follow();
      }
    },
    [enabled, following, target, follow]
  );

  // Leaves the follow for a place in the answer, as a drag would.
  const jump = useCallback(
    (y: number) => {
      following.value = false;
      setDetached(true);
      scrollRef.current?.scrollTo({ y, animated: true });
    },
    [following, scrollRef]
  );

  const reset = useCallback(() => {
    following.value = enabled;
    target.value = 0;
    offset.value = 0;
    velocity.value = 0;
    scrollRef.current?.scrollTo({ y: 0, animated: false });
    setDetached(false);
  }, [enabled, following, target, offset, velocity, scrollRef]);

  // Stable across ticks, so the scroll view does not re-render as text grows.
  const scrollProps = useMemo(
    () => ({
      ref: scrollRef,
      onLayout: (event: LayoutChangeEvent) => {
        viewport.value = event.nativeEvent.layout.height;
      },
      onScrollBeginDrag: () => {
        following.value = false;
        setDetached(true);
      },
      onScrollEndDrag: rejoinAtBottom,
      onMomentumScrollEnd: rejoinAtBottom,
      onContentSizeChange: (_: number, height: number) => {
        target.value = Math.max(0, height - viewport.value);
      },
    }),
    [scrollRef, viewport, following, rejoinAtBottom, target]
  );

  return { detached, follow, jump, reset, scrollProps };
}

// Streams `source` like a model answer, `startDelay` ms after the prompt, and
// keeps the scroll view following the bottom until the reader drags away.
// `holdFence`, when given, is asked before each line of a code block (its
// opening fence included) with the line and the block's language, and returns
// how many ms to hold the line back, so a block can land on a downbeat.
export function useDemoStream(
  source: string,
  startDelay = START_DELAY_MS,
  following = true,
  fences: FenceStreaming = 'lines',
  followOmega?: number,
  prose: ProseStreaming = 'chars',
  holdFence?: (line: string, language: string) => number
) {
  const { detached, follow, jump, reset, scrollProps } = useFollow(
    following,
    followOmega
  );
  const [run, setRun] = useState(0);
  const [cursor, setCursor] = useState(0);
  const hold = useRef(holdFence);
  hold.current = holdFence;

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout>;
    let position = 0;
    let held = false;
    const tick = () => {
      let start = position;
      while (source[start] === '\n') start++;
      if (
        hold.current &&
        !held &&
        (start === 0 || source[start - 1] === '\n')
      ) {
        const before = source.slice(0, start);
        const inFence = (before.match(FENCE)?.length ?? 0) % 2 === 1;
        const line = source.slice(start, lineEnd(source, start)).trimEnd();
        const opening = !inFence && line.startsWith('```');
        if (opening || (inFence && !line.startsWith('```'))) {
          const fence = opening
            ? line
            : before.slice(before.lastIndexOf('```'));
          const language = fence.slice(3).split('\n')[0]!.trim();
          const ms = hold.current(line, language);
          if (ms > 0) {
            held = true;
            timer = setTimeout(tick, ms);
            return;
          }
        }
      }
      held = false;
      const next = nextCursor(source, position, fences, prose);
      position = next.cursor;
      setCursor(position);
      if (position < source.length) {
        timer = setTimeout(tick, next.ms ?? PAUSE_MS[next.pause ?? 'tick']);
      }
    };
    timer = setTimeout(tick, startDelay);
    return () => clearTimeout(timer);
  }, [source, run, startDelay, fences, prose]);

  const replay = useCallback(() => {
    reset();
    setCursor(0);
    setRun((value) => value + 1);
  }, [reset]);

  const streaming = cursor < source.length;

  return {
    run,
    streaming,
    writing: streaming && cursor > 0,
    markdown: streaming ? closeOpenEmphasis(source.slice(0, cursor)) : source,
    detached,
    follow,
    jump,
    replay,
    scrollProps,
  };
}
