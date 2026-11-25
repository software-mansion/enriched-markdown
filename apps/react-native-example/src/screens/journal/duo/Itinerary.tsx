import { memo, useEffect, useRef, type ComponentRef } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  interpolate,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';
import { latestBlock, tapeLines, type TapeLine } from '../../shared/tapeLines';
import { rendererFor } from '../renderers';
import { FONTS, INK, INK_SOFT, PAPER, VERMILION, accentFor } from '../theme';

const DAYS = [
  { day: 1, kanji: '一' },
  { day: 2, kanji: '二' },
  { day: 3, kanji: '三' },
];

// The right page: the trip's three days, stamped as the answer reaches each
// one, over the markdown the answer is made of.
export function Itinerary({
  top,
  bottom,
  markdown,
  streaming,
  onReplay,
}: {
  top: number;
  bottom: number;
  markdown: string;
  streaming: boolean;
  onReplay: () => void;
}) {
  const titles = DAYS.map(
    ({ day }) =>
      markdown.match(new RegExp(`^## Day ${day} · (.*)$`, 'm'))?.[1] ?? null
  );
  const today = titles.reduce(
    (latest, title, i) => (title !== null ? i : latest),
    -1
  );
  return (
    <View
      style={[
        styles.root,
        { paddingTop: top + 14, paddingBottom: bottom + 14 },
      ]}
    >
      <View style={styles.head}>
        <Text style={styles.desk}>旅のしおり · TRAVEL DESK</Text>
        <Pressable
          onPress={onReplay}
          hitSlop={12}
          accessibilityRole="button"
          accessibilityLabel="Replay the answer"
        >
          <Text style={styles.replay}>↻</Text>
        </Pressable>
      </View>
      <View style={styles.days}>
        {DAYS.map(({ day, kanji }, i) => (
          <Stamp
            key={day}
            day={day}
            kanji={kanji}
            title={titles[i] ?? null}
            today={i === today}
          />
        ))}
      </View>
      <Text style={styles.tapeLabel}>THE ANSWER AS WRITTEN</Text>
      <Source markdown={markdown} streaming={streaming} />
    </View>
  );
}

const THUMP = Easing.out(Easing.back(1.8));

// A day's hanko: a dashed outline until the answer gets there, then pressed
// in, solid while it is the day being written.
const Stamp = memo(function Stamp({
  day,
  kanji,
  title,
  today,
}: {
  day: number;
  kanji: string;
  title: string | null;
  today: boolean;
}) {
  const reached = title !== null;
  const pressed = useSharedValue(reached ? 1 : 0);
  useEffect(() => {
    pressed.value = withTiming(reached ? 1 : 0, {
      duration: reached ? 420 : 0,
      easing: THUMP,
    });
  }, [pressed, reached]);
  const style = useAnimatedStyle(() => ({
    opacity: interpolate(pressed.value, [0, 0.4, 1], [0, 1, 1]),
    transform: [
      { scale: interpolate(pressed.value, [0, 1], [1.7, 1]) },
      { rotate: `${(day - 2) * 3}deg` },
    ],
  }));
  return (
    <View style={styles.day}>
      <View style={styles.outline}>
        <Text style={styles.ghost}>{kanji}</Text>
      </View>
      <Animated.View style={[styles.seal, today && styles.sealToday, style]}>
        <Text style={[styles.sealKanji, today && styles.sealKanjiToday]}>
          {kanji}
        </Text>
      </Animated.View>
      <Text style={styles.dayLabel}>{`DAY ${day}`}</Text>
      <Text style={styles.dayTitle} numberOfLines={2}>
        {title ?? ' '}
      </Text>
    </View>
  );
});

// The answer line by line, dimmed, each block that becomes a component
// marked in that component's colour, and the latest one lit.
function Source({
  markdown,
  streaming,
}: {
  markdown: string;
  streaming: boolean;
}) {
  const scroll = useRef<ComponentRef<typeof ScrollView>>(null);
  const lines = tapeLines(markdown, rendererFor);
  const latest = latestBlock(lines);
  return (
    <ScrollView
      ref={scroll}
      style={styles.tape}
      contentContainerStyle={styles.tapeContent}
      onContentSizeChange={() => scroll.current?.scrollToEnd()}
    >
      {lines.map((line, i) => (
        <SourceLine
          key={i}
          line={line}
          active={line.renderer !== null && line.block === latest}
          caret={streaming && i === lines.length - 1}
        />
      ))}
    </ScrollView>
  );
}

