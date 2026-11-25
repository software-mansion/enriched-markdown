import { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, {
  FadeInLeft,
  useAnimatedStyle,
  useDerivedValue,
  type SharedValue,
} from 'react-native-reanimated';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import {
  BPM,
  engine,
  stepAt,
  stepTime,
  STEPS_PER_BAR,
  transport,
  usePlaying,
  type Drum,
} from '../audio';
import { BLUES_LOOP } from '../band';
import { BRASS, CREAM, FONTS, RED, SOFT } from '../theme';
import {
  Card,
  PlayButton,
  splitCode,
  useArrivals,
  useNow,
  useOnClose,
} from './Card';

const GROOVE_LOOP = 'groove';
const NEXT: Record<string, string> = { '.': 'x', 'x': 'o', 'o': '.' };
const COLORS: Record<Drum, string> = {
  kick: BRASS,
  snare: RED,
  hat: '#9DB8FF',
};

// `kick x...x...`: a row per drum, a swung eighth per character; `x` hits,
// `o` ghosts, `.` rests.
function parseGroove(lines: string[]) {
  const rows: { drum: Drum; cells: string }[] = [];
  for (const line of lines) {
    const match = /^\s*(kick|snare|hat)\s+([xo.]+)\s*$/.exec(line);
    if (match) {
      rows.push({
        drum: match[1] as Drum,
        cells: match[2]!.padEnd(STEPS_PER_BAR, '.').slice(0, STEPS_PER_BAR),
      });
    }
  }
  return rows;
}

/**
 * A ```groove block: a step sequencer. Each drum sounds as its row is
 * written, the beat starts when the block closes, and every step is a
 * button: the reader's edits are what the band plays later.
 */
export function GrooveCell({ block }: { block: MarkdownCodeBlock }) {
  const { caption, body } = splitCode(block.code);
  const written = parseGroove(body);
  const [edits, setEdits] = useState<Partial<Record<Drum, string>>>({});
  const rows = written.map((row) => ({
    ...row,
    cells: edits[row.drum] ?? row.cells,
  }));
  const playing = usePlaying();
  const now = useNow();

  useEffect(() => {
    const groove = { ...engine.groove };
    for (const row of rows) groove[row.drum] = row.cells;
    engine.groove = groove;
  });

  useArrivals(block, written.length, (index) => {
    const row = written[index];
    if (!row) return;
    const at = engine.now();
    [...row.cells].forEach((cell, step) => {
      if (cell !== '.')
        engine.drum(
          row.drum,
          at + stepTime(step) / 2,
          cell === 'x' ? 0.9 : 0.4
        );
    });
  });

  const start = () =>
    engine.play({
      id: GROOVE_LOOP,
      steps: STEPS_PER_BAR,
      onStep: (step, at) => engine.playGrooveStep(step, at),
    });

  // The beat starts as the block closes and keeps going: the rest of the
  // lesson lands on it, and the band joins it at the twelve bars.
  useOnClose(block, () => setTimeout(start, 300));

  const toggle = (drum: Drum, step: number) => {
    const row = rows.find((r) => r.drum === drum);
    if (!row) return;
    const cell = NEXT[row.cells[step]!]!;
    const cells = row.cells.slice(0, step) + cell + row.cells.slice(step + 1);
    setEdits((value) => ({ ...value, [drum]: cells }));
    if (cell !== '.') engine.drum(drum, undefined, cell === 'x' ? 1 : 0.45);
  };

  const on = playing === GROOVE_LOOP;

  return (
    <Card
      tag={`SHUFFLE · ${BPM} BPM`}
      caption={caption}
      accent={RED}
      action={
        block.isComplete ? (
          <PlayButton
            playing={on}
            accent={RED}
            testID="groove-play"
            onPress={() => (on ? engine.stop(GROOVE_LOOP) : start())}
          />
        ) : null
      }
    >
      <View style={styles.machine}>
        <View style={styles.row}>
          <View style={styles.rowLabel} />
          {Array.from({ length: STEPS_PER_BAR }, (_, step) => (
            <Led key={step} step={step} now={now} />
          ))}
        </View>
        {rows.map((row) => (
          <Animated.View
            key={row.drum}
            entering={FadeInLeft.duration(260)}
            style={styles.row}
          >
            <View style={styles.rowLabel}>
              <View
                style={[styles.drumDot, { backgroundColor: COLORS[row.drum] }]}
              />
              <Text style={styles.drumName}>{row.drum.toUpperCase()}</Text>
            </View>
            {[...row.cells].map((cell, step) => (
              <Step
                key={step}
                step={step}
                cell={cell}
                color={COLORS[row.drum]}
                now={now}
                onPress={() => toggle(row.drum, step)}
                testID={`groove-${row.drum}-${step}`}
              />
            ))}
          </Animated.View>
        ))}
        <View style={styles.row}>
          <View style={styles.rowLabel} />
          {Array.from({ length: STEPS_PER_BAR }, (_, step) => (
            <Text
              key={step}
              style={[styles.count, step % 2 === 1 && styles.and]}
            >
              {step % 2 ? '&' : step / 2 + 1}
            </Text>
          ))}
        </View>
      </View>
      <Text style={styles.hint}>
        {block.isComplete
          ? 'tap a pad: hit · ghost · rest. the band plays your beat.'
          : ' '}
      </Text>
    </Card>
  );
}

function useHere(step: number, now: SharedValue<number>) {
  return useDerivedValue(() => {
    const t = transport.value;
    const live = t.id === GROOVE_LOOP || t.id === BLUES_LOOP;
    return live && stepAt(t, now.value) % STEPS_PER_BAR === step ? 1 : 0;
  });
}

// The running light over the pads.
function Led({ step, now }: { step: number; now: SharedValue<number> }) {
  const here = useHere(step, now);
  const style = useAnimatedStyle(() => ({
    backgroundColor: here.value ? '#FF5A4E' : '#3A1416',
    boxShadow: here.value ? '0 0 10px #FF5A4E' : 'none',
  }));
  return (
    <View style={styles.ledCell}>
      <Animated.View style={[styles.led, style]} />
    </View>
  );
}

function Step({
  step,
  cell,
  color,
  now,
  onPress,
  testID,
}: {
  step: number;
  cell: string;
  color: string;
  now: SharedValue<number>;
  onPress: () => void;
  testID: string;
}) {
  const rest = cell === '.';
  const hit = cell === 'x';
  const here = useHere(step, now);

  const animated = useAnimatedStyle(() => {
    const on = here.value === 1;
    return {
      transform: [{ scale: on && !rest ? 1.08 : 1 }],
      boxShadow: on
        ? rest
          ? 'inset 0 0 0 1px #FFFFFF44'
          : `0 0 16px ${color}, inset 0 1px 0 rgba(255,255,255,0.5)`
        : rest
          ? 'inset 0 2px 4px rgba(0,0,0,0.7)'
          : 'inset 0 1px 0 rgba(255,255,255,0.35), 0 2px 3px rgba(0,0,0,0.6)',
    };
  });

  return (
    <Pressable
      onPress={onPress}
      style={styles.stepWrap}
      testID={testID}
      hitSlop={2}
    >
      <Animated.View
        style={[
          styles.pad,
          step % 4 === 0 && styles.downbeat,
          rest
            ? null
            : {
                backgroundImage: `linear-gradient(180deg, ${color}${hit ? 'FF' : '77'} 0%, ${color}${hit ? 'B0' : '44'} 100%)`,
              },
          animated,
        ]}
      />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  machine: {
    backgroundImage: 'linear-gradient(180deg, #1E2130 0%, #12141D 100%)',
    boxShadow:
      'inset 0 1px 0 rgba(255,255,255,0.08), inset 0 -2px 0 rgba(0,0,0,0.5)',
    borderRadius: 14,
    padding: 12,
    gap: 9,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  rowLabel: {
    width: 54,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  drumDot: {
    width: 5,
    height: 5,
    borderRadius: 3,
  },
  drumName: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 1,
    color: CREAM,
  },
  ledCell: {
    flex: 1,
    alignItems: 'center',
  },
  led: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  stepWrap: {
    flex: 1,
  },
  pad: {
    height: 34,
    borderRadius: 8,
    backgroundColor: '#0E1018',
  },
  downbeat: {
    borderWidth: 1,
    borderColor: '#FFFFFF14',
  },
  count: {
    flex: 1,
    textAlign: 'center',
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    color: SOFT,
  },
  and: {
    color: '#555D7C',
  },
  hint: {
    fontFamily: FONTS.mono,
    fontSize: 11,
    color: SOFT,
    textAlign: 'center',
  },
});
