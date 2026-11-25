import { memo, useEffect, useMemo, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  interpolate,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import Svg, {
  Circle,
  G,
  Line,
  Path,
  Polygon,
  Polyline,
  Rect,
  Text as SvgText,
} from 'react-native-svg';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import { AMBER, EL, FONTS, PAPER, PAPER_SOFT } from '../theme';
import { CardTitle, cardStyle } from './CardTitle';
import { SETTLE, codeLines, useEntrance } from './motion';
import { Segments } from './Segments';

const CHART_HEIGHT = 150;
const TOP_ALT = 800;
const PAD_X = 10;
const GROUND = CHART_HEIGHT - 18;

interface Callout {
  get: number;
  time: string;
  alt?: number;
  down?: number;
  fwd?: number;
  fuel?: number;
  call?: string;
  dust: boolean;
  contact: boolean;
}

function seconds(time: string) {
  const [h = 0, m = 0, s = 0] = time.split(':').map(Number);
  return h * 3600 + m * 60 + s;
}

function number(line: string, key: string) {
  const match = line.match(new RegExp(`${key}\\s+([\\d.]+)`));
  return match ? Number(match[1]) : undefined;
}

// `102:43:26  ALT 400  DOWN 9  FWD 58`, `102:45:02  CALL 60 SECONDS`,
// `102:45:40  CONTACT LIGHT`: one callout per line, in feet and feet a second.
function callout(line: string): Callout | null {
  const time = line.match(/^\s*(\d+:\d{2}:\d{2})/)?.[1];
  if (!time) return null;
  return {
    get: seconds(time),
    time,
    alt: number(line, 'ALT'),
    down: number(line, 'DOWN'),
    fwd: number(line, 'FWD'),
    fuel: number(line, 'FUEL'),
    call: line.match(/CALL\s+(.+)$/)?.[1]?.trim(),
    dust: /\bDUST\b/.test(line),
    contact: /CONTACT/.test(line),
  };
}

function latest<K extends 'alt' | 'down' | 'fwd' | 'fuel'>(
  callouts: Callout[],
  key: K
) {
  for (let i = callouts.length - 1; i >= 0; i--) {
    const value = callouts[i]![key];
    if (value !== undefined) return value;
  }
  return undefined;
}

function spoken(c: Callout) {
  if (c.contact) return 'CONTACT LIGHT';
  if (c.call) return c.call;
  if (c.alt === undefined)
    return c.fuel !== undefined ? `${c.fuel} PERCENT` : '';
  const parts = [`${c.alt} FEET`];
  if (c.down !== undefined) parts.push(`DOWN ${c.down}`);
  if (c.fwd !== undefined) parts.push(`${c.fwd} FORWARD`);
  if (c.dust) parts.push('PICKING UP SOME DUST');
  return parts.join(', ');
}

// A ```descent block as the last three minutes on the console: each callout
// plots as it streams in, the lander easing down to the next height.
export function DescentTrace({ block }: { block: MarkdownCodeBlock }) {
  const callouts = useMemo(
    () =>
      codeLines(block.code)
        .map(callout)
        .filter((c): c is Callout => c !== null),
    [block.code]
  );
  const [width, setWidth] = useState(0);
  const entrance = useEntrance();
  const style = useAnimatedStyle(() => ({
    opacity: entrance.value,
    transform: [{ translateY: interpolate(entrance.value, [0, 1], [18, 0]) }],
  }));

  const last = callouts[callouts.length - 1];
  const alt = latest(callouts, 'alt');
  const contact = callouts.some((c) => c.contact);

  return (
    <Animated.View style={[styles.card, style]}>
      <CardTitle
        renderer="DescentTrace"
        title="P66 · ALDRIN'S CALLOUTS"
        right={<ContactLamp lit={contact} />}
      />
      <View style={styles.readouts}>
        <View style={styles.altitude}>
          <Text style={styles.readoutLabel}>ALT FT</Text>
          <Segments
            text={
              contact
                ? '    0'
                : alt === undefined
                  ? '     '
                  : String(Math.round(alt)).padStart(5, ' ')
            }
            height={30}
          />
        </View>
        <Readout label="DOWN" value={contact ? 0 : latest(callouts, 'down')} />
        <Readout label="FWD" value={contact ? 0 : latest(callouts, 'fwd')} />
        <Readout label="FUEL %" value={latest(callouts, 'fuel')} warn />
      </View>
      <View
        style={styles.chart}
        onLayout={(event) => setWidth(event.nativeEvent.layout.width)}
      >
        {width > 0 && callouts.length > 0 && (
          <Chart callouts={callouts} width={width} contact={contact} />
        )}
      </View>
      <Text style={styles.ticker} numberOfLines={1}>
        {last ? `${last.time}  ${spoken(last)}` : ' '}
      </Text>
    </Animated.View>
  );
}

function Readout({
  label,
  value,
  warn = false,
}: {
  label: string;
  value: number | undefined;
  warn?: boolean;
}) {
  return (
    <View style={styles.readout}>
      <Text style={styles.readoutLabel}>{label}</Text>
      <Text
        style={[
          styles.readoutValue,
          warn && value !== undefined && value <= 5 && styles.readoutWarn,
        ]}
      >
        {value === undefined ? '—' : value}
      </Text>
    </View>
  );
}

const Chart = memo(function Chart({
  callouts,
  width,
  contact,
}: {
  callouts: Callout[];
  width: number;
  contact: boolean;
}) {
  const first = callouts[0]!.get - 4;
  const end = first + 165;
  const x = (get: number) =>
    PAD_X + ((get - first) / (end - first)) * (width - PAD_X * 2);
  const y = (alt: number) => GROUND - (alt / TOP_ALT) * (GROUND - 12);

  const points = callouts.flatMap((c) =>
    c.contact
      ? [{ get: c.get, alt: 0 }]
      : c.alt === undefined
        ? []
        : [{ get: c.get, alt: c.alt }]
  );
  const calls = callouts.filter((c) => c.call);
  const dust = callouts.find((c) => c.dust);
  const lander = points[points.length - 1];

  return (
    <View style={StyleSheet.absoluteFill}>
      <Svg width={width} height={CHART_HEIGHT}>
        {[200, 400, 600].map((alt) => (
          <G key={alt}>
            <Line
              x1={PAD_X}
              x2={width - PAD_X}
              y1={y(alt)}
              y2={y(alt)}
              stroke="#1E2632"
              strokeWidth={1}
            />
            <SvgText
              x={width - PAD_X}
              y={y(alt) - 3}
              fontSize={8}
              fill="#4A5566"
              textAnchor="end"
              fontFamily={FONTS.mono}
            >
              {`${alt}`}
            </SvgText>
          </G>
        ))}
        {calls.map((c) => (
          <G key={c.time}>
            <Line
              x1={x(c.get)}
              x2={x(c.get)}
              y1={8}
              y2={GROUND}
              stroke={AMBER}
              strokeWidth={1}
              strokeDasharray="3 3"
            />
            <SvgText
              x={x(c.get) + 3}
              y={16}
              fontSize={8}
              fill={AMBER}
              fontFamily={FONTS.monoMedium}
            >
              {c.call?.replace(' SECONDS', ' SEC')}
            </SvgText>
          </G>
        ))}
        <Surface width={width} />
        <Polyline
          points={points.map((p) => `${x(p.get)},${y(p.alt)}`).join(' ')}
          stroke={EL}
          strokeWidth={1.6}
          fill="none"
        />
        {points.map((p) => (
          <Circle key={p.get} cx={x(p.get)} cy={y(p.alt)} r={2.2} fill={EL} />
        ))}
      </Svg>
      {dust && !contact && <Dust left={x(dust.get)} />}
      {lander && (
        <Lander left={x(lander.get)} top={y(lander.alt)} landed={contact} />
      )}
    </View>
  );
});

const Surface = memo(function Surface({ width }: { width: number }) {
  // A gentle regolith line with a few boulders, flat where Eagle sets down.
  const d = `M 0 ${GROUND + 2} Q ${width * 0.15} ${GROUND - 3}, ${width * 0.3} ${GROUND + 1} T ${width * 0.6} ${GROUND} L ${width} ${GROUND} L ${width} ${CHART_HEIGHT} L 0 ${CHART_HEIGHT} Z`;
  return (
    <G>
      <Path d={d} fill="#2A2E35" />
      <Line x1={0} x2={width} y1={GROUND} y2={GROUND} stroke="#3B414B" />
      {[0.12, 0.2, 0.34, 0.45].map((f) => (
        <Rect
          key={f}
          x={width * f}
          y={GROUND - 4}
          width={6}
          height={5}
          rx={2}
          fill="#3B414B"
        />
      ))}
    </G>
  );
});

const LANDER = 26;

function Lander({
  left,
  top,
  landed,
}: {
  left: number;
  top: number;
  landed: boolean;
}) {
  const x = useSharedValue(left);
  const y = useSharedValue(top);
  const flame = useSharedValue(0);
  useEffect(() => {
    x.value = withTiming(left, { duration: 600, easing: SETTLE });
    y.value = withTiming(top, { duration: 600, easing: SETTLE });
  }, [x, y, left, top]);
  useEffect(() => {
    flame.value = landed
      ? withTiming(0, { duration: 300 })
      : withRepeat(
          withSequence(
            withTiming(1, { duration: 70 }),
            withTiming(0.55, { duration: 90 })
          ),
          -1
        );
  }, [flame, landed]);
  const style = useAnimatedStyle(() => ({
    transform: [
      { translateX: x.value - LANDER / 2 },
      { translateY: y.value - LANDER + 2 },
    ],
  }));
  const flameStyle = useAnimatedStyle(() => ({
    opacity: flame.value,
    transform: [{ scaleY: 0.6 + flame.value * 0.5 }],
  }));
  return (
    <Animated.View style={[styles.lander, style]} pointerEvents="none">
      <Animated.View style={[styles.flame, flameStyle]} />
      <Svg width={LANDER} height={LANDER} viewBox="0 0 26 26">
        <Polygon points="9,3 17,3 19,8 7,8" fill="#C9CDD4" />
        <Rect x={6} y={8} width={14} height={7} fill="#D9A441" />
        <Line
          x1={7}
          y1={15}
          x2={2}
          y2={24}
          stroke="#C9CDD4"
          strokeWidth={1.4}
        />
        <Line
          x1={19}
          y1={15}
          x2={24}
          y2={24}
          stroke="#C9CDD4"
          strokeWidth={1.4}
        />
        <Line
          x1={0}
          y1={24}
          x2={4}
          y2={24}
          stroke="#C9CDD4"
          strokeWidth={1.6}
        />
        <Line
          x1={22}
          y1={24}
          x2={26}
          y2={24}
          stroke="#C9CDD4"
          strokeWidth={1.6}
        />
      </Svg>
    </Animated.View>
  );
}

const MOTES = [-14, -8, -3, 3, 8, 14];

function Dust({ left }: { left: number }) {
  return (
    <View style={[styles.dust, { left }]} pointerEvents="none">
      {MOTES.map((dx, i) => (
        <Mote key={dx} dx={dx} index={i} />
      ))}
    </View>
  );
}

function Mote({ dx, index }: { dx: number; index: number }) {
  const t = useSharedValue(0);
  useEffect(() => {
    t.value = withRepeat(withTiming(1, { duration: 700 + index * 90 }), -1);
  }, [t, index]);
  const style = useAnimatedStyle(() => ({
    opacity: 0.7 * (1 - t.value),
    transform: [
      { translateX: dx * (1 + t.value * 2.2) },
      { translateY: -t.value * 6 },
    ],
  }));
  return <Animated.View style={[styles.mote, style]} />;
}

function ContactLamp({ lit }: { lit: boolean }) {
  const glow = useSharedValue(0);
  useEffect(() => {
    glow.value = withTiming(lit ? 1 : 0, { duration: 160 });
  }, [glow, lit]);
  const style = useAnimatedStyle(() => ({
    backgroundColor: glow.value > 0.5 ? EL : '#14201A',
    shadowOpacity: glow.value,
  }));
  return (
    <Animated.View style={[styles.contact, style]}>
      <Text style={[styles.contactText, lit && styles.contactTextLit]}>
        CONTACT
      </Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  card: {
    ...cardStyle,
    gap: 12,
  },
  readouts: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 12,
  },
  altitude: {
    flex: 1,
  },
  readout: {
    alignItems: 'flex-end',
  },
  readoutLabel: {
    fontFamily: FONTS.mono,
    fontSize: 8.5,
    letterSpacing: 1,
    color: PAPER_SOFT,
    marginBottom: 3,
  },
  readoutValue: {
    fontFamily: FONTS.monoMedium,
    fontSize: 18,
    color: PAPER,
  },
  readoutWarn: {
    color: AMBER,
  },
  chart: {
    height: CHART_HEIGHT,
    borderRadius: 8,
    backgroundColor: '#0A0D12',
    overflow: 'hidden',
  },
  ticker: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10.5,
    letterSpacing: 0.6,
    color: EL,
  },
  lander: {
    position: 'absolute',
    left: 0,
    top: 0,
    width: LANDER,
    height: LANDER,
  },
  flame: {
    position: 'absolute',
    left: LANDER / 2 - 3,
    top: 15,
    width: 6,
    height: 12,
    borderRadius: 3,
    backgroundColor: '#FFD9A0',
    transformOrigin: 'top',
  },
  dust: {
    position: 'absolute',
    top: GROUND - 3,
    width: 0,
    height: 0,
  },
  mote: {
    position: 'absolute',
    width: 3,
    height: 3,
    borderRadius: 1.5,
    backgroundColor: '#9AA1AB',
  },
  contact: {
    borderRadius: 3,
    paddingHorizontal: 8,
    paddingVertical: 4,
    shadowColor: EL,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 0 },
  },
  contactText: {
    fontFamily: FONTS.label,
    fontSize: 8,
    letterSpacing: 1,
    color: '#3B4A6B',
  },
  contactTextLit: {
    color: '#0B1A0E',
  },
});
