import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import Animated, {
  interpolate,
  useAnimatedStyle,
} from 'react-native-reanimated';
import { useNavigation, type ParamListBase } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';
import type { MarkdownRenderers } from 'react-native-enriched-markdown';
import type { Hinge } from '../../shared/hinge';
import { useFollow } from '../../shared/useDemoStream';
import {
  DotGrid,
  FollowPill,
  Journal,
  KyotoJournal,
  Prompt,
  useJournal,
} from '../JournalScreen';
import { JOURNAL_MARKDOWN } from '../journalMarkdown';
import { FONTS, INK_SOFT, PAPER, VERMILION } from '../theme';
import { SourceSwitch, sourceRenderers } from '../source/SourceSwitch';
import { Cover } from './Cover';

// Opening the Duo, the answer takes a moment, as if it were being written.
const THINKING_MS = 1500;

// Where the answer turns over to the right page: the start of Day 3.
const TURN = JOURNAL_MARKDOWN.indexOf('\n## Day 3');

// The iPhone Duo as a travel notebook: folded it is the cover, opened the
// answer is written across the spread, the left page first.
export function DuoJournal({ hinge }: { hinge: Hinge }) {
  const [readFolded, setReadFolded] = useState(false);
  useEffect(() => {
    if (!hinge.closed) setReadFolded(false);
  }, [hinge.closed]);

  // The cover and the pages run edge to edge, with no clock over them.
  const navigation = useNavigation<NativeStackNavigationProp<ParamListBase>>();
  useEffect(() => {
    navigation.setOptions({ statusBarHidden: true });
  }, [navigation]);

  if (!hinge.closed) {
    return (
      <SourceSwitch>
        <Spread open={hinge.open} renderers={sourceRenderers} />
      </SourceSwitch>
    );
  }
  if (readFolded) {
    return (
      <SourceSwitch>
        <KyotoJournal renderers={sourceRenderers} />
      </SourceSwitch>
    );
  }
  return <Cover onRead={() => setReadFolded(true)} />;
}

export function Spread({
  open,
  renderers,
  written = false,
}: {
  open: Hinge['open'];
  renderers?: MarkdownRenderers;
  // The whole answer at once, both pages from the top, instead of a stream.
  written?: boolean;
}) {
  const insets = useSafeAreaInsets();
  const { width, height } = useWindowDimensions();
  const stream = useJournal(THINKING_MS, written);
  const left = useFollow(!written);
  const { reset: resetLeft } = left;
  const { replay: replayStream } = stream;
  const replay = useCallback(() => {
    resetLeft();
    replayStream();
  }, [resetLeft, replayStream]);

  const turned = stream.markdown.length > TURN;
  const leftMarkdown = turned
    ? JOURNAL_MARKDOWN.slice(0, TURN)
    : stream.markdown;
  const rightMarkdown = turned ? stream.markdown.slice(TURN + 1) : '';

  // Rotated a quarter turn the hinge runs across, and the pages stack.
  const across = width >= height;
  // Each page is exactly half the screen, so the crease sits on the hinge
  // whatever the pages hold.
  const half = across ? { width: width / 2 } : { height: height / 2 };
  const contentStyle = useMemo(
    () => [styles.content, { paddingBottom: insets.bottom + 70 }],
    [insets.bottom]
  );

  return (
    <View style={[styles.root, !across && styles.stacked]}>
      <Page
        size={half}
        side="left"
        top={insets.top}
        bottom={insets.bottom}
        inset={across ? insets.left : 0}
        head="Three slow days in Kyoto"
        number={1}
        onReplay={replay}
      >
        <Animated.ScrollView
          {...left.scrollProps}
          contentContainerStyle={contentStyle}
        >
          <Prompt />
          <Journal
            markdown={leftMarkdown}
            run={stream.run}
            streaming={stream.streaming && !turned}
            signed={false}
            renderers={renderers}
          />
        </Animated.ScrollView>
        <View
          style={[styles.follow, { bottom: insets.bottom + 34 }]}
          pointerEvents="box-none"
        >
          {stream.streaming && !turned && left.detached && (
            <FollowPill onFollow={left.follow} />
          )}
        </View>
      </Page>
      <Crease open={open} across={across} />
      <Page
        size={half}
        side="right"
        top={across ? insets.top : 0}
        bottom={insets.bottom}
        inset={across ? insets.right : 0}
        head="Kyoto Journal · autumn"
        number={2}
      >
        <Animated.ScrollView
          {...stream.scrollProps}
          contentContainerStyle={contentStyle}
        >
          {turned && (
            <Journal
              markdown={rightMarkdown}
              run={stream.run}
              streaming={stream.streaming}
              signed={!stream.streaming}
              renderers={renderers}
            />
          )}
        </Animated.ScrollView>
        <View
          style={[styles.follow, { bottom: insets.bottom + 34 }]}
          pointerEvents="box-none"
        >
          {stream.streaming && turned && stream.detached && (
            <FollowPill onFollow={stream.follow} />
          )}
        </View>
      </Page>
    </View>
  );
}

