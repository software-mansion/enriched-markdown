import { useEffect, useMemo, useRef } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  ZoomIn,
  useAnimatedStyle,
  type SharedValue,
} from 'react-native-reanimated';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import { STEP_SECONDS, engine, transport, usePlaying } from '../audio';
import { BLUES_LOOP, bluesLoop, setTune } from '../band';
import {
  compVoicing,
  numeral,
  parseChord,
  pitchClass,
  type Chord,
} from '../theory';
import { CREAM, FONTS, SOFT, functionColor } from '../theme';
import {
  Card,
  PlayButton,
  splitCode,
  useArrivals,
  useNow,
  useOnClose,
} from './Card';

const BARS_PER_LINE = 4;

/**
 * A ```progression block: the twelve-bar blues as a chart, a tile a bar,
 * coloured by where it sits in the key: home, away, and the pull back. Each
 * line of bars sounds as it is written; ▶ brings the whole band in.
 */
export function ProgressionCell({ block }: { block: MarkdownCodeBlock }) {
  const { caption, body } = splitCode(block.code);
  const chords = useMemo(
    () =>
      body
        .join(' ')
        .split(/[\s|]+/)
        .map(parseChord)
        .filter((c): c is Chord => c !== null),
    [body.join(' ')] // eslint-disable-line react-hooks/exhaustive-deps
  );
  const key = chords[0] ? pitchClass(chords[0].root) : 0;
  const playing = usePlaying() === BLUES_LOOP;
  const now = useNow();

  useEffect(() => {
    if (block.isComplete) setTune(chords);
  }, [block.isComplete, chords]);

  // A line of bars lands at once and plays through, a chord a beat; with the
  // drums going, the line lands on a downbeat and the chords on the beats.
  const free = useRef(0);
  useArrivals(block, chords.length, (index) => {
    const chord = chords[index];
    if (!chord) return;
    const beat = STEP_SECONDS * 2;
    const at = Math.max(
      engine.playing ? engine.nextBeat() : engine.now(),
      free.current
    );
    free.current = at + (engine.playing ? beat : 0.18);
    engine.bass(36 + pitchClass(chord.root), at, beat * 0.9);
    compVoicing(chord).forEach((midi) =>
      engine.piano(midi, at, beat * 0.8, 0.55)
    );
  });

  // The band joins the drums on the next downbeat as the chart completes.
  useOnClose(block, () => {
    if (!engine.playing) return;
    setTune(chords);
    engine.play(bluesLoop());
  });

  const toggle = () => {
    if (playing) {
      engine.stop(BLUES_LOOP);
      return;
    }
    setTune(chords);
    engine.play(bluesLoop());
  };

  return (
    <Card
      tag="THE 12-BAR BLUES"
      caption={caption}
      action={
        block.isComplete ? (
          <PlayButton
            playing={playing}
            onPress={toggle}
            label="band"
            testID="progression-play"
          />
        ) : null
      }
    >
      <View style={styles.chart}>
        {chords.map((chord, bar) => (
          <Bar
            key={bar}
            bar={bar}
            bars={chords.length}
            chord={chord}
            numeral={numeral(chord, key)}
            now={now}
          />
        ))}
      </View>
      <View style={styles.legend}>
        {(['I', 'IV', 'V'] as const).map((n) => (
          <View
            key={n}
            style={[styles.chip, { borderColor: functionColor(n) + '55' }]}
          >
            <Text style={[styles.chipNumeral, { color: functionColor(n) }]}>
              {n}
            </Text>
            <Text style={styles.chipText}>
              {n === 'I' ? 'home' : n === 'IV' ? 'away' : 'pull home'}
            </Text>
          </View>
        ))}
      </View>
    </Card>
  );
}

function Bar({
  bar,
  bars,
  chord,
  numeral: roman,
  now,
}: {
  bar: number;
  bars: number;
  chord: Chord;
  numeral: string;
  now: SharedValue<number>;
}) {
  const color = functionColor(roman);

  // How far through this bar the band is, 0 to 1; 0 when it is elsewhere.
  const fill = useAnimatedStyle(() => {
    const t = transport.value;
    if (t.id !== BLUES_LOOP) return { width: '0%', opacity: 0 };
    const barMs = t.beatMs * 4;
    const elapsed = now.value - t.startedAt;
    if (elapsed < 0) return { width: '0%', opacity: 0 };
    const position = (elapsed / barMs) % bars;
    const here = Math.floor(position) === bar;
    return {
      width: `${here ? (position - bar) * 100 : 0}%`,
      opacity: here ? 1 : 0,
    };
  });

  const lit = useAnimatedStyle(() => {
    const t = transport.value;
    const elapsed = now.value - t.startedAt;
    const here =
      t.id === BLUES_LOOP &&
      elapsed >= 0 &&
      Math.floor((elapsed / (t.beatMs * 4)) % bars) === bar;
    return {
      borderColor: here ? color : color + '30',
      boxShadow: here
        ? `0 0 18px ${color}99, inset 0 1px 0 rgba(255,255,255,0.12)`
        : 'inset 0 1px 0 rgba(255,255,255,0.06)',
      transform: [{ scale: here ? 1.05 : 1 }],
    };
  });

  return (
    <Animated.View
      entering={ZoomIn.springify()
        .damping(14)
        .delay((bar % BARS_PER_LINE) * 70)}
      style={styles.barWrap}
    >
      <Animated.View
        style={[
          styles.bar,
          {
            backgroundImage: `linear-gradient(160deg, ${color}38 0%, #0D1120 75%)`,
          },
          lit,
        ]}
      >
        <Animated.View
          style={[styles.progress, { backgroundColor: color + '45' }, fill]}
        />
        <Text style={[styles.numeral, { color }]}>{roman}</Text>
        <Text style={styles.symbol}>{chord.symbol}</Text>
        <Text style={styles.barNumber}>{bar + 1}</Text>
      </Animated.View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  chart: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginHorizontal: -4,
  },
  barWrap: {
    width: `${100 / BARS_PER_LINE}%`,
    padding: 4,
  },
  bar: {
    height: 70,
    borderRadius: 12,
    borderWidth: 1,
    overflow: 'hidden',
    justifyContent: 'flex-end',
    paddingHorizontal: 10,
    paddingBottom: 8,
  },
  progress: {
    ...StyleSheet.absoluteFill,
    right: undefined,
  },
  numeral: {
    position: 'absolute',
    top: 8,
    left: 10,
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 1,
  },
  barNumber: {
    position: 'absolute',
    top: 8,
    right: 9,
    fontFamily: FONTS.mono,
    fontSize: 9,
    color: '#ffffff40',
  },
  symbol: {
    fontFamily: FONTS.display,
    fontSize: 24,
    lineHeight: 28,
    color: CREAM,
  },
  legend: {
    flexDirection: 'row',
    gap: 8,
  },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    borderWidth: 1,
    borderRadius: 12,
    paddingHorizontal: 9,
    paddingVertical: 4,
  },
  chipNumeral: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
  },
  chipText: {
    fontFamily: FONTS.mono,
    fontSize: 11,
    color: SOFT,
  },
});
