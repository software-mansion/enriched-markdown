import { useEffect, useRef, type ReactNode } from 'react';
import {
  Pressable,
  StyleSheet,
  Text,
  View,
  type ViewStyle,
} from 'react-native';
import Animated, {
  FadeIn,
  useFrameCallback,
  useSharedValue,
} from 'react-native-reanimated';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import {
  BRASS,
  CREAM,
  FONTS,
  GEAR_BACKGROUND,
  GEAR_SHADOW,
  MIDNIGHT,
  RULE,
  glow,
} from '../theme';

/** A fence's `// caption` lines, and the rest. */
export function splitCode(code: string) {
  const caption: string[] = [];
  const body: string[] = [];
  for (const line of code.split('\n')) {
    const comment = /^\s*\/\/\s?(.*)$/.exec(line);
    if (comment) caption.push(comment[1]!);
    else if (line.trim()) body.push(line);
  }
  return { caption: caption.join(' '), body };
}

/**
 * Calls `onArrive` once for each new item while the block streams in, so the
 * cell can sound what the answer just wrote. A cell that mounts whole (the
 * reader scrolled back, or the answer was already there) stays quiet.
 */
export function useArrivals(
  block: MarkdownCodeBlock,
  count: number,
  onArrive: (index: number) => void
) {
  const live = useRef(!block.isComplete);
  const seen = useRef(block.isComplete ? count : 0);
  const callback = useRef(onArrive);
  callback.current = onArrive;
  useEffect(() => {
    if (!live.current) return;
    for (let i = seen.current; i < count; i++) callback.current(i);
    seen.current = Math.max(seen.current, count);
  }, [count]);
  return live.current;
}

/** Runs `effect` once when a block that streamed in closes its fence. */
export function useOnClose(block: MarkdownCodeBlock, effect: () => void) {
  const live = useRef(!block.isComplete);
  const done = useRef(false);
  const callback = useRef(effect);
  callback.current = effect;
  useEffect(() => {
    if (!block.isComplete || done.current || !live.current) return;
    done.current = true;
    callback.current();
  }, [block.isComplete]);
}

/** `Date.now()` on every frame, for playheads drawn on the UI thread. */
export function useNow() {
  const now = useSharedValue(Date.now());
  useFrameCallback(() => {
    now.value = Date.now();
  });
  return now;
}

/**
 * A piece of gear on the stage: a lit panel with a pilot light, the cell's
 * name stencilled beside it and the answer's caption under that.
 */
export function Card({
  tag,
  caption,
  children,
  action,
  style,
  accent = BRASS,
}: {
  tag: string;
  caption?: string;
  children: ReactNode;
  action?: ReactNode;
  style?: ViewStyle;
  accent?: string;
}) {
  return (
    <Animated.View entering={FadeIn.duration(320)} style={[styles.card, style]}>
      <View style={styles.header}>
        <View style={styles.titles}>
          <View style={styles.tagRow}>
            <View
              style={[
                styles.pilot,
                { backgroundColor: accent, boxShadow: glow(accent, 8) },
              ]}
            />
            <Text style={[styles.tag, { color: accent }]}>{tag}</Text>
          </View>
          {caption ? (
            <Text style={styles.caption} numberOfLines={2}>
              {caption}
            </Text>
          ) : null}
        </View>
        {action}
      </View>
      {children}
    </Animated.View>
  );
}

/** A round transport button that lights up while it plays. */
export function PlayButton({
  playing,
  onPress,
  label,
  accent = BRASS,
  testID,
}: {
  playing: boolean;
  onPress: () => void;
  label?: string;
  accent?: string;
  testID?: string;
}) {
  return (
    <Pressable
      onPress={onPress}
      hitSlop={10}
      testID={testID}
      style={({ pressed }) => [
        styles.play,
        label ? styles.playWide : null,
        { borderColor: accent + '88' },
        playing && {
          backgroundColor: accent,
          borderColor: accent,
          boxShadow: glow(accent, 16),
        },
        pressed && styles.pressed,
      ]}
    >
      <Text style={[styles.playIcon, { color: playing ? MIDNIGHT : accent }]}>
        {playing ? '■' : '▶\uFE0E'}
      </Text>
      {label ? (
        <Text
          style={[styles.playLabel, { color: playing ? MIDNIGHT : accent }]}
        >
          {label}
        </Text>
      ) : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundImage: GEAR_BACKGROUND,
    boxShadow: GEAR_SHADOW,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: RULE,
    padding: 16,
    marginVertical: 10,
    gap: 14,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  titles: {
    flex: 1,
    gap: 3,
  },
  tagRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 7,
  },
  pilot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  tag: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 2,
  },
  caption: {
    fontFamily: FONTS.italic,
    fontStyle: 'italic',
    fontSize: 17,
    lineHeight: 22,
    color: CREAM,
  },
  play: {
    minWidth: 38,
    height: 38,
    borderRadius: 19,
    borderWidth: 1.5,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: '#0B0E19',
  },
  playWide: {
    paddingHorizontal: 14,
  },
  pressed: {
    transform: [{ scale: 0.94 }],
  },
  playIcon: {
    fontSize: 13,
  },
  playLabel: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
    letterSpacing: 1.2,
    textTransform: 'uppercase',
  },
});
