import { useMemo, useState } from 'react';
import { StyleSheet, View, useWindowDimensions } from 'react-native';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import { LIGHTBOX_MARGIN, Lightbox } from '../Lightbox';
import { Tappable } from '../Tappable';
import { BarChart } from './BarChart';
import { Donut } from './Donut';
import { MoodLine } from './MoodLine';
import { parseMermaid, type MermaidChart } from './parse';
import { ChartScale } from './scale';

// The page column a chart is drawn for, and the widest it lifts to.
const PAGE_WIDTH = 360;
const LIFTED_WIDTH = 600;

// A ```mermaid block drawn in the journal's own hand, from the diagram its
// first line names. Until that line has landed there is nothing to draw.
// Once complete, a tap lifts it into the lightbox, drawn again and larger.
export function Mermaid({ block }: { block: MarkdownCodeBlock }) {
  const chart = useMemo(() => parseMermaid(block.code), [block.code]);
  const [open, setOpen] = useState(false);
  if (!chart) return null;
  return (
    <>
      <Tappable
        onPress={() => setOpen(true)}
        disabled={!block.isComplete}
        label={`Open chart: ${chart.title ?? chart.kind}`}
      >
        <Drawn chart={chart} complete={block.isComplete} />
      </Tappable>
      <Lightbox open={open} onClose={() => setOpen(false)} label="Close chart">
        <Lifted chart={chart} />
      </Lightbox>
    </>
  );
}

function Lifted({ chart }: { chart: MermaidChart }) {
  const window = useWindowDimensions();
  const width = Math.min(window.width - LIGHTBOX_MARGIN * 2, LIFTED_WIDTH);
  return (
    <ChartScale.Provider value={Math.max(1, width / PAGE_WIDTH)}>
      <View style={[styles.lifted, { width }]}>
        <Drawn chart={chart} complete />
      </View>
    </ChartScale.Provider>
  );
}

function Drawn({
  chart,
  complete,
}: {
  chart: MermaidChart;
  complete: boolean;
}) {
  switch (chart.kind) {
    case 'xychart':
      return <BarChart chart={chart} complete={complete} />;
    case 'pie':
      return <Donut chart={chart} complete={complete} />;
    case 'journey':
      return <MoodLine chart={chart} complete={complete} />;
  }
}

const styles = StyleSheet.create({
  lifted: {
    borderRadius: 14,
    shadowColor: '#000',
    shadowOpacity: 0.35,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 8 },
  },
});
