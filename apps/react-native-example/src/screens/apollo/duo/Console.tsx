import { memo, useRef, type ComponentRef } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { latestBlock, tapeLines, type TapeLine } from '../../shared/tapeLines';
import { missionTime } from '../FlightJournalScreen';
import { rendererFor } from '../renderers';
import { Segments } from '../renderers/Segments';
import {
  AMBER,
  CARD_LABEL,
  CONSOLE_EDGE,
  EL,
  FONTS,
  PANEL_EDGE,
  PAPER,
  PAPER_SOFT,
  STAR,
  accentFor,
} from '../theme';

// The right page: the console in Houston, following the journal on the left.
// The clock shows how far into the descent the answer has got, and the
// tape the markdown it is made of.
export function Console({
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
  const time = missionTime(markdown);
  return (
    <View
      style={[
        styles.root,
        { paddingTop: top + 14, paddingBottom: bottom + 14 },
      ]}
    >
      <View style={styles.head}>
        <Text style={styles.station}>MISSION CONTROL · HOUSTON</Text>
        <Pressable
          onPress={onReplay}
          hitSlop={12}
          accessibilityRole="button"
          accessibilityLabel="Replay the answer"
        >
          <Text style={styles.replay}>↻</Text>
        </Pressable>
      </View>
      <View style={styles.clock}>
        <Text style={styles.clockLabel}>GROUND ELAPSED TIME</Text>
        <Clock time={time} />
      </View>
      <Text style={styles.tapeLabel}>THE ANSWER AS WRITTEN</Text>
      <Source markdown={markdown} streaming={streaming} />
    </View>
  );
}

function Clock({ time }: { time: string | null }) {
  const [h, m, s] = (time ?? '').split(':');
  return (
    <View style={styles.clockDigits}>
      <Segments text={h ?? '   '} height={26} />
      <Text style={styles.colon}>:</Text>
      <Segments text={m ?? '  '} height={26} />
      <Text style={styles.colon}>:</Text>
      <Segments text={s ?? '  '} height={26} />
    </View>
  );
}

// The answer line by line, dimmed, each block that becomes a component
// marked in that component's accent, and the latest one lit.
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

const TAPE_DIM = '#7C8695';

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
        accent && styles.blockLine,
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

const styles = StyleSheet.create({
  root: {
    flex: 1,
    paddingHorizontal: 18,
    gap: 14,
  },
  head: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  station: {
    fontFamily: FONTS.label,
    fontSize: 10,
    letterSpacing: 1.8,
    color: PAPER_SOFT,
  },
  replay: {
    fontFamily: FONTS.monoMedium,
    fontSize: 20,
    color: STAR,
  },
  clock: {
    backgroundColor: '#0B0D0B',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: CONSOLE_EDGE,
    paddingVertical: 12,
    paddingHorizontal: 14,
    gap: 8,
  },
  clockLabel: {
    fontFamily: FONTS.label,
    fontSize: 8,
    letterSpacing: 1.6,
    color: '#5E7A58',
  },
  clockDigits: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  colon: {
    fontFamily: FONTS.monoMedium,
    fontSize: 20,
    color: EL,
    marginTop: -3,
  },
  tapeLabel: {
    fontFamily: FONTS.label,
    fontSize: 8.5,
    letterSpacing: 1.6,
    color: PAPER_SOFT,
    marginBottom: -6,
  },
  tape: {
    flex: 1,
    borderRadius: 10,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: PANEL_EDGE,
    backgroundColor: 'rgba(18, 22, 29, 0.85)',
  },
  tapeContent: {
    paddingVertical: 10,
    paddingRight: 10,
  },
  line: {
    flexDirection: 'row',
    borderLeftWidth: 2,
    borderLeftColor: 'transparent',
  },
  blockLine: {
    borderTopRightRadius: 4,
    borderBottomRightRadius: 4,
  },
  number: {
    width: 28,
    textAlign: 'right',
    marginRight: 10,
    fontFamily: FONTS.mono,
    fontSize: 9.5,
    lineHeight: 15,
    color: '#3A4352',
  },
  body: {
    flex: 1,
  },
  text: {
    fontFamily: FONTS.mono,
    fontSize: 10.5,
    lineHeight: 16,
    color: TAPE_DIM,
  },
  textActive: {
    color: PAPER,
  },
  marker: {
    color: '#4E5867',
  },
  heading: {
    color: CARD_LABEL,
  },
  caret: {
    color: AMBER,
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
