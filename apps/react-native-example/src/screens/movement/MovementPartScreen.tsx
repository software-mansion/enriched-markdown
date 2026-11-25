import { useCallback, useEffect, useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import Animated, {
  SharedTransitionBoundary,
  runOnJS,
  useAnimatedStyle,
  Easing,
  useSharedValue,
  withDelay,
  withTiming,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useIsFocused } from '@react-navigation/native';
import Svg, { Path } from 'react-native-svg';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type { RootStackScreenProps } from '../../navigation/types';
import { PART_NOTES, isPartId, specsOf } from './movementMarkdown';
import { ALONE_MS, HeroPlate, homeIn, leaving } from './Plate';
import {
  BLUED,
  BLUED_DEEP,
  CREAM,
  FONTS,
  INK,
  INK_SOFT,
  IVORY,
  NIGHT,
  RULE,
  TILE_EDGE,
  partMarkdownStyle,
} from './theme';

// A part on its own screen. The screen's boundary follows the navigator's
// focus, so the plate tapped on the page or on the board grows into this
// header, and a back swipe carries it home under the finger.
export default function MovementPartScreen({
  route,
  navigation,
}: RootStackScreenProps<'MovementPart'>) {
  const focused = useIsFocused();
  const insets = useSafeAreaInsets();
  const { part, night } = route.params;
  // The notes ride the same clock as the plate: nothing waits for it to land.
  // The title fades first, then the screen goes: see `HeroPlate`.
  const closing = useSharedValue(0);
  const goBack = useCallback(() => {
    closing.value = withTiming(1, { duration: 80 });
    // The card's text fades in as the plate lands, on its own clock: the
    // navigator is done long before the flight is.
    homeIn.value = 0;
    homeIn.value = withDelay(
      ALONE_MS + 90,
      withTiming(1, { duration: 300, easing: Easing.out(Easing.quad) })
    );
    leaving.value = withTiming(1, { duration: 70 }, () => {
      runOnJS(navigation.goBack)();
    });
  }, [navigation, closing]);
  const specs = useMemo(() => (isPartId(part) ? specsOf(part) : []), [part]);
  // The notes and the back button come in as the plate lands, on a clock of
  // their own: the screen's own fade ends long before the flight does. Coming
  // home they are gone in the first moments.
  const arrive = useSharedValue(0);
  useEffect(() => {
    arrive.value = withDelay(
      Math.round(ALONE_MS * 0.65),
      withTiming(1, { duration: Math.round(ALONE_MS * 0.35) })
    );
  }, [arrive]);
  const notes = useAnimatedStyle(() => {
    const shown = arrive.value * (1 - closing.value);
    return {
      opacity: shown,
      transform: [{ translateY: 14 * (1 - shown) }],
    };
  });
  const back = useAnimatedStyle(() => ({
    opacity: arrive.value * (1 - closing.value),
  }));
  if (!isPartId(part)) return <View style={styles.root} />;

  return (
    <View style={[styles.root, night && styles.night]}>
      <SharedTransitionBoundary isActive={focused}>
        <ScrollView
          bounces={false}
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{ paddingBottom: insets.bottom + 40 }}
        >
          <View collapsable={false}>
            <HeroPlate id={part} from={night ? 'board' : 'page'} />
          </View>
          <Animated.View style={[styles.notes, notes]}>
            <View style={styles.table}>
              {specs.map((spec) => (
                <View
                  key={spec.key}
                  style={[styles.row, night && styles.rowNight]}
                >
                  <Text style={styles.rowKey}>{spec.key.toUpperCase()}</Text>
                  <Text style={[styles.rowValue, night && styles.valueNight]}>
                    {spec.value}
                  </Text>
                </View>
              ))}
            </View>
            <View style={styles.kickerRow}>
              <Text style={[styles.kicker, night && styles.kickerNight]}>
                BENCH NOTE
              </Text>
              <View style={styles.kickerRule} />
            </View>
            <EnrichedMarkdownText
              flavor="github"
              markdown={PART_NOTES[part]}
              markdownStyle={partMarkdownStyle[night ? 'night' : 'ivory']}
            />
          </Animated.View>
        </ScrollView>
        <Animated.View style={[styles.back, { top: insets.top + 4 }, back]}>
          <Pressable
            onPress={goBack}
            hitSlop={14}
            accessibilityRole="button"
            accessibilityLabel="Back"
            testID="movement-part-back"
            style={styles.backButton}
          >
            <Svg width={18} height={18} viewBox="0 0 18 18">
              <Path
                d="M11 3 L5 9 L11 15"
                fill="none"
                stroke={CREAM}
                strokeWidth={1.8}
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </Svg>
          </Pressable>
        </Animated.View>
      </SharedTransitionBoundary>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: IVORY },
  night: { backgroundColor: NIGHT },
  kickerNight: { color: BLUED },
  notes: { paddingHorizontal: 26, paddingTop: 14 },
  table: { marginBottom: 26 },
  row: {
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'space-between',
    paddingVertical: 11,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: RULE,
  },
  rowNight: { borderBottomColor: TILE_EDGE },
  rowKey: {
    fontFamily: FONTS.mono,
    fontSize: 10.5,
    letterSpacing: 1.6,
    color: INK_SOFT,
  },
  rowValue: { fontFamily: FONTS.monoMedium, fontSize: 15, color: INK },
  valueNight: { color: CREAM },
  kickerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 14,
  },
  kicker: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
    letterSpacing: 1.6,
    color: BLUED_DEEP,
  },
  kickerRule: {
    flex: 1,
    height: StyleSheet.hairlineWidth,
    backgroundColor: INK_SOFT,
  },
  back: { position: 'absolute', left: 16 },
  backButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(239, 234, 223, 0.1)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(239, 234, 223, 0.35)',
  },
});
