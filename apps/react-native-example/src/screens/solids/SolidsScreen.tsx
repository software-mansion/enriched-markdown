import { useMemo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated from 'react-native-reanimated';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  EnrichedMarkdownText,
  type MarkdownRenderers,
} from 'react-native-enriched-markdown';
import { useDemoStream } from '../shared/useDemoStream';
import { FollowPill } from '../journal/JournalScreen';
import { SolidCell, StreamRun } from './SolidCell';
import { PROMPT, SOLIDS_MARKDOWN } from './solidsMarkdown';
import {
  FONTS,
  NIGHT,
  RULE,
  TEXT,
  TEXT_SOFT,
  VIOLET,
  solidsMarkdownStyle,
} from './theme';

const renderers: MarkdownRenderers = {
  code: (block) =>
    block.language === 'typegpu' ? <SolidCell block={block} /> : undefined,
};

// A cell lands with its whole stage, so the follow glides rather than jumps.
const FOLLOW_OMEGA = 6;

export default function SolidsScreen() {
  const insets = useSafeAreaInsets();
  const stream = useDemoStream(
    SOLIDS_MARKDOWN,
    undefined,
    true,
    'typed',
    FOLLOW_OMEGA,
    'words'
  );
  const contentStyle = useMemo(
    () => [styles.content, { paddingBottom: insets.bottom + 120 }],
    [insets.bottom]
  );

  return (
    <GestureHandlerRootView style={styles.root}>
      <View style={[styles.header, { paddingTop: insets.top + 8 }]}>
        <View style={styles.badge}>
          <Text style={styles.badgeText}>▲</Text>
        </View>
        <View style={styles.titles}>
          <Text style={styles.title}>Solids</Text>
          <Text style={styles.sub}>
            {stream.writing ? 'writing…' : 'TypeGPU in markdown'}
          </Text>
        </View>
        <Pressable onPress={stream.replay} hitSlop={12} testID="solids-replay">
          <Text style={styles.replay}>↻ REPLAY</Text>
        </Pressable>
      </View>
      <Animated.ScrollView
        {...stream.scrollProps}
        contentContainerStyle={contentStyle}
      >
        <View style={styles.prompt}>
          <Text style={styles.promptLabel}>YOU</Text>
          <Text style={styles.promptText}>{PROMPT}</Text>
        </View>
        <StreamRun.Provider value={stream.run}>
          <EnrichedMarkdownText
            key={stream.run}
            flavor="github"
            markdown={stream.markdown}
            markdownStyle={solidsMarkdownStyle}
            renderers={renderers}
            streamingAnimation={stream.streaming}
          />
        </StreamRun.Provider>
      </Animated.ScrollView>
      <View
        style={[styles.pillRow, { bottom: insets.bottom + 24 }]}
        pointerEvents="box-none"
      >
        {stream.streaming && stream.detached && (
          <FollowPill onFollow={stream.follow} />
        )}
      </View>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: NIGHT,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingBottom: 12,
    gap: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: RULE,
  },
  badge: {
    width: 36,
    height: 36,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#1C1736',
    borderWidth: 1,
    borderColor: '#3A2F70',
  },
  badgeText: {
    color: VIOLET,
    fontSize: 16,
  },
  titles: {
    flex: 1,
  },
  title: {
    fontFamily: FONTS.sansBold,
    fontSize: 20,
    color: TEXT,
  },
  sub: {
    fontFamily: FONTS.mono,
    fontSize: 12,
    color: TEXT_SOFT,
    marginTop: 1,
  },
  replay: {
    fontFamily: FONTS.monoMedium,
    fontSize: 12,
    color: VIOLET,
    letterSpacing: 1,
  },
  content: {
    paddingHorizontal: 20,
    paddingTop: 20,
  },
  prompt: {
    alignSelf: 'flex-end',
    maxWidth: '85%',
    backgroundColor: '#1A1830',
    borderRadius: 16,
    borderBottomRightRadius: 4,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginBottom: 22,
  },
  promptLabel: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 1.5,
    color: VIOLET,
    marginBottom: 3,
  },
  promptText: {
    fontFamily: FONTS.sans,
    fontSize: 15,
    lineHeight: 21,
    color: TEXT,
  },
  pillRow: {
    position: 'absolute',
    left: 0,
    right: 0,
    alignItems: 'center',
  },
});