const SourceLine = memo(function SourceLine({
  line,
  active,
  caret,
}: {
  line: TapeLine;
  active: boolean;
  caret: boolean;
}) {
  const { renderer } = line;
  const accent = renderer ? accentFor(renderer) : null;
  const heading = line.text.match(/^(#{1,6} )(.*)$/);
  return (
    <View
      style={[
        styles.line,
        accent && { borderLeftColor: active ? accent : `${accent}55` },
        accent && active && { backgroundColor: `${accent}14` },
      ]}
    >
      <Text style={styles.number}>{line.number}</Text>
      <View style={styles.body}>
        <Text style={[styles.text, active && styles.textActive]}>
          {heading ? (
            <>
              <Text style={styles.marker}>{heading[1]}</Text>
              <Text style={styles.heading}>{heading[2]}</Text>
            </>
          ) : (
            line.text
          )}
          {caret && <Text style={styles.caret}>▍</Text>}
        </Text>
        {line.opens && accent && (
          <Text
            style={[styles.tag, { color: accent }, !active && styles.tagIdle]}
          >
            {`→ <${renderer} />`}
          </Text>
        )}
      </View>
    </View>
  );
});

const SEAL = 46;

const styles = StyleSheet.create({
  root: {
    flex: 1,
    paddingHorizontal: 18,
    gap: 14,
    backgroundColor: '#EFE6D5',
  },
  head: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  desk: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 1.6,
    color: INK_SOFT,
  },
  replay: {
    fontFamily: FONTS.monoMedium,
    fontSize: 20,
    color: VERMILION,
  },
  days: {
    flexDirection: 'row',
    gap: 10,
  },
  day: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 6,
    borderRadius: 12,
    backgroundColor: '#FBF6EC',
    borderWidth: 1,
    borderColor: '#E3D6BF',
  },
  outline: {
    width: SEAL,
    height: SEAL,
    borderRadius: 8,
    borderWidth: 1.5,
    borderStyle: 'dashed',
    borderColor: '#CDBEA4',
    alignItems: 'center',
    justifyContent: 'center',
  },
  ghost: {
    fontFamily: FONTS.mincho,
    fontSize: 22,
    color: '#D6C9B2',
  },
  seal: {
    position: 'absolute',
    top: 12,
    width: SEAL,
    height: SEAL,
    borderRadius: 8,
    borderWidth: 2.5,
    borderColor: VERMILION,
    backgroundColor: '#FBF6EC',
    alignItems: 'center',
    justifyContent: 'center',
  },
  sealToday: {
    backgroundColor: VERMILION,
  },
  sealKanji: {
    fontFamily: FONTS.mincho,
    fontSize: 24,
    fontWeight: '700',
    color: VERMILION,
  },
  sealKanjiToday: {
    color: PAPER,
  },
  dayLabel: {
    marginTop: 8,
    fontFamily: FONTS.monoMedium,
    fontSize: 9,
    letterSpacing: 1.4,
    color: INK_SOFT,
  },
  dayTitle: {
    marginTop: 2,
    fontFamily: FONTS.hand,
    fontSize: 18,
    lineHeight: 19,
    color: INK,
    textAlign: 'center',
    minHeight: 38,
  },
  tapeLabel: {
    fontFamily: FONTS.monoMedium,
    fontSize: 9,
    letterSpacing: 1.6,
    color: INK_SOFT,
    marginBottom: -6,
  },
  tape: {
    flex: 1,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E3D6BF',
    backgroundColor: '#FBF6EC',
  },
  tapeContent: {
    paddingVertical: 10,
    paddingRight: 10,
  },
  line: {
    flexDirection: 'row',
    borderLeftWidth: 2,
    borderLeftColor: 'transparent',
    borderTopRightRadius: 4,
    borderBottomRightRadius: 4,
  },
  number: {
    width: 28,
    textAlign: 'right',
    marginRight: 10,
    fontFamily: FONTS.mono,
    fontSize: 9.5,
    lineHeight: 16,
    color: '#C3B49C',
  },
  body: {
    flex: 1,
  },
  text: {
    fontFamily: FONTS.mono,
    fontSize: 10.5,
    lineHeight: 16,
    color: '#8F806F',
  },
  textActive: {
    color: INK,
  },
  marker: {
    color: '#C3B49C',
  },
  heading: {
    fontFamily: FONTS.monoMedium,
    color: VERMILION,
  },
  caret: {
    color: VERMILION,
  },
  tag: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10.5,
    lineHeight: 16,
  },
  tagIdle: {
    opacity: 0.6,
  },
});
