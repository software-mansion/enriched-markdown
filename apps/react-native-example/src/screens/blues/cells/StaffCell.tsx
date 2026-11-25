import { useMemo, useRef, useState } from 'react';
import { StyleSheet, Text, View, type LayoutChangeEvent } from 'react-native';
import Animated, {
  FadeInDown,
  interpolateColor,
  useAnimatedStyle,
  useSharedValue,
  type SharedValue,
} from 'react-native-reanimated';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import { engine, STEP_SECONDS } from '../audio';
import { FONTS, INK, PAPER } from '../theme';
import { Card, PlayButton, splitCode, useArrivals, useNow } from './Card';

const GAP = 12;
const TOP = 26;
const BOTTOM_LINE = TOP + GAP * 4;
const CLEF = 52;
const HEAD_W = 14;
const HEAD_H = 10.5;
const STAGE = BOTTOM_LINE + GAP * 3;
const NOTE_SECONDS = STEP_SECONDS * 2;
const GLOW_MS = 500;
const DIATONIC: Record<string, number> = {
  C: 0,
  D: 1,
  E: 2,
  F: 3,
  G: 4,
  A: 5,
  B: 6,
};

interface Written {
  midi: number;
  // Staff positions above the bottom line, E4: a line every two.
  position: number;
  accidental: '♭' | '♯' | '';
  name: string;
}

