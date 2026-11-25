import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useAnimatedReaction, useDerivedValue } from 'react-native-reanimated';
import { scheduleOnRN } from 'react-native-worklets';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import { engine, stepAt, stepTime, transport, usePlaying } from '../audio';
import { BLUES_LOOP, bluesLoop, tuneMasks, tuneSymbol } from '../band';
import { Keyboard, useHits } from '../Keyboard';
import {
  BLUE_NOTE,
  BLUES_SCALE,
  inScale,
  noteName,
  numeral,
  parseChord,
  parseNote,
  pitchClass,
} from '../theory';
import { BLUE, BRASS, CREAM, FONTS, SOFT, functionColor, glow } from '../theme';
import { Scope } from '../Scope';
import { Card, PlayButton, splitCode, useNow, useOnClose } from './Card';

// `scale C blues` and `lick C5 Eb5 F5 ...`: the keys to leave on, and a
// phrase the answer can play over the band to show how it's done.
function parseJam(lines: string[]) {
  let tonic = 60;
  let lick: (number | null)[] = [];
  for (const line of lines) {
    const scale = /^\s*scale\s+(\S+)/.exec(line);
    if (scale) tonic = parseNote(scale[1]! + '4') ?? 60;
    const phrase = /^\s*lick\s+(.*)$/.exec(line);
    if (phrase) {
      lick = phrase[1]!
        .split(/\s+/)
        .map((word) => (word === '-' ? null : parseNote(word)));
    }
  }
  return { tonic, lick };
}

const LOW = 60;
const HIGH = 84;

/**
 * A ```jam block, the finale: the band plays the twelve bars, and the
 * keyboard keeps only the blues scale. Every key left sounds right, and the
 * ones that fit the bar right now are ringed.
 */
