import { useCallback, useEffect, useMemo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, { FadeIn, FadeOut } from 'react-native-reanimated';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  EnrichedMarkdownText,
  type LinkPressEvent,
  type MarkdownRenderers,
} from 'react-native-enriched-markdown';
import { useDemoStream } from '../shared/useDemoStream';
import { FollowPill } from '../journal/JournalScreen';
import { engine, usePlaying } from './audio';
import { BLUES_MARKDOWN, PROMPT } from './bluesMarkdown';
import { chordNotes, parseChord, parseNote } from './theory';
import { FlipCell } from './cells/FlipCell';
import { GrooveCell } from './cells/GrooveCell';
import { JamCell } from './cells/JamCell';
import { KeysCell } from './cells/KeysCell';
import { ProgressionCell } from './cells/ProgressionCell';
import { QuizCell } from './cells/QuizCell';
import { StaffCell } from './cells/StaffCell';
import {
  BRASS,
  CREAM,
  FONTS,
  MIDNIGHT,
  RED,
  STAGE_BACKGROUND,
  bluesMarkdownStyle,
  glow,
} from './theme';
import { Scope } from './Scope';

const CELLS = {
  keys: KeysCell,
  quiz: QuizCell,
  flip: FlipCell,
  staff: StaffCell,
  groove: GrooveCell,
  progression: ProgressionCell,
  jam: JamCell,
} as const;

const renderers: MarkdownRenderers = {
  code: (block) => {
    const Cell = CELLS[block.language as keyof typeof CELLS];
    return Cell ? <Cell block={block} /> : undefined;
  },
};

// `chord:Cm` and `note:Gb4` in the prose: tap to hear.
function onLinkPress({ url }: LinkPressEvent) {
  const [scheme, value = ''] = url.split(':');
  if (scheme === 'chord') {
    const chord = parseChord(value);
    if (!chord) return;
    const at = engine.now();
    chordNotes(chord).forEach((midi, i) =>
      engine.piano(midi, at + i * 0.03, 1.4, 0.75)
    );
  }
  if (scheme === 'note') {
    const midi = parseNote(value);
    if (midi !== null) engine.piano(midi, undefined, 1.2, 0.85);
  }
}

// A cell lands with its whole stage, so the follow glides rather than jumps.
const FOLLOW_OMEGA = 6;
// How far ahead of the downbeat a held block is let in, for it to render.
const LEAD_MS = 60;

// Once the band plays, the answer keeps time with it: every block opens on
// a downbeat, and the chart writes a line of bars per bar.
function holdFence(line: string, language: string) {
  if (!engine.playing) return 0;
  const opening = line.startsWith('```');
  const chartLine = language === 'progression' && !line.trim().startsWith('//');
  if (!opening && !chartLine) return 0;
  return Math.max(0, engine.msToNextBar() - LEAD_MS);
}

export default function BluesScreen() {
  const insets = useSafeAreaInsets();
  const stream = useDemoStream(
    BLUES_MARKDOWN,
    undefined,
    true,
    'lines',
    FOLLOW_OMEGA,
    'words',
    holdFence
  );
  const playing = usePlaying();
  const contentStyle = useMemo(
    () => [styles.content, { paddingBottom: insets.bottom + 120 }],
    [insets.bottom]
  );

  // Decodes the piano while the prompt is still being read.
  useEffect(() => {
    engine.context();
    return () => engine.stop();
  }, []);

  const replay = useCallback(() => {
    engine.stop();
    stream.replay();
  }, [stream]);

  return (
    <GestureHandlerRootView style={styles.root}>
      <View style={[styles.header, { paddingTop: insets.top + 6 }]}>
        <View style={styles.headerRow}>
          <View style={styles.titles}>
            <Text style={styles.kicker}>
              {stream.writing ? '● WRITING' : 'LESSON · AUDIO-API'}
            </Text>
            <Text style={styles.title}>The Blues</Text>
          </View>
          <Pressable
            onPress={replay}
            hitSlop={12}
            testID="blues-replay"
            style={({ pressed }) => [styles.replay, pressed && styles.pressed]}
          >
            <Text style={styles.replayText}>↻</Text>
          </Pressable>
        </View>
        <Scope height={34} />
      </View>
      <Animated.ScrollView
        {...stream.scrollProps}
        contentContainerStyle={contentStyle}
      >
        <View style={styles.prompt}>
          <Text style={styles.promptText}>{PROMPT}</Text>
        </View>
        <EnrichedMarkdownText
          key={stream.run}
          flavor="github"
          markdown={stream.markdown}
          markdownStyle={bluesMarkdownStyle}
          renderers={renderers}
          onLinkPress={onLinkPress}
          streamingAnimation={stream.streaming}
        />
      </Animated.ScrollView>
      <View
        style={[styles.pillRow, { bottom: insets.bottom + 20 }]}
        pointerEvents="box-none"
      >
        {stream.streaming && stream.detached && (
          <FollowPill onFollow={stream.follow} />
        )}
        {playing && (
          <Animated.View entering={FadeIn} exiting={FadeOut}>
            <Pressable
              onPress={() => engine.stop()}
              style={styles.stop}
              testID="blues-stop"
            >
              <View style={styles.stopLight} />
              <Text style={styles.stopText}>BAND PLAYING · STOP</Text>
            </Pressable>
          </Animated.View>
        )}
      </View>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: MIDNIGHT,
    backgroundImage: STAGE_BACKGROUND,
  },
  header: {
    paddingHorizontal: 20,
    paddingBottom: 4,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#ffffff14',
    backgroundColor: '#07090FCC',
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  titles: {
    flex: 1,
  },
  kicker: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10,
    letterSpacing: 2,
    color: BRASS,
  },
  title: {
    fontFamily: FONTS.display,
    fontSize: 28,
    lineHeight: 34,
    color: CREAM,
  },
  replay: {
    width: 38,
    height: 38,
    borderRadius: 19,
    borderWidth: 1,
    borderColor: '#ffffff22',
    alignItems: 'center',
    justifyContent: 'center',
  },
  pressed: {
    transform: [{ scale: 0.92 }],
  },
  replayText: {
    fontSize: 18,
    color: CREAM,
  },
  content: {
    paddingHorizontal: 20,
    paddingTop: 22,
  },
  prompt: {
    alignSelf: 'flex-end',
    maxWidth: '85%',
    backgroundImage: 'linear-gradient(135deg, #3A2A12 0%, #2A1F10 100%)',
    borderWidth: 1,
    borderColor: '#5A4320',
    borderRadius: 20,
    borderBottomRightRadius: 6,
    paddingHorizontal: 16,
    paddingVertical: 11,
    marginBottom: 26,
  },
  promptText: {
    fontFamily: FONTS.serif,
    fontSize: 17,
    lineHeight: 23,
    color: '#FFE3B5',
  },
  pillRow: {
    position: 'absolute',
    left: 0,
    right: 0,
    alignItems: 'center',
    gap: 10,
  },
  stop: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: '#0B0E19EE',
    borderWidth: 1,
    borderColor: BRASS + '66',
    borderRadius: 22,
    paddingHorizontal: 16,
    paddingVertical: 10,
    boxShadow: '0 8px 24px rgba(0,0,0,0.6)',
  },
  stopLight: {
    width: 7,
    height: 7,
    borderRadius: 4,
    backgroundColor: RED,
    boxShadow: glow(RED, 8),
  },
  stopText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 11,
    letterSpacing: 1.5,
    color: CREAM,
  },
});