// The note as written, so E♭ sits on the E line with a flat beside it.
function spell(word: string): Written | null {
  const match = /^([A-G])(#|b)?(\d)$/.exec(word);
  if (!match) return null;
  const letter = match[1]!;
  const octave = Number(match[3]);
  const semis: Record<string, number> = {
    C: 0,
    D: 2,
    E: 4,
    F: 5,
    G: 7,
    A: 9,
    B: 11,
  };
  const shift = match[2] === '#' ? 1 : match[2] === 'b' ? -1 : 0;
  const accidental = match[2] === '#' ? '♯' : match[2] === 'b' ? '♭' : '';
  return {
    midi: 12 * (octave + 1) + semis[letter]! + shift,
    position: octave * 7 + DIATONIC[letter]! - (4 * 7 + 2),
    accidental,
    name: letter + accidental,
  };
}

/**
 * A ```staff block: the notes on a treble staff. Each drops onto its line as
 * the answer writes it and sounds as it lands; ▶ plays the line back with a
 * cursor, so the reader sees what they hear.
 */
export function StaffCell({ block }: { block: MarkdownCodeBlock }) {
  const { caption, body } = splitCode(block.code);
  const notes = useMemo(
    () =>
      body
        .join(' ')
        .split(/\s+/)
        .map(spell)
        .filter((n): n is Written => n !== null),
    [body.join(' ')] // eslint-disable-line react-hooks/exhaustive-deps
  );
  const [width, setWidth] = useState(0);
  const [playing, setPlaying] = useState(false);
  const now = useNow();
  // When each written note last sounded, by its place in the line.
  const struck = useSharedValue<number[]>([]);

  const sound = (index: number, at: number) => {
    const note = notes[index];
    if (!note) return;
    engine.piano(note.midi, at, NOTE_SECONDS * 0.95, 0.8);
    const wall = engine.wall(at);
    struck.modify((value) => {
      'worklet';
      value[index] = wall;
      return value;
    });
  };

  // Notes land faster than they ring, so each waits for the one before.
  const free = useRef(0);
  useArrivals(block, notes.length, (index) => {
    const at = Math.max(engine.now(), free.current);
    free.current = at + NOTE_SECONDS * 0.6;
    sound(index, at);
  });

  const play = () => {
    if (playing) return;
    const start = engine.now();
    notes.forEach((_, i) => sound(i, start + i * NOTE_SECONDS));
    setPlaying(true);
    setTimeout(
      () => setPlaying(false),
      notes.length * NOTE_SECONDS * 1000 + 200
    );
  };

  // Spread across the staff, first note to last, as the line fills in.
  const step = Math.min(
    54,
    (width - CLEF - 14 - HEAD_W - 10) / Math.max(notes.length - 1, 6)
  );

  return (
    <Card
      tag="STAFF"
      caption={caption}
      action={
        block.isComplete ? (
          <PlayButton playing={playing} onPress={play} testID="staff-play" />
        ) : null
      }
    >
      <View style={styles.paper}>
        <View
          style={styles.stage}
          onLayout={(e: LayoutChangeEvent) =>
            setWidth(e.nativeEvent.layout.width)
          }
        >
          {[0, 1, 2, 3, 4].map((line) => (
            <View key={line} style={[styles.line, { top: TOP + line * GAP }]} />
          ))}
          <Text style={styles.clef}>𝄞</Text>
          {width > 0 &&
            notes.map((note, i) => (
              <Note
                key={i}
                index={i}
                note={note}
                x={CLEF + 14 + i * step}
                struck={struck}
                now={now}
              />
            ))}
        </View>
      </View>
    </Card>
  );
}

function Note({
  index,
  note,
  x,
  struck,
  now,
}: {
  index: number;
  note: Written;
  x: number;
  struck: SharedValue<number[]>;
  now: SharedValue<number>;
}) {
  const y = BOTTOM_LINE - (note.position * GAP) / 2;
  const up = note.position < 4;
  const ledgers: number[] = [];
  for (let p = -2; p >= note.position; p -= 2) ledgers.push(p);
  for (let p = 10; p <= note.position; p += 2) ledgers.push(p);

  const glow = useAnimatedStyle(() => {
    const at = struck.value[index] ?? 0;
    const age = now.value - at;
    const level = age >= 0 && age < 3000 ? Math.exp(-age / GLOW_MS) : 0;
    return {
      backgroundColor: interpolateColor(level, [0, 1], [INK, '#E0891F']),
      transform: [{ rotate: '-20deg' }, { scale: 1 + level * 0.35 }],
      boxShadow: `0 0 ${level * 14}px #FFB547${level > 0.02 ? 'CC' : '00'}`,
    };
  });
  const stemGlow = useAnimatedStyle(() => {
    const age = now.value - (struck.value[index] ?? 0);
    const level = age >= 0 && age < 3000 ? Math.exp(-age / GLOW_MS) : 0;
    return {
      backgroundColor: interpolateColor(level, [0, 1], [INK, '#E0891F']),
    };
  });

  return (
    <Animated.View
      entering={FadeInDown.springify().damping(9).stiffness(180)}
      style={[styles.note, { left: x }]}
    >
      {ledgers.map((p) => (
        <View
          key={p}
          style={[styles.ledger, { top: BOTTOM_LINE - (p * GAP) / 2 }]}
        />
      ))}
      {note.accidental !== '' && (
        <Text style={[styles.accidental, { top: y - 13 }]}>
          {note.accidental}
        </Text>
      )}
      <Animated.View
        style={[
          styles.stem,
          up ? { left: HEAD_W - 1.5, top: y - GAP * 3.3 } : { left: 0, top: y },
          stemGlow,
        ]}
      />
      <Animated.View style={[styles.head, { top: y - HEAD_H / 2 }, glow]} />
      <Text style={[styles.name, note.accidental === '♭' && styles.blue]}>
        {note.name}
      </Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  // Manuscript paper under the stage light.
  paper: {
    backgroundColor: PAPER,
    backgroundImage:
      'radial-gradient(ellipse 90% 70% at 30% 0%, #FFF8E8 0%, #F3EAD7 60%, #E4D6BA 100%)',
    boxShadow: 'inset 0 0 0 1px #D7C8A8, 0 10px 18px -10px rgba(0,0,0,0.8)',
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingTop: 6,
    paddingBottom: 4,
  },
  stage: {
    height: STAGE + 22,
  },
  line: {
    position: 'absolute',
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: '#1C1A2466',
  },
  clef: {
    position: 'absolute',
    left: 2,
    top: TOP - 30,
    fontSize: 76,
    lineHeight: 108,
    color: INK,
  },
  note: {
    position: 'absolute',
    top: 0,
    width: HEAD_W,
    height: STAGE + 22,
  },
  head: {
    position: 'absolute',
    left: 0,
    width: HEAD_W,
    height: HEAD_H,
    borderRadius: HEAD_H / 2,
  },
  stem: {
    position: 'absolute',
    width: 1.5,
    height: GAP * 3.3,
  },
  ledger: {
    position: 'absolute',
    left: -5,
    width: HEAD_W + 10,
    height: 1,
    backgroundColor: '#1C1A24AA',
  },
  accidental: {
    position: 'absolute',
    left: -12,
    fontSize: 17,
    color: '#2747B0',
  },
  name: {
    position: 'absolute',
    top: STAGE + 2,
    width: HEAD_W + 20,
    left: -10,
    textAlign: 'center',
    fontFamily: FONTS.italic,
    fontStyle: 'italic',
    fontSize: 15,
    color: '#6B5E48',
  },
  blue: {
    color: '#2747B0',
  },
});
