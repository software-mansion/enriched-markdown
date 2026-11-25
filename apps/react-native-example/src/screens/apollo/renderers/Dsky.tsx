import { memo, useEffect, useMemo, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  interpolate,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import {
  AMBER,
  AMBER_DIM,
  CONSOLE,
  CONSOLE_EDGE,
  EL,
  FONTS,
  PAPER_SOFT,
} from '../theme';
import { codeLines, useEntrance } from './motion';
import { Segments } from './Segments';

const LINE_MS = 420;
const KEYS_AFTER_ALARM_MS = 1500;
const KEY_MS = 300;
// What the crew keys to read the alarm: Verb 05, Noun 09, Enter.
const ALARM_KEYS = ['VERB', '0', '5', 'NOUN', '0', '9', 'ENTR'];

const BLANK = '      ';

interface Display {
  prog: string;
  verb: string;
  noun: string;
  registers: [string, string, string];
  alarm: string | null;
}

function register(value: string) {
  const sign = value.startsWith('-') ? '-' : '+';
  return sign + value.replace(/^[-+]/, '').padStart(5, '0').slice(-5);
}

// Each line of the block keys one thing into the display: `PROG 63`,
// `VERB 16  NOUN 68`, `R3 -02900`, `ALARM 1202`.
function apply(lines: string[]): Display {
  const display: Display = {
    prog: '  ',
    verb: '  ',
    noun: '  ',
    registers: [BLANK, BLANK, BLANK],
    alarm: null,
  };
  for (const line of lines) {
    for (const [, key, value] of line.matchAll(
      /(PROG|VERB|NOUN|R[123]|ALARM)\s+(\S+)/g
    )) {
      if (!key || !value) continue;
      if (key === 'PROG') display.prog = value.padStart(2, '0');
      else if (key === 'VERB') display.verb = value.padStart(2, '0');
      else if (key === 'NOUN') display.noun = value.padStart(2, '0');
      else if (key === 'ALARM') display.alarm = value;
      else display.registers[Number(key[1]) - 1] = register(value);
    }
  }
  return display;
}

// Verb 05 Noun 09 as the crew keys it, then the alarm codes it shows: the
// first in R1, the second in R2 and the latest in R3.
function keyed(display: Display, pressed: number): Display {
  if (pressed < 0 || !display.alarm) return display;
  const typed = (from: number) =>
    ALARM_KEYS.slice(from + 1, from + 3)
      .slice(0, Math.max(0, pressed - from))
      .join('')
      .padEnd(2, ' ');
  const code = register(display.alarm);
  return {
    ...display,
    verb: typed(0),
    noun: pressed >= 3 ? typed(3) : display.noun,
    registers:
      pressed >= ALARM_KEYS.length - 1
        ? [code, register('0'), code]
        : display.registers,
  };
}

// The Apollo Guidance Computer's display and keyboard, keyed by the lines of
// a ```dsky block as they stream in.
export function Dsky({ block }: { block: MarkdownCodeBlock }) {
  const lines = useMemo(() => codeLines(block.code), [block.code]);
  const [shown, setShown] = useState(0);
  const [pressed, setPressed] = useState(-1);
  const entrance = useEntrance();

  useEffect(() => {
    if (shown >= lines.length) return;
    const timer = setTimeout(() => setShown((n) => n + 1), LINE_MS);
    return () => clearTimeout(timer);
  }, [shown, lines.length]);

  const display = apply(lines.slice(0, shown));
  const alarmed = display.alarm !== null;

  useEffect(() => {
    if (!alarmed || pressed >= ALARM_KEYS.length - 1) return;
    const timer = setTimeout(
      () => setPressed((n) => n + 1),
      pressed < 0 ? KEYS_AFTER_ALARM_MS : KEY_MS
    );
    return () => clearTimeout(timer);
  }, [alarmed, pressed]);

  // A key lights while the finger is on it.
  const [held, setHeld] = useState(false);
  useEffect(() => {
    if (pressed < 0) return;
    setHeld(true);
    const timer = setTimeout(() => setHeld(false), KEY_MS * 0.6);
    return () => clearTimeout(timer);
  }, [pressed]);

  const shownDisplay = keyed(display, pressed);
  const readingAlarm = pressed >= ALARM_KEYS.length - 1;

  const style = useAnimatedStyle(() => ({
    opacity: entrance.value,
    transform: [
      { translateY: interpolate(entrance.value, [0, 1], [18, 0]) },
      { scale: interpolate(entrance.value, [0, 1], [0.97, 1]) },
    ],
  }));

  return (
    <Animated.View style={[styles.card, style]}>
      <View style={styles.top}>
        <Lamps prog={alarmed} />
        <ElPanel display={shownDisplay} />
      </View>
      <Keypad pressed={held ? ALARM_KEYS[pressed] : undefined} />
      <Text style={styles.caption}>
        {readingAlarm
          ? `DSKY · V05 N09 · ALARM ${display.alarm} IN R1 AND R3`
          : `DSKY · P${display.prog.trim() || '--'} BRAKING PHASE · V${display.verb} N${display.noun}`}
      </Text>
    </Animated.View>
  );
}

const LAMPS: Array<[string, string]> = [
  ['UPLINK\nACTY', 'TEMP'],
  ['NO ATT', 'GIMBAL\nLOCK'],
  ['STBY', 'PROG'],
  ['KEY REL', 'RESTART'],
  ['OPR ERR', 'TRACKER'],
  ['', 'ALT'],
  ['', 'VEL'],
];

const Lamps = memo(function Lamps({ prog }: { prog: boolean }) {
  return (
    <View style={styles.lamps}>
      {LAMPS.map(([left, right]) => (
        <View key={right} style={styles.lampRow}>
          <Lamp label={left} />
          <Lamp label={right} lit={right === 'PROG' && prog} />
        </View>
      ))}
    </View>
  );
});

function Lamp({ label, lit = false }: { label: string; lit?: boolean }) {
  const glow = useSharedValue(0);
  useEffect(() => {
    glow.value = lit
      ? withSequence(
          withRepeat(
            withSequence(
              withTiming(1, { duration: 90 }),
              withDelay(160, withTiming(0.2, { duration: 90 }))
            ),
            3
          ),
          withTiming(1, { duration: 90 })
        )
      : withTiming(0, { duration: 200 });
  }, [glow, lit]);
  const style = useAnimatedStyle(() => ({
    backgroundColor: glow.value > 0.5 ? AMBER : AMBER_DIM,
    shadowOpacity: glow.value * 0.9,
  }));
  return (
    <Animated.View style={[styles.lamp, !label && styles.lampBlank, style]}>
      {label ? (
        <Text style={[styles.lampText, lit && styles.lampTextLit]}>
          {label}
        </Text>
      ) : null}
    </Animated.View>
  );
}

function ElPanel({ display }: { display: Display }) {
  return (
    <View style={styles.el}>
      <View style={styles.elTop}>
        <View style={styles.elCell}>
          <CompActy />
        </View>
        <View style={styles.elCell}>
          <Text style={styles.elLabel}>PROG</Text>
          <Segments text={display.prog} height={22} />
        </View>
      </View>
      <View style={styles.elTop}>
        <View style={styles.elCell}>
          <Text style={styles.elLabel}>VERB</Text>
          <Segments text={display.verb} height={22} />
        </View>
        <View style={styles.elCell}>
          <Text style={styles.elLabel}>NOUN</Text>
          <Segments text={display.noun} height={22} />
        </View>
      </View>
      {display.registers.map((value, i) => (
        <View key={i} style={styles.register}>
          <Segments text={value} height={22} sign />
        </View>
      ))}
    </View>
  );
}

// The computer's activity lamp, flickering as jobs run.
function CompActy() {
  const on = useSharedValue(0);
  useEffect(() => {
    on.value = withRepeat(
      withSequence(
        withTiming(1, { duration: 40 }),
        withDelay(110, withTiming(0, { duration: 30 })),
        withDelay(260, withTiming(1, { duration: 40 })),
        withDelay(60, withTiming(0, { duration: 30 })),
        withDelay(520, withTiming(1, { duration: 40 })),
        withDelay(220, withTiming(0, { duration: 30 }))
      ),
      -1
    );
  }, [on]);
  const style = useAnimatedStyle(() => ({ opacity: 0.12 + on.value * 0.88 }));
  return (
    <Animated.View style={[styles.compActy, style]}>
      <Text style={styles.compActyText}>{'COMP\nACTY'}</Text>
    </Animated.View>
  );
}

// prettier-ignore
const KEY_ROWS = [
  ['VERB', '+', '7', '8', '9', 'CLR', 'ENTR'],
  ['', '-', '4', '5', '6', 'PRO', ''],
  ['NOUN', '0', '1', '2', '3', 'KEY REL', 'RSET'],
];

const Keypad = memo(function Keypad({ pressed }: { pressed?: string }) {
  return (
    <View style={styles.keypad}>
      {KEY_ROWS.map((row, r) => (
        <View key={r} style={styles.keyRow}>
          {row.map((key, c) =>
            key ? (
              <View
                key={c}
                style={[styles.key, pressed === key && styles.keyPressed]}
              >
                <Text
                  style={[
                    styles.keyText,
                    key.length > 2 && styles.keyTextWord,
                    pressed === key && styles.keyTextPressed,
                  ]}
                  numberOfLines={1}
                  adjustsFontSizeToFit
                >
                  {key}
                </Text>
              </View>
            ) : (
              <View key={c} style={styles.keyGap} />
            )
          )}
        </View>
      ))}
    </View>
  );
});

const styles = StyleSheet.create({
  card: {
    backgroundColor: CONSOLE,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: CONSOLE_EDGE,
    padding: 10,
    gap: 10,
    shadowColor: '#000',
    shadowOpacity: 0.5,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
  },
  top: {
    flexDirection: 'row',
    gap: 10,
  },
  lamps: {
    flex: 0.9,
    backgroundColor: '#1D2026',
    borderRadius: 6,
    padding: 5,
    gap: 4,
  },
  lampRow: {
    flex: 1,
    flexDirection: 'row',
    gap: 4,
  },
  lamp: {
    flex: 1,
    minHeight: 24,
    borderRadius: 3,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: AMBER,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 0 },
  },
  lampBlank: {
    opacity: 0.5,
  },
  lampText: {
    fontFamily: FONTS.label,
    fontSize: 6.5,
    lineHeight: 8,
    letterSpacing: 0.4,
    textAlign: 'center',
    color: '#8A7F6C',
  },
  lampTextLit: {
    color: '#2A1A00',
  },
  el: {
    flex: 1.25,
    backgroundColor: '#0B0D0B',
    borderRadius: 6,
    paddingHorizontal: 8,
    paddingVertical: 6,
    gap: 4,
  },
  elTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  elCell: {
    alignItems: 'center',
    minWidth: 46,
  },
  elLabel: {
    fontFamily: FONTS.label,
    fontSize: 7,
    letterSpacing: 0.6,
    color: '#0B0D0B',
    backgroundColor: EL,
    paddingHorizontal: 4,
    borderRadius: 1,
    marginBottom: 3,
    overflow: 'hidden',
  },
  compActy: {
    width: 40,
    height: 34,
    borderRadius: 2,
    backgroundColor: EL,
    alignItems: 'center',
    justifyContent: 'center',
  },
  compActyText: {
    fontFamily: FONTS.label,
    fontSize: 7,
    lineHeight: 9,
    textAlign: 'center',
    color: '#0B0D0B',
  },
  register: {
    alignItems: 'flex-end',
    borderTopWidth: 1.5,
    borderTopColor: 'rgba(141, 255, 122, 0.35)',
    paddingTop: 4,
  },
  keypad: {
    gap: 5,
  },
  keyRow: {
    flexDirection: 'row',
    gap: 5,
  },
  key: {
    flex: 1,
    height: 28,
    borderRadius: 4,
    backgroundColor: '#1E2228',
    borderBottomWidth: 2,
    borderBottomColor: '#111317',
    alignItems: 'center',
    justifyContent: 'center',
  },
  keyPressed: {
    backgroundColor: '#3A414C',
    borderBottomWidth: 0,
    transform: [{ translateY: 1 }],
  },
  keyGap: {
    flex: 1,
  },
  keyText: {
    fontFamily: FONTS.heading,
    fontSize: 12,
    color: '#E6E2D8',
    paddingHorizontal: 2,
  },
  keyTextWord: {
    fontSize: 7.5,
    letterSpacing: 0.4,
  },
  keyTextPressed: {
    color: EL,
  },
  caption: {
    fontFamily: FONTS.mono,
    fontSize: 9,
    letterSpacing: 0.8,
    color: PAPER_SOFT,
  },
});
