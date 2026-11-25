import { memo, useEffect, useMemo, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  interpolate,
  useAnimatedProps,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import Svg, { Path } from 'react-native-svg';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import {
  AMBER,
  AMBER_DIM,
  EL,
  FONTS,
  PANEL_EDGE,
  PAPER,
  PAPER_SOFT,
} from '../theme';
import { CardTitle, cardStyle } from './CardTitle';
import { SETTLE, codeLines, useEntrance } from './motion';

const AnimatedPath = Animated.createAnimatedComponent(Path);

const NODE_HEIGHT = 44;
const RANK_GAP = 30;
const COLUMN_GAP = 12;
const EDGE_MS = 320;
const EDGE_COLOR = '#56606F';

type Shape = 'box' | 'alarm';

interface Node {
  id: string;
  label: string;
  shape: Shape;
  rank: number;
}

interface Edge {
  from: string;
  to: string;
}

const END = String.raw`(\w+)(?:\[([^\]]+)\]|\{([^}]+)\})?`;
const EDGE = new RegExp(String.raw`^\s*${END}\s*-->\s*${END}\s*$`);

// Mermaid's flowchart notation, the part an answer needs: `a[Label] --> b`,
// with `{Label}` for the node that raised the alarm.
function parse(lines: string[]) {
  const nodes = new Map<string, Node>();
  const edges: Edge[] = [];
  const add = (id: string, box?: string, alarm?: string) => {
    const known = nodes.get(id);
    if (known) {
      if (!known.label && (box || alarm)) known.label = (box ?? alarm)!;
      return known;
    }
    const node: Node = {
      id,
      label: box ?? alarm ?? id,
      shape: alarm ? 'alarm' : 'box',
      rank: 0,
    };
    nodes.set(id, node);
    return node;
  };
  for (const line of lines) {
    const match = line.match(EDGE);
    if (!match) continue;
    const [, a, aBox, aAlarm, b, bBox, bAlarm] = match;
    const from = add(a!, aBox, aAlarm);
    const to = add(b!, bBox, bAlarm);
    to.rank = Math.max(to.rank, from.rank + 1);
    edges.push({ from: from.id, to: to.id });
  }
  return { nodes: [...nodes.values()], edges };
}

interface Placed extends Node {
  x: number;
  y: number;
  width: number;
}

function layout(nodes: Node[], width: number) {
  const ranks = new Map<number, Node[]>();
  for (const node of nodes) {
    ranks.set(node.rank, [...(ranks.get(node.rank) ?? []), node]);
  }
  const placed = new Map<string, Placed>();
  for (const [rank, row] of ranks) {
    const columns = row.length;
    const nodeWidth =
      columns === 1
        ? width * 0.72
        : (width - COLUMN_GAP * (columns - 1)) / columns;
    const rowWidth = nodeWidth * columns + COLUMN_GAP * (columns - 1);
    row.forEach((node, i) => {
      placed.set(node.id, {
        ...node,
        width: nodeWidth,
        x: (width - rowWidth) / 2 + i * (nodeWidth + COLUMN_GAP),
        y: rank * (NODE_HEIGHT + RANK_GAP),
      });
    });
  }
  const height =
    Math.max(0, ...[...placed.values()].map((n) => n.y)) + NODE_HEIGHT;
  return { placed, height };
}

// A curve from the bottom of one node to the top of the next.
function edgePath(from: Placed, to: Placed) {
  const x1 = from.x + from.width / 2;
  const y1 = from.y + NODE_HEIGHT;
  const x2 = to.x + to.width / 2;
  const y2 = to.y - 4;
  const mid = (y1 + y2) / 2;
  return {
    d: `M ${x1} ${y1} C ${x1} ${mid}, ${x2} ${mid}, ${x2} ${y2}`,
    length: Math.hypot(x2 - x1, y2 - y1) * 1.15 + 4,
    tip: { x: x2, y: y2 },
  };
}

// A ```flowchart block drawn as it streams: each line draws its arrow, then
// springs its node in. Once the block is complete, signal runs down the arrows.
export function Flowchart({ block }: { block: MarkdownCodeBlock }) {
  const { nodes, edges } = useMemo(
    () => parse(codeLines(block.code)),
    [block.code]
  );
  const [width, setWidth] = useState(0);
  const { placed, height } = useMemo(
    () => layout(nodes, width),
    [nodes, width]
  );
  const entrance = useEntrance();
  const style = useAnimatedStyle(() => ({
    opacity: entrance.value,
    transform: [{ translateY: interpolate(entrance.value, [0, 1], [18, 0]) }],
  }));

  return (
    <Animated.View style={[styles.card, style]}>
      <CardTitle renderer="Flowchart" title="HOW THE COMPUTER KEPT FLYING" />
      <View
        style={{ height }}
        onLayout={(event) => setWidth(event.nativeEvent.layout.width)}
      >
        {width > 0 && (
          <>
            <Svg style={StyleSheet.absoluteFill}>
              {edges.map((edge) => {
                const from = placed.get(edge.from);
                const to = placed.get(edge.to);
                if (!from || !to) return null;
                return (
                  <Arrow
                    key={`${edge.from}-${edge.to}`}
                    {...edgePath(from, to)}
                    flowing={block.isComplete}
                  />
                );
              })}
            </Svg>
            {[...placed.values()].map((node, i) => (
              <NodeBox key={node.id} node={node} delayed={i > 0} />
            ))}
          </>
        )}
      </View>
    </Animated.View>
  );
}

const Arrow = memo(function Arrow({
  d,
  length,
  tip,
  flowing,
}: {
  d: string;
  length: number;
  tip: { x: number; y: number };
  flowing: boolean;
}) {
  const drawn = useSharedValue(0);
  const flow = useSharedValue(0);
  const flowOpacity = useSharedValue(0);

  useEffect(() => {
    drawn.value = withTiming(1, { duration: EDGE_MS, easing: SETTLE });
  }, [drawn]);

  useEffect(() => {
    if (!flowing) return;
    flowOpacity.value = withTiming(1, { duration: 400 });
    flow.value = withRepeat(
      withTiming(1, { duration: 900, easing: Easing.linear }),
      -1
    );
  }, [flowing, flow, flowOpacity]);

  const lineProps = useAnimatedProps(() => ({
    strokeDashoffset: length * (1 - drawn.value),
  }));
  const headProps = useAnimatedProps(() => ({
    opacity: interpolate(drawn.value, [0.8, 1], [0, 1], 'clamp'),
  }));
  const flowProps = useAnimatedProps(() => ({
    strokeDashoffset: -flow.value * 14,
    opacity: flowOpacity.value,
  }));

  const head = `M ${tip.x - 5} ${tip.y - 6} L ${tip.x} ${tip.y} L ${tip.x + 5} ${tip.y - 6}`;
  return (
    <>
      <AnimatedPath
        d={d}
        stroke={EDGE_COLOR}
        strokeWidth={2}
        fill="none"
        strokeDasharray={`${length} ${length}`}
        animatedProps={lineProps}
      />
      <AnimatedPath
        d={d}
        stroke={EL}
        strokeWidth={2}
        strokeLinecap="round"
        fill="none"
        strokeDasharray="2 12"
        animatedProps={flowProps}
      />
      <AnimatedPath
        d={head}
        stroke={PAPER_SOFT}
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
        fill="none"
        animatedProps={headProps}
      />
    </>
  );
});

const NodeBox = memo(function NodeBox({
  node,
  delayed,
}: {
  node: Placed;
  delayed: boolean;
}) {
  const shown = useSharedValue(0);
  const glow = useSharedValue(0);
  const alarm = node.shape === 'alarm';

  useEffect(() => {
    shown.value = withDelay(
      delayed ? EDGE_MS * 0.8 : 0,
      withSpring(1, { damping: 12, stiffness: 170 })
    );
    if (alarm) {
      glow.value = withDelay(
        EDGE_MS,
        withRepeat(withTiming(1, { duration: 700 }), -1, true)
      );
    }
  }, [shown, glow, delayed, alarm]);

  const style = useAnimatedStyle(() => ({
    opacity: interpolate(shown.value, [0, 0.4], [0, 1], 'clamp'),
    transform: [{ scale: interpolate(shown.value, [0, 1], [0.82, 1]) }],
    shadowOpacity: alarm ? 0.25 + glow.value * 0.55 : 0,
  }));

  return (
    <Animated.View
      style={[
        styles.node,
        alarm && styles.alarm,
        { left: node.x, top: node.y, width: node.width },
        style,
      ]}
    >
      <Text
        style={[styles.label, alarm && styles.alarmLabel]}
        numberOfLines={2}
        adjustsFontSizeToFit
      >
        {node.label}
      </Text>
    </Animated.View>
  );
});

const styles = StyleSheet.create({
  card: {
    ...cardStyle,
    gap: 16,
  },
  node: {
    position: 'absolute',
    height: NODE_HEIGHT,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: PANEL_EDGE,
    backgroundColor: '#0E1218',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 10,
  },
  alarm: {
    borderColor: AMBER,
    backgroundColor: AMBER_DIM,
    borderRadius: NODE_HEIGHT / 2,
    shadowColor: AMBER,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 0 },
  },
  label: {
    fontFamily: FONTS.body,
    fontSize: 14,
    lineHeight: 17,
    color: PAPER,
    textAlign: 'center',
  },
  alarmLabel: {
    fontFamily: FONTS.monoMedium,
    fontSize: 13,
    letterSpacing: 1,
    color: AMBER,
  },
});
