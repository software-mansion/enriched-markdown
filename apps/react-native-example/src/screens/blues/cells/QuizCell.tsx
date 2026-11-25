import { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  FadeInDown,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withSpring,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import { engine } from '../audio';
import { loudness, useScopeFeed } from '../Scope';
import { parseGroups } from './KeysCell';
import { Card, splitCode, useOnClose } from './Card';
import {
  BRASS,
  CREAM,
  FONTS,
  GREEN,
  MIDNIGHT,
  RED,
  RULE,
  SOFT,
  glow,
} from '../theme';

interface Question {
  play: number[][];
  options: { text: string; right: boolean }[];
}

// `play C4+E4+G4` (or `play C4 E4` for two notes in turn), then the choices
// as task items, the right one ticked.
function parseQuiz(lines: string[]): Question {
  const question: Question = { play: [], options: [] };
  for (const line of lines) {
    const play = /^\s*play\s+(.*)$/.exec(line);
    if (play) {
      question.play = parseGroups(play[1]!.split(/\s+/));
      continue;
    }
    const option = /^\s*\[( |x)\]\s+(.+)$/.exec(line);
    if (option) {
      question.options.push({ text: option[2]!, right: option[1] === 'x' });
    }
  }
  return question;
}

const LISTEN = 84;
const RINGS = [0, 1, 2];

/**
 * A ```quiz block: ear training. A glowing button plays the sound, its rings
 * breathing with it; a right pick springs green, a wrong one shakes red and
 * lights the right one.
 */
export function QuizCell({ block }: { block: MarkdownCodeBlock }) {
  const { caption, body } = splitCode(block.code);
  const quiz = parseQuiz(body);
  const [picked, setPicked] = useState<number | null>(null);
  const wave = useSharedValue(0);
  useScopeFeed();

  const listen = () => {
    if (quiz.play.length === 0) return;
    const start = engine.now();
    quiz.play.forEach((group, i) =>
      group.forEach((midi, j) =>
        engine.piano(midi, start + i * 0.55 + j * 0.015, 1.6, 0.85)
      )
    );
    wave.value = 0;
    wave.value = withRepeat(
      withTiming(1, { duration: 1400, easing: Easing.linear }),
      2,
      false
    );
  };

  useOnClose(block, () => setTimeout(listen, 350));

  const core = useAnimatedStyle(() => ({
    transform: [{ scale: 1 + loudness.value * 0.12 }],
    boxShadow: `0 0 ${18 + loudness.value * 40}px ${BRASS}${loudness.value > 0.05 ? 'CC' : '66'}`,
  }));

  const verdict = picked === null ? null : quiz.options[picked]?.right;

  return (
    <Card tag="EAR TRAINING" caption={caption}>
      <View style={styles.row}>
        <Pressable onPress={listen} testID="quiz-listen" hitSlop={8}>
          <View style={styles.listenWrap}>
            {RINGS.map((i) => (
              <Ring key={i} index={i} wave={wave} />
            ))}
            <Animated.View style={[styles.listen, core]}>
              <Text style={styles.listenIcon}>♪</Text>
            </Animated.View>
          </View>
        </Pressable>
        <View style={styles.side}>
          <Text style={styles.prompt}>
            {picked === null
              ? 'Listen, then choose'
              : verdict
                ? 'Correct'
                : 'Listen again'}
          </Text>
          <Text style={styles.hint}>tap ♪ to hear it as often as you like</Text>
        </View>
      </View>
      <View style={styles.options}>
        {quiz.options.map((option, i) => (
          <Option
            key={i}
            letter={String.fromCharCode(65 + i)}
            text={option.text}
            state={
              picked === null
                ? 'open'
                : i === picked
                  ? option.right
                    ? 'right'
                    : 'wrong'
                  : option.right
                    ? 'reveal'
                    : 'idle'
            }
            onPress={() => {
              setPicked(i);
              const tones = option.right ? [72, 76, 79, 84] : [61, 60];
              const t = engine.now();
              tones.forEach((m, k) => engine.piano(m, t + k * 0.08, 0.5, 0.55));
            }}
          />
        ))}
      </View>
      {picked !== null && (
        <Animated.Text
          entering={FadeInDown.duration(260)}
          style={[styles.verdict, { color: verdict ? GREEN : RED }]}
        >
          {verdict
            ? 'Your ear already knows: major sounds bright.'
            : 'Not quite. The right one is lit; tap ♪ and hear it again.'}
        </Animated.Text>
      )}
    </Card>
  );
}

// Sound rings rolling out of the button, a third of a cycle apart.
function Ring({ index, wave }: { index: number; wave: SharedValue<number> }) {
  const style = useAnimatedStyle(() => {
    const t = (wave.value + index / RINGS.length) % 1;
    const on = wave.value > 0 && wave.value < 1 ? 1 : 0;
    return {
      opacity: on * (1 - t) * 0.8,
      transform: [{ scale: 1 + t * 0.9 }],
    };
  });
  return <Animated.View pointerEvents="none" style={[styles.ring, style]} />;
}

type OptionState = 'open' | 'right' | 'wrong' | 'reveal' | 'idle';

function Option({
  letter,
  text,
  state,
  onPress,
}: {
  letter: string;
  text: string;
  state: OptionState;
  onPress: () => void;
}) {
  const scale = useSharedValue(1);
  const shake = useSharedValue(0);

  useEffect(() => {
    if (state === 'right') {
      scale.value = withSequence(
        withSpring(1.05, { damping: 6, stiffness: 300 }),
        withSpring(1)
      );
    }
    if (state === 'wrong') {
      shake.value = withSequence(
        withTiming(-8, { duration: 50 }),
        withRepeat(withTiming(8, { duration: 80 }), 4, true),
        withTiming(0, { duration: 50 })
      );
    }
  }, [state, scale, shake]);

  const animated = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }, { translateX: shake.value }],
  }));

  const color =
    state === 'right' || state === 'reveal'
      ? GREEN
      : state === 'wrong'
        ? RED
        : null;

  return (
    <Animated.View entering={FadeInDown.duration(240)}>
      <Animated.View style={animated}>
        <Pressable
          onPress={onPress}
          disabled={state !== 'open'}
          style={({ pressed }) => [
            styles.option,
            color && {
              borderColor: color,
              backgroundColor: color + '1F',
              boxShadow: glow(color, 14, '55'),
            },
            state === 'idle' && styles.idle,
            pressed && styles.optionPressed,
          ]}
        >
          <View
            style={[
              styles.letter,
              color && { backgroundColor: color, borderColor: color },
            ]}
          >
            <Text style={[styles.letterText, color && { color: MIDNIGHT }]}>
              {state === 'right' || state === 'reveal'
                ? '✓'
                : state === 'wrong'
                  ? '✕'
                  : letter}
            </Text>
          </View>
          <Text style={styles.optionText}>{text}</Text>
        </Pressable>
      </Animated.View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 18,
  },
  listenWrap: {
    width: LISTEN + 24,
    height: LISTEN + 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ring: {
    position: 'absolute',
    width: LISTEN,
    height: LISTEN,
    borderRadius: LISTEN / 2,
    borderWidth: 1.5,
    borderColor: BRASS,
  },
  listen: {
    width: LISTEN,
    height: LISTEN,
    borderRadius: LISTEN / 2,
    backgroundImage:
      'radial-gradient(circle at 35% 30%, #FFE3A8 0%, #FFB547 45%, #C9761C 100%)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  listenIcon: {
    fontSize: 34,
    color: '#3A2208',
  },
  side: {
    flex: 1,
    gap: 4,
  },
  prompt: {
    fontFamily: FONTS.display,
    fontSize: 22,
    color: CREAM,
  },
  hint: {
    fontFamily: FONTS.mono,
    fontSize: 11,
    lineHeight: 15,
    color: SOFT,
  },
  options: {
    gap: 10,
  },
  option: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    borderWidth: 1,
    borderColor: RULE,
    backgroundColor: '#0C1020',
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 12,
  },
  optionPressed: {
    backgroundColor: '#161C33',
  },
  idle: {
    opacity: 0.4,
  },
  letter: {
    width: 30,
    height: 30,
    borderRadius: 15,
    borderWidth: 1,
    borderColor: '#3A4366',
    alignItems: 'center',
    justifyContent: 'center',
  },
  letterText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 13,
    color: SOFT,
  },
  optionText: {
    flex: 1,
    fontFamily: FONTS.serif,
    fontSize: 18,
    color: CREAM,
  },
  verdict: {
    fontFamily: FONTS.italic,
    fontStyle: 'italic',
    fontSize: 17,
    lineHeight: 23,
  },
});