// A page of the notebook: a running head over the writing, and the page
// number at its outer corner.
function Page({
  size,
  side,
  top,
  bottom,
  inset,
  head,
  number,
  onReplay,
  children,
}: {
  side: 'left' | 'right';
  top: number;
  bottom: number;
  size: { width: number } | { height: number };
  inset: number;
  head: string;
  number: number;
  onReplay?: () => void;
  children: ReactNode;
}) {
  const outer = side === 'left' ? 'paddingLeft' : 'paddingRight';
  return (
    <View style={[styles.page, size, { [outer]: inset }]}>
      <DotGrid />
      <View
        style={[
          styles.head,
          side === 'right' && styles.headRight,
          { paddingTop: top + 12 },
        ]}
      >
        <Text style={styles.headText}>{head.toUpperCase()}</Text>
        {onReplay && (
          <Text
            style={styles.replay}
            onPress={onReplay}
            suppressHighlighting
            accessibilityRole="button"
            accessibilityLabel="Replay the answer"
          >
            ↻
          </Text>
        )}
      </View>
      {children}
      <Text
        style={[
          styles.number,
          side === 'left' ? styles.numberLeft : styles.numberRight,
          { bottom: bottom + 12 },
        ]}
      >
        {number}
      </Text>
    </View>
  );
}

// The fold between the pages, deepest while the notebook is half open.
function Crease({ open, across }: { open: Hinge['open']; across: boolean }) {
  const style = useAnimatedStyle(() => ({
    opacity: interpolate(open.value, [0.3, 1], [1, 0.55], 'clamp'),
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
            <Stop offset="0" stopColor="#5A4632" stopOpacity={0} />
            <Stop offset="0.5" stopColor="#5A4632" stopOpacity={0.3} />
            <Stop offset="1" stopColor="#5A4632" stopOpacity={0} />
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
    backgroundColor: PAPER,
  },
  stacked: {
    flexDirection: 'column',
  },
  page: {
    flexShrink: 0,
    overflow: 'hidden',
  },
  head: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 26,
    paddingBottom: 8,
  },
  headRight: {
    justifyContent: 'flex-end',
  },
  headText: {
    fontFamily: FONTS.mono,
    fontSize: 9,
    letterSpacing: 2,
    color: INK_SOFT,
  },
  replay: {
    fontFamily: FONTS.monoMedium,
    fontSize: 18,
    color: VERMILION,
  },
  content: {
    paddingHorizontal: 26,
    paddingTop: 10,
  },
  number: {
    position: 'absolute',
    fontFamily: FONTS.display,
    fontSize: 13,
    color: INK_SOFT,
  },
  numberLeft: {
    left: 26,
  },
  numberRight: {
    right: 26,
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
