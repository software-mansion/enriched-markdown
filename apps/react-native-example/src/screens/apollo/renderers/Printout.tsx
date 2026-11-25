import { memo, useEffect, useMemo } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  interpolate,
  useAnimatedProps,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withTiming,
} from 'react-native-reanimated';
import Svg, { Circle, Path } from 'react-native-svg';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import { FONTS } from '../theme';
import { SETTLE, codeLines, useEntrance } from './motion';

const AnimatedPath = Animated.createAnimatedComponent(Path);

const PAPER = '#F1EFE4';
const BAR = '#D7E6CF';
const INK = '#2B2E33';
const FAINT = '#8B9187';
const PEN = '#C8312A';
const LINE_HEIGHT = 19;
// Green bars are three lines deep, as on the fan-fold paper of the listings.
const BAR_LINES = 3;
const HOLES = 7;

interface Statement {
  label: string;
  op: string;
  operand: string;
  comment: string;
}

// `LABEL  OP  OPERAND  # COMMENT`; a line starting with spaces has no label.
function statement(line: string): Statement {
  const hash = line.indexOf('#');
  const code = hash === -1 ? line : line.slice(0, hash);
  const comment = hash === -1 ? '' : line.slice(hash);
  const fields = code.trim().split(/\s+/);
  const label = /^\S/.test(code) ? (fields.shift() ?? '') : '';
  return {
    label,
    op: fields[0] ?? '',
    operand: fields.slice(1).join(' '),
    comment,
  };
}

// A ```agc block as a page of the program listing, the lines striking in as
// they stream. Once the block is complete, someone circles the alarm code.
export function Printout({ block }: { block: MarkdownCodeBlock }) {
  const statements = useMemo(
    () => codeLines(block.code).map(statement),
    [block.code]
  );
  const entrance = useEntrance(600);
  const style = useAnimatedStyle(() => ({
    opacity: entrance.value,
    transform: [{ translateY: interpolate(entrance.value, [0, 1], [-14, 0]) }],
  }));
  const bars = Math.ceil((statements.length + 2) / (BAR_LINES * 2));

  return (
    <Animated.View style={[styles.paper, style]}>
      <Feed side="left" />
      <View style={styles.body}>
        <View style={StyleSheet.absoluteFill} pointerEvents="none">
          {Array.from({ length: bars }, (_, i) => (
            <View
              key={i}
              style={[
                styles.bar,
                { top: (i * 2 + 1) * BAR_LINES * LINE_HEIGHT + 8 },
              ]}
            />
          ))}
        </View>
        <Text style={styles.header} numberOfLines={1}>
          LUMINARY 099 · EXECUTIVE · PAGE 1107
        </Text>
        {statements.map((s, i) => (
          <Row
            key={i}
            statement={s}
            circled={block.isComplete && /^\d{4}$/.test(s.operand)}
          />
        ))}
        <Text style={styles.footer}>MIT INSTRUMENTATION LAB · LMY99 REV 1</Text>
      </View>
      <Feed side="right" />
    </Animated.View>
  );
}

const Row = memo(function Row({
  statement: { label, op, operand, comment },
  circled,
}: {
  statement: Statement;
  circled: boolean;
}) {
  const strike = useSharedValue(0);
  useEffect(() => {
    strike.value = withTiming(1, { duration: 220, easing: SETTLE });
  }, [strike]);
  const style = useAnimatedStyle(() => ({
    opacity: strike.value,
    transform: [{ translateX: interpolate(strike.value, [0, 1], [-6, 0]) }],
  }));
  return (
    <Animated.View style={[styles.row, style]}>
      <Text style={[styles.cell, styles.label]}>{label}</Text>
      <Text style={[styles.cell, styles.op]}>{op}</Text>
      <View style={styles.operandCell}>
        <Text style={styles.cell}>{operand}</Text>
        {circled && <PenCircle />}
      </View>
      <Text style={[styles.cell, styles.comment]}>
        {comment}
        {circled && <Text style={styles.note}>{'  ← the 1202'}</Text>}
      </Text>
    </Animated.View>
  );
});

// A loose ink loop, drawn in one stroke.
const LOOP =
  'M 6 15 C 2 6, 22 1, 40 3 C 56 5, 60 18, 46 23 C 32 28, 8 26, 4 18 C 2 12, 14 6, 26 6';
const LOOP_LENGTH = 170;

function PenCircle() {
  const drawn = useSharedValue(0);
  useEffect(() => {
    drawn.value = withDelay(350, withTiming(1, { duration: 650 }));
  }, [drawn]);
  const props = useAnimatedProps(() => ({
    strokeDashoffset: LOOP_LENGTH * (1 - drawn.value),
  }));
  return (
    <Svg style={styles.pen} viewBox="0 0 62 30" pointerEvents="none">
      <AnimatedPath
        d={LOOP}
        stroke={PEN}
        strokeWidth={1.8}
        strokeLinecap="round"
        fill="none"
        strokeDasharray={LOOP_LENGTH}
        animatedProps={props}
      />
    </Svg>
  );
}

function Feed({ side }: { side: 'left' | 'right' }) {
  return (
    <View
      style={[
        styles.feed,
        side === 'left' ? styles.feedLeft : styles.feedRight,
      ]}
    >
      <Svg width={12} height="100%" preserveAspectRatio="none">
        {Array.from({ length: HOLES }, (_, i) => (
          <Circle
            key={i}
            cx={6}
            cy={`${((i + 0.5) / HOLES) * 100}%`}
            r={3}
            fill="#C9C5B6"
          />
        ))}
      </Svg>
    </View>
  );
}

const styles = StyleSheet.create({
  paper: {
    flexDirection: 'row',
    backgroundColor: PAPER,
    borderRadius: 3,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOpacity: 0.4,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
  },
  feed: {
    width: 16,
    alignItems: 'center',
    paddingVertical: 8,
    borderColor: '#D8D4C4',
  },
  feedLeft: {
    borderRightWidth: StyleSheet.hairlineWidth,
  },
  feedRight: {
    borderLeftWidth: StyleSheet.hairlineWidth,
  },
  body: {
    flex: 1,
    paddingHorizontal: 8,
    paddingVertical: 8,
  },
  bar: {
    position: 'absolute',
    left: 0,
    right: 0,
    height: BAR_LINES * LINE_HEIGHT,
    backgroundColor: BAR,
  },
  header: {
    fontFamily: FONTS.typewriter,
    fontSize: 10,
    lineHeight: LINE_HEIGHT,
    letterSpacing: 0.4,
    color: FAINT,
  },
  footer: {
    fontFamily: FONTS.typewriter,
    fontSize: 9,
    lineHeight: LINE_HEIGHT,
    color: FAINT,
    textAlign: 'right',
  },
  row: {
    flexDirection: 'row',
    minHeight: LINE_HEIGHT,
  },
  cell: {
    fontFamily: FONTS.typewriter,
    fontSize: 11,
    lineHeight: LINE_HEIGHT,
    color: INK,
  },
  label: {
    width: 66,
  },
  op: {
    width: 38,
  },
  operandCell: {
    width: 70,
  },
  comment: {
    flex: 1,
    color: '#5A6157',
  },
  note: {
    fontFamily: FONTS.handBold,
    fontSize: 17,
    color: PEN,
  },
  pen: {
    position: 'absolute',
    left: -9,
    top: -4,
    width: 54,
    height: 27,
  },
});
