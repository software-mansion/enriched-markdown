import { memo, useEffect, useMemo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, {
  interpolate,
  useAnimatedStyle,
  useFrameCallback,
  useSharedValue,
  withRepeat,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';
import type { MarkdownLinkBlock } from 'react-native-enriched-markdown';
import {
  ENVELOPE_RATE,
  loopPlayer,
  usePlaying,
  type Line,
  type Loop,
} from '../loops';
import { AMBER, EL, FONTS, PAPER, PAPER_SOFT, SPACE, STAR } from '../theme';
import { CardTitle, cardStyle } from './CardTitle';
import { useEntrance } from './motion';

const BARS = 46;
// The landing call is cued once its card has settled.
const CUE_DELAY_MS = 700;

// A link to one of NASA's clips as a loop on the Mission Control console:
// tap to listen, and the transcript lights word by word with the voices.
export function Transmission({
  block,
  loop,
}: {
  block: MarkdownLinkBlock;
  loop: Loop;
}) {
  const playing = usePlaying();
  const live = playing?.url === loop.url ? playing : null;
  const startedAt = useSharedValue(0);
  const elapsed = useSharedValue(-1);
  const entrance = useEntrance();

  useEffect(() => {
    startedAt.value = live?.startedAt ?? 0;
    if (!live) elapsed.value = -1;
  }, [live, startedAt, elapsed]);

  useFrameCallback(() => {
    if (startedAt.value === 0) return;
    elapsed.value = Math.max(0, (Date.now() - startedAt.value) / 1000);
  });

  useEffect(() => {
    if (!loop.autoCue || !loopPlayer.autoCue || loopPlayer.cued.has(loop.url)) {
      return;
    }
    loopPlayer.cued.add(loop.url);
    const timer = setTimeout(() => loopPlayer.play(loop.url), CUE_DELAY_MS);
    return () => clearTimeout(timer);
  }, [loop]);

  const [get, ...who] = block.title.split(' · ');
  const style = useAnimatedStyle(() => ({
    opacity: entrance.value,
    transform: [{ translateY: interpolate(entrance.value, [0, 1], [18, 0]) }],
  }));

  return (
    <Animated.View style={[styles.card, style]}>
      <CardTitle
        renderer="Transmission"
        title={loop.loop}
        right={
          <View style={styles.head}>
            <OnAir live={live !== null} />
            <Text style={styles.get}>{get ? `GET ${get}` : ''}</Text>
          </View>
        }
      />
      <View style={styles.titleRow}>
        <Pressable
          onPress={() => loopPlayer.toggle(loop.url)}
          hitSlop={10}
          accessibilityRole="button"
          accessibilityLabel={
            live ? 'Stop the transmission' : `Play ${block.label}`
          }
          style={[styles.play, live && styles.playLive]}
        >
          {live ? (
            <View style={styles.stopGlyph} />
          ) : (
            <View style={styles.playGlyph} />
          )}
        </Pressable>
        <View style={styles.titles}>
          <Text style={styles.label}>{block.label}</Text>
          {who.length > 0 && <Text style={styles.who}>{who.join(' · ')}</Text>}
        </View>
      </View>
      <Waveform
        envelope={live?.envelope}
        length={live?.length}
        elapsed={elapsed}
      />
      <View style={styles.transcript}>
        {loop.lines.map((line, i) => (
          <Caption key={i} line={line} elapsed={elapsed} />
        ))}
      </View>
      <Text style={styles.credit}>NASA AUDIO · PUBLIC DOMAIN</Text>
    </Animated.View>
  );
}

function OnAir({ live }: { live: boolean }) {
  const pulse = useSharedValue(0);
  useEffect(() => {
    pulse.value = live
      ? withRepeat(withTiming(1, { duration: 600 }), -1, true)
      : withTiming(0, { duration: 200 });
  }, [pulse, live]);
  const style = useAnimatedStyle(() => ({
    opacity: 0.25 + pulse.value * 0.75,
  }));
  return <Animated.View style={[styles.onAir, style]} />;
}

const Waveform = memo(function Waveform({
  envelope,
  length,
  elapsed,
}: {
  envelope?: number[];
  length?: number;
  elapsed: SharedValue<number>;
}) {
  // Until the clip is decoded the bars sit at a low hum.
  const heights = useMemo(() => {
    if (!envelope?.length) return Array.from({ length: BARS }, () => 0.12);
    const per = envelope.length / BARS;
    return Array.from({ length: BARS }, (_, i) => {
      const slice = envelope.slice(
        Math.floor(i * per),
        Math.floor((i + 1) * per)
      );
      return Math.max(0.08, Math.max(...slice, 0));
    });
  }, [envelope]);
  const seconds = length ?? (envelope ? envelope.length / ENVELOPE_RATE : 1);
  return (
    <View style={styles.wave}>
      {heights.map((h, i) => (
        <Bar key={i} height={h} at={(i / BARS) * seconds} elapsed={elapsed} />
      ))}
    </View>
  );
});

function Bar({
  height,
  at,
  elapsed,
}: {
  height: number;
  at: number;
  elapsed: SharedValue<number>;
}) {
  const style = useAnimatedStyle(() => ({
    backgroundColor: elapsed.value >= at ? EL : '#2C3542',
  }));
  return (
    <Animated.View
      style={[styles.bar, { height: `${height * 100}%` }, style]}
    />
  );
}

const Caption = memo(function Caption({
  line,
  elapsed,
}: {
  line: Line;
  elapsed: SharedValue<number>;
}) {
  return (
    <View style={styles.caption}>
      <Text style={[styles.speaker, line.who === 'DUKE' && styles.capcom]}>
        {line.who === 'DUKE' ? 'CAPCOM' : 'EAGLE'}
      </Text>
      <View style={styles.words}>
        {line.words.map(([at, word], i) => (
          <Word key={i} at={at} word={word} elapsed={elapsed} />
        ))}
      </View>
    </View>
  );
});

function Word({
  at,
  word,
  elapsed,
}: {
  at: number;
  word: string;
  elapsed: SharedValue<number>;
}) {
  const style = useAnimatedStyle(() => {
    // Before the clip plays the whole transcript reads; while it plays the
    // words light up as they are spoken.
    const idle = elapsed.value < 0;
    const spoken = elapsed.value >= at;
    return {
      color: idle ? PAPER : spoken ? STAR : '#4E5867',
      opacity: idle ? 0.85 : 1,
    };
  });
  return <Animated.Text style={[styles.word, style]}>{word}</Animated.Text>;
}

const styles = StyleSheet.create({
  card: {
    ...cardStyle,
    gap: 12,
  },
  head: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  onAir: {
    width: 7,
    height: 7,
    borderRadius: 3.5,
    backgroundColor: AMBER,
  },
  loop: {
    flex: 1,
    fontFamily: FONTS.label,
    fontSize: 9.5,
    letterSpacing: 1.4,
    color: PAPER_SOFT,
  },
  get: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 0.6,
    color: AMBER,
  },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  play: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: AMBER,
    alignItems: 'center',
    justifyContent: 'center',
  },
  playLive: {
    backgroundColor: STAR,
  },
  playGlyph: {
    marginLeft: 4,
    width: 0,
    height: 0,
    borderTopWidth: 8,
    borderBottomWidth: 8,
    borderLeftWidth: 13,
    borderTopColor: 'transparent',
    borderBottomColor: 'transparent',
    borderLeftColor: SPACE,
  },
  stopGlyph: {
    width: 13,
    height: 13,
    borderRadius: 2,
    backgroundColor: SPACE,
  },
  titles: {
    flex: 1,
  },
  label: {
    fontFamily: FONTS.display,
    fontSize: 30,
    lineHeight: 32,
    color: STAR,
  },
  who: {
    fontFamily: FONTS.mono,
    fontSize: 10,
    color: PAPER_SOFT,
  },
  wave: {
    height: 34,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  bar: {
    flex: 1,
    borderRadius: 1,
  },
  transcript: {
    gap: 6,
  },
  caption: {
    flexDirection: 'row',
    gap: 10,
  },
  speaker: {
    width: 52,
    paddingTop: 4,
    fontFamily: FONTS.label,
    fontSize: 8.5,
    letterSpacing: 1,
    color: AMBER,
  },
  capcom: {
    color: '#7FA6FF',
  },
  words: {
    flex: 1,
    flexDirection: 'row',
    flexWrap: 'wrap',
    columnGap: 5,
  },
  word: {
    fontFamily: FONTS.body,
    fontSize: 17,
    lineHeight: 23,
  },
  credit: {
    fontFamily: FONTS.mono,
    fontSize: 8.5,
    letterSpacing: 0.8,
    color: '#5B6576',
  },
});