export function JamCell({ block }: { block: MarkdownCodeBlock }) {
  const { caption, body } = splitCode(block.code);
  const { tonic, lick } = parseJam(body);
  const { hits, flash } = useHits();
  const playing = usePlaying() === BLUES_LOOP;
  const now = useNow();
  const [bar, setBar] = useState(-1);
  const lickTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const targets = useDerivedValue(() => {
    const t = transport.value;
    if (t.id !== BLUES_LOOP) return 0;
    const step = stepAt(t, now.value);
    return step < 0 ? 0 : (tuneMasks.value[Math.floor(step / 8)] ?? 0);
  });

  useAnimatedReaction(
    () => {
      const t = transport.value;
      if (t.id !== BLUES_LOOP) return -1;
      const step = stepAt(t, now.value);
      return step < 0 ? -1 : Math.floor(step / 8);
    },
    (current, previous) => {
      if (current !== previous) scheduleOnRN(setBar, current);
    }
  );

  const enabled = useCallback(
    (midi: number) => inScale(midi, tonic, BLUES_SCALE),
    [tonic]
  );

  const { marks, labels } = useMemo(() => {
    const dots: Record<number, string> = {};
    const names: Record<number, string> = {};
    for (let m = LOW; m <= HIGH; m++) {
      if (!inScale(m, tonic, BLUES_SCALE)) continue;
      names[m] = noteName(m);
      if (pitchClass(m - tonic) === BLUE_NOTE) dots[m] = BLUE;
    }
    return { marks: dots, labels: names };
  }, [tonic]);

  const play = useCallback(
    (midi: number) => {
      engine.piano(midi, undefined, 0.6, 0.85);
      flash(midi);
    },
    [flash]
  );

  const band = () => {
    if (playing) engine.stop(BLUES_LOOP);
    else engine.play(bluesLoop());
  };

  // The lick comes in on the next downbeat, a note per swung eighth.
  const playLick = () => {
    if (!playing) engine.play(bluesLoop());
    const start = engine.nextBar();
    lick.forEach((midi, i) => {
      if (midi === null) return;
      const at = start + stepTime(i);
      engine.piano(midi, at, 0.32, 0.9);
      flash(midi, engine.wall(at));
    });
  };

  useOnClose(block, () => {
    lickTimer.current = setTimeout(() => {
      if (!engine.playing) engine.play(bluesLoop());
    }, 500);
  });

  useEffect(
    () => () => {
      if (lickTimer.current) clearTimeout(lickTimer.current);
    },
    []
  );

  const chord = bar >= 0 ? tuneSymbol(bar) : null;
  const parsed = chord ? parseChord(chord) : null;
  const roman = parsed ? numeral(parsed, tonic) : null;
  const color = roman ? functionColor(roman) : SOFT;

  return (
    <Card
      tag="THE JAM"
      caption={caption}
      accent={BLUE}
      action={
        block.isComplete ? (
          <PlayButton
            playing={playing}
            onPress={band}
            label="band"
            accent={BLUE}
            testID="jam-band"
          />
        ) : null
      }
    >
      <View style={styles.stage}>
        <Scope height={46} color="#7FA2FF" />
        <View style={styles.status}>
          <View style={styles.now}>
            <Text style={[styles.numeral, { color }]}>{roman ?? 'READY'}</Text>
            <Text style={styles.chord}>{chord ?? '—'}</Text>
          </View>
          <View style={styles.bars}>
            {Array.from({ length: 12 }, (_, i) => (
              <View
                key={i}
                style={[
                  styles.barDot,
                  i === bar && {
                    backgroundColor: color,
                    boxShadow: glow(color, 8),
                  },
                  i < bar && styles.barPast,
                ]}
              />
            ))}
          </View>
        </View>
        <Keyboard
          low={LOW}
          high={HIGH}
          hits={hits}
          targets={targets}
          marks={marks}
          labels={labels}
          enabled={enabled}
          onKey={play}
          height={150}
          glow={BLUE}
        />
        <View style={styles.footer}>
          <Text style={styles.hint}>
            lit keys fit this bar · blue dot: the blue note
          </Text>
          {block.isComplete && lick.length > 0 && (
            <Pressable
              onPress={playLick}
              hitSlop={8}
              testID="jam-lick"
              style={({ pressed }) => [styles.lick, pressed && styles.pressed]}
            >
              <Text style={styles.lickText}>♪ SHOW ME A LICK</Text>
            </Pressable>
          )}
        </View>
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  stage: {
    marginHorizontal: -16,
    marginBottom: -16,
    paddingHorizontal: 12,
    paddingBottom: 14,
    gap: 12,
    borderBottomLeftRadius: 22,
    borderBottomRightRadius: 22,
    // A blue spotlight from above.
    backgroundImage:
      'radial-gradient(ellipse 80% 70% at 50% 0%, #1F3270 0%, #0A0F22 70%)',
  },
  status: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
    paddingHorizontal: 4,
  },
  now: {
    gap: 0,
  },
  numeral: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
    letterSpacing: 1.5,
  },
  chord: {
    fontFamily: FONTS.display,
    fontSize: 40,
    lineHeight: 44,
    color: CREAM,
  },
  bars: {
    flexDirection: 'row',
    gap: 5,
    paddingBottom: 10,
  },
  barDot: {
    width: 8,
    height: 8,
    borderRadius: 2,
    backgroundColor: '#ffffff1A',
  },
  barPast: {
    backgroundColor: '#ffffff40',
  },
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 8,
    paddingHorizontal: 4,
  },
  hint: {
    flex: 1,
    fontFamily: FONTS.mono,
    fontSize: 10,
    lineHeight: 14,
    color: '#AEB8DD',
  },
  lick: {
    borderWidth: 1,
    borderColor: BRASS + '99',
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 7,
    backgroundColor: '#2A1E0C',
  },
  pressed: {
    transform: [{ scale: 0.95 }],
  },
  lickText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
    letterSpacing: 1,
    color: BRASS,
  },
});
