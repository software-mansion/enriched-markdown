import { useEffect, useMemo, useState } from 'react';
import { StyleSheet, useWindowDimensions, View } from 'react-native';
import Animated, {
  interpolate,
  useAnimatedStyle,
} from 'react-native-reanimated';
import { useNavigation, type ParamListBase } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';
import type { Hinge } from '../../shared/hinge';
import {
  FlightJournal,
  FollowPill,
  Journal,
  Prompt,
  Starfield,
  useJournal,
} from '../FlightJournalScreen';
import { loopPlayer } from '../loops';
import { SPACE } from '../theme';
import { Console } from './Console';
import { Cover } from './Cover';

// Opening the Duo, the answer takes a moment, as if it were being radioed in.
const THINKING_MS = 1500;

// The iPhone Duo as the flight: folded it is the journal's cover, opened the
// journal runs down the left page and Mission Control follows on the right.
export function DuoJournal({ hinge }: { hinge: Hinge }) {
  const [readFolded, setReadFolded] = useState(false);
  useEffect(() => {
    if (!hinge.closed) setReadFolded(false);
  }, [hinge.closed]);

  // Folding the phone drops the loop, whatever was playing.
  useEffect(() => {
    if (hinge.closed) loopPlayer.stop();
  }, [hinge.closed]);

  // The cover and the pages run edge to edge, with no clock over them.
  const navigation = useNavigation<NativeStackNavigationProp<ParamListBase>>();
  useEffect(() => {
    navigation.setOptions({ statusBarHidden: true });
  }, [navigation]);

  if (!hinge.closed) return <Spread open={hinge.open} />;
  if (readFolded) return <FlightJournal />;
  return <Cover onRead={() => setReadFolded(true)} />;
}

function Spread({ open }: { open: Hinge['open'] }) {
  const insets = useSafeAreaInsets();
  const { width, height } = useWindowDimensions();
  const stream = useJournal(THINKING_MS);
  // Rotated a quarter turn the hinge runs across, and the pages stack.
  const across = width >= height;
  const contentStyle = useMemo(
    () => [
      styles.content,
      { paddingTop: insets.top + 20, paddingBottom: insets.bottom + 90 },
    ],
    [insets.top, insets.bottom]
  );

  return (
    <View style={[styles.root, !across && styles.stacked]}>
      <View style={[styles.page, across && { paddingLeft: insets.left }]}>
        <Starfield />
        <Animated.ScrollView
          {...stream.scrollProps}
          contentContainerStyle={contentStyle}
        >
          <Prompt />
          <Journal stream={stream} />
        </Animated.ScrollView>
        <View
          style={[styles.follow, { bottom: insets.bottom + 16 }]}
          pointerEvents="box-none"
        >
          {stream.streaming && stream.detached && (
            <FollowPill onFollow={stream.follow} />
          )}
        </View>
      </View>
      <Crease open={open} across={across} />
      <View style={[styles.page, across && { paddingRight: insets.right }]}>
        <Console
          top={across ? insets.top : 0}
          bottom={insets.bottom}
          markdown={stream.markdown}
          streaming={stream.streaming}
          onReplay={stream.replay}
        />
      </View>
    </View>
  );
}

// The fold between the pages, deepest while the phone is half open.
function Crease({ open, across }: { open: Hinge['open']; across: boolean }) {
  const style = useAnimatedStyle(() => ({
    opacity: interpolate(open.value, [0.3, 1], [1, 0.45], 'clamp'),
  }));
  return (
    <Animated.View
      pointerEvents="none"
      style={[across ? styles.creaseAcross : styles.creaseDown, style]}
    >
      <Svg width="100%" height="100%">
        <Defs>
          <LinearGradient
            id="crease"
            x1="0"
            y1="0"
            x2={across ? '1' : '0'}
            y2={across ? '0' : '1'}
          >
            <Stop offset="0" stopColor="#000" stopOpacity={0} />
            <Stop offset="0.5" stopColor="#000" stopOpacity={0.75} />
            <Stop offset="1" stopColor="#000" stopOpacity={0} />
          </LinearGradient>
        </Defs>
        <Rect width="100%" height="100%" fill="url(#crease)" />
      </Svg>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    flexDirection: 'row',
    backgroundColor: SPACE,
  },
  stacked: {
    flexDirection: 'column',
  },
  page: {
    flex: 1,
    overflow: 'hidden',
  },
  content: {
    paddingHorizontal: 22,
  },
  follow: {
    position: 'absolute',
    left: 0,
    right: 0,
    alignItems: 'center',
  },
  creaseAcross: {
    width: 36,
    marginHorizontal: -18,
    zIndex: 2,
  },
  creaseDown: {
    height: 36,
    marginVertical: -18,
    zIndex: 2,
  },
});
