import {
  createContext,
  memo,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  type LayoutChangeEvent,
} from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  Easing,
  FadeIn,
  FadeOut,
  LinearTransition,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import Svg, { Defs, RadialGradient, Rect, Stop } from 'react-native-svg';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import {
  closePartial,
  compileSolid,
  GROW_SLOTS,
  type Compiled,
  type Knob,
} from './gpu/compile';
import { d } from 'typegpu';
import { onCpu } from './gpu/cpu';
import { KNOBS } from './gpu/raymarch';
import { RADIUS, SolidView } from './gpu/SolidView';
import { HighlightedLine } from './highlight';
import { FONTS, PANEL, RULE, TEXT_SOFT, tintColor, tintFor } from './theme';

// Long enough to read the "compiling" state, short of feeling slow.
const COMPILE_BEAT_MS = 280;
// How long a part the block just added takes to melt on.
const PART_GROW_MS = 450;
// How far a number moves for a drag across its own width, roughly: 90 pt
// changes it by about its own size.
const SCRUB_PT = 90;
const LINE_HEIGHT = 18;
const CARD_RADIUS = 14;
// A new line opens up, and the stage under it glides down, over a moment. A
// layout transition moves the views on the UI thread; the document itself
// lays out once per line.
const LINE_GROW_MS = 140;
// A cell fades in as its block opens, rather than appearing at once.
const CELL_ENTER = FadeIn.duration(320);
// The code types a few characters a frame: what the stream has sent since
// the last frame, spread out, so it never arrives in jumps.
const TYPE_FRAMES = 5;
const LINE_GROW = LinearTransition.duration(LINE_GROW_MS).easing(
  Easing.out(Easing.quad)
);
const CARET_REST_MS = 500;
const GUTTER = 26;
// Measures the code font's advance: it is monospaced, so a column is a width.
const PROBE = '0'.repeat(20);
// The first solid of an answer shows once that its numbers move: its first
// number swells and settles, after the solid has come in.
const NUDGE_DELAY_MS = 1900;
const NUDGE_MS = 1600;
let nudgedRun = -1;
// A solid that grows into itself as it comes in: its first number climbs from
// here to the one written, slowly at first while the solid sweeps in. The
// Mandelbulb's is its power.
const GROW_FROM: Record<string, number> = { mandelbulb: 2 };
const GROW_MS = 3200;

/** Which run of the answer this is: a replay nudges its first solid again. */
export const StreamRun = createContext(0);

type Solid = Extract<Compiled, { ok: true }>;

/**
 * A ```typegpu block as a notebook cell: the code as it streams in, then the
 * solid it describes, compiled to WGSL on the device and raymarched below.
 * While the block is still being written, every whole statement that adds to
 * the solid compiles too, so it takes shape line by line. Once it is whole,
 * its numbers can be dragged; each one is a uniform, so the solid follows
 * without compiling again. The stage under the code is there from the first
 * line, at its final size, so nothing moves when the solid arrives.
 */
export function SolidCell({ block }: { block: MarkdownCodeBlock }) {
  const run = useContext(StreamRun);
  const [preview, setPreview] = useState<Solid | null>(null);
  const [compiled, setCompiled] = useState<Compiled | null>(null);
  const [showWgsl, setShowWgsl] = useState(false);
  const [values, setValues] = useState<number[] | null>(null);
  const [active, setActive] = useState(-1);
  // A partial block that does not compile, a loop still open, waits to be
  // whole before anything shows, and the stage says so.
  const [unfinished, setUnfinished] = useState(false);
  const [motion, setMotion] = useState<'nudge' | 'grow' | null>(null);
  const knobs = useSharedValue<number[]>([]);
  const probe = useSharedValue<number[]>([0, 0, 0, 0]);
  const [hit, setHit] = useState<Hit | null>(null);
  const tried = useRef<string | null>(null);
  const previews = useRef(0);
  // When the newest part is fully on, so the finished solid waits for it.
  const grown = useRef(0);

  // Each statement that adds to the solid, as it arrives.
  useEffect(() => {
    if (block.isComplete) return;
    const closed = closePartial(block.code);
    if (!closed || closed === tried.current) return;
    const timer = setTimeout(() => {
      tried.current = closed;
      const slot = GROW_SLOTS[previews.current % GROW_SLOTS.length];
      const result = compileSolid(closed, false, slot);
      setUnfinished(!result.ok);
      if (!result.ok) return;
      previews.current++;
      setPreview(result);
    }, 0);
    return () => clearTimeout(timer);
  }, [block.code, block.isComplete]);

  // The compile and the render it causes land in separate frames, so neither
  // holds up the stream for long.
  useEffect(() => {
    if (!block.isComplete) return;
    let frame = 0;
    const timer = setTimeout(
      () => {
        const result = compileSolid(block.code, true);
        frame = requestAnimationFrame(() => setCompiled(result));
      },
      preview
        ? Math.max(COMPILE_BEAT_MS / 2, grown.current - performance.now())
        : COMPILE_BEAT_MS
    );
    return () => {
      clearTimeout(timer);
      cancelAnimationFrame(frame);
    };
    // The preview only shortens the beat; a new one must not restart it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [block.code, block.isComplete]);

  const solid = compiled?.ok ? compiled : compiled ? null : preview;
  const final = compiled?.ok ? compiled : null;

  // A tap on the solid: the same function, run on the CPU, finds where it
  // landed, and the shader rings that point.
  const onProbe = useCallback(
    (ray: number[], time: number) => {
      if (!final) return;
      const found = probeOnCpu(final, knobs.value, ray, time);
      setHit(found);
      if (!found) return;
      const [x, y, z] = found.point;
      probe.value = [x, y, z, 0];
      probe.value = [x, y, z, 1];
    },
    [final, knobs, probe]
  );
  useEffect(() => {
    probe.value = [0, 0, 0, 0];
    setHit(null);
  }, [final, probe]);

  // A new shader starts from the numbers as written, and the part it adds
  // melts on through its grow slot. The other slot is the shader still on
  // screen, which keeps its own newest part whole until this one takes over.
  useEffect(() => {
    if (!solid) return;
    const next = new Array<number>(KNOBS).fill(0);
    solid.knobs.forEach((knob, i) => (next[i] = knob.value));
    for (const slot of GROW_SLOTS) next[slot] = knobs.value[slot] ?? 1;
    const slot = solid.grow;
    if (slot !== undefined) next[slot] = 0;
    knobs.value = next;
    setValues(null);
    if (slot === undefined) return;
    grown.current = performance.now() + PART_GROW_MS;
    return playSlot(slot, PART_GROW_MS, knobs);
  }, [solid, knobs]);

  // Stops a nudge or a grow when a finger takes the number over.
  const interrupt = useRef<(() => void) | null>(null);
  const scrub = useScrub(final, values, setValues, setActive, knobs, interrupt);

  useEffect(() => {
    if (!final || final.knobs.length === 0) return;
    const base = final.knobs.map((knob) => knob.value);
    const written = base[0]!;
    const from = GROW_FROM[final.name];
    const animate = (
      kind: 'nudge' | 'grow',
      ms: number,
      curve: (t: number) => number
    ) => {
      setActive(0);
      setMotion(kind);
      const cancel = playFirst(base, ms, curve, (next) => {
        knobs.value = next ?? base;
        setValues(next);
        if (next) return;
        interrupt.current = null;
        setActive(-1);
        setMotion(null);
      });
      interrupt.current = () => {
        cancel();
        interrupt.current = null;
        knobs.value = base;
        setValues(null);
        setMotion(null);
      };
      return () => {
        cancel();
        interrupt.current = null;
      };
    };
    if (from !== undefined) {
      knobs.value = [from, ...base.slice(1)];
      return animate(
        'grow',
        GROW_MS,
        (t) => from + (written - from) * t * t * (3 - 2 * t)
      );
    }
    if (nudgedRun === run) return;
    nudgedRun = run;
    const amount = Math.max(Math.abs(written), 0.3) * 0.15;
    let stop = () => {};
    const timer = setTimeout(() => {
      stop = animate(
        'nudge',
        NUDGE_MS,
        (t) => written + amount * Math.sin(2 * Math.PI * t)
      );
    }, NUDGE_DELAY_MS);
    return () => {
      clearTimeout(timer);
      stop();
    };
  }, [final, run, knobs]);

  // The name once it is whole, so the header never shows half of one.
  const name = block.code.match(/const\s+(\w+)\s*=/)?.[1];
  const accent = name ? tintColor(name) : TEXT_SOFT;
  const underline = name ? tintColor(name, 0.45) : TEXT_SOFT;
  const typed = useTyped(
    block.isComplete ? block.code : withoutFence(block.code)
  );
  const whole = block.isComplete && typed === block.code;
  const shown = useMemo(
    () => withValues(typed, whole ? (final?.knobs ?? []) : [], values),
    [typed, whole, final, values]
  );
  const drag = useKnobDrag(shown.lines, final ? scrub.onScrub : undefined);

  return (
    <Animated.View entering={CELL_ENTER} style={styles.cell}>
      <View style={styles.header}>
        <View style={[styles.dot, { backgroundColor: accent }]} />
        {name && (
          <Animated.Text entering={FadeIn.duration(200)} style={styles.name}>
            {name}
          </Animated.Text>
        )}
        <Status
          block={block}
          preview={preview}
          compiled={compiled}
          nudging={motion === 'nudge'}
        />
        {values && !motion && (
          <Pressable onPress={scrub.reset} hitSlop={8} style={styles.toggle}>
            <Text style={styles.toggleText}>RESET</Text>
          </Pressable>
        )}
        {final && (
          <Pressable
            onPress={() => setShowWgsl((wgsl) => !wgsl)}
            hitSlop={8}
            style={[styles.toggle, showWgsl && { borderColor: accent }]}
          >
            <Text style={[styles.toggleText, showWgsl && { color: accent }]}>
              {showWgsl ? 'TS' : 'WGSL'}
            </Text>
          </Pressable>
        )}
      </View>
      {showWgsl && final ? (
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={[styles.side, styles.wgsl]}
        >
          <ScrollView nestedScrollEnabled>
            <View style={styles.code}>
              {final.wgsl.split('\n').map((line, i) => (
                <CodeLine key={i} number={i + 1} text={line} />
              ))}
            </View>
          </ScrollView>
        </ScrollView>
      ) : (
        <GestureDetector gesture={drag.gesture}>
          <Animated.View layout={LINE_GROW} style={[styles.side, styles.code]}>
            <Text
              style={[styles.line, styles.probe]}
              onLayout={drag.onProbeLayout}
            >
              {PROBE}
            </Text>
            {shown.lines.map((line, i) => (
              <CodeLine
                key={i}
                number={i + 1}
                text={line.text}
                knobs={final ? line.knobs : undefined}
                knobsKey={final ? line.key : undefined}
                active={
                  line.knobs.some((knob) => knob.index === active) ? active : -1
                }
                accent={accent}
                underline={underline}
                caret={!whole && i === shown.lines.length - 1}
              />
            ))}
          </Animated.View>
        </GestureDetector>
      )}
      {!(compiled && !compiled.ok) && (
        <Animated.View
          layout={LINE_GROW}
          style={[styles.side, styles.foot, styles.stage]}
        >
          <Backdrop />
          {!solid && (
            <Animated.Text
              key={
                block.isComplete
                  ? 'compiling'
                  : unfinished
                    ? 'unfinished'
                    : 'waiting'
              }
              entering={FadeIn.duration(200)}
              exiting={FadeOut.duration(150)}
              style={styles.stageHint}
            >
              {block.isComplete
                ? 'compiling…'
                : unfinished
                  ? 'compiles once the block is whole'
                  : 'compiles as the code arrives'}
            </Animated.Text>
          )}
          <SolidView
            wgsl={solid?.wgsl ?? null}
            tint={tintFor(solid?.name ?? name ?? '')}
            knobs={knobs}
            probe={probe}
            onProbe={final ? onProbe : undefined}
            style={StyleSheet.absoluteFill}
          />
          {hit && final && (
            <Animated.View
              key={hit.at}
              entering={FadeIn.duration(200)}
              style={styles.cpuChip}
            >
              <Text style={styles.readingText}>
                {final.name}(p) on the CPU{' '}
                <Text style={styles.readingValue}>{hit.ms.toFixed(1)} ms</Text>
              </Text>
            </Animated.View>
          )}
          {motion && final && values && (
            <Animated.View
              entering={FadeIn.duration(250)}
              exiting={FadeOut.duration(400)}
              style={styles.reading}
            >
              <Text style={styles.readingText}>
                {readingOf(block.code, final.knobs[0]!)}
                <Text style={styles.readingValue}>{values[0]!.toFixed(2)}</Text>
              </Text>
            </Animated.View>
          )}
        </Animated.View>
      )}
      {compiled && !compiled.ok && (
        <View style={[styles.side, styles.foot, styles.error]}>
          <Text style={styles.errorText}>{compiled.error}</Text>
        </View>
      )}
    </Animated.View>
  );
}

type LineKnob = { index: number; col: number; length: number };
type ShownLine = { text: string; knobs: LineKnob[]; key: string };

// The code with every dragged number as it stands now, and where each number
// sits on its line.
function withValues(code: string, knobs: Knob[], values: number[] | null) {
  let text = '';
  let at = 0;
  const ranges: { index: number; start: number; end: number }[] = [];
  knobs.forEach((knob, index) => {
    const raw = code.slice(knob.start, knob.end);
    const value = values?.[index] ?? knob.value;
    const shown = value === knob.value ? raw : format(value, raw);
    text += code.slice(at, knob.start);
    ranges.push({ index, start: text.length, end: text.length + shown.length });
    text += shown;
    at = knob.end;
  });
  text += code.slice(at);
  const lines: ShownLine[] = [];
  let start = 0;
  for (const line of text.split('\n')) {
    const end = start + line.length;
    const inLine = ranges
      .filter((range) => range.start >= start && range.end <= end)
      .map((range) => ({
        index: range.index,
        col: range.start - start,
        length: range.end - range.start,
      }));
    lines.push({
      text: line,
      knobs: inLine,
      key: inLine
        .map((knob) => `${knob.index}:${knob.col}:${knob.length}`)
        .join(','),
    });
    start = end + 1;
  }
  return { lines };
}

// Eases one number from 0 to 1, straight into the shader: no render.
function playSlot(slot: number, ms: number, knobs: { value: number[] }) {
  let frame = 0;
  let start = 0;
  const step = (now: number) => {
    start ||= now;
    const t = Math.min((now - start) / ms, 1);
    const next = knobs.value.slice();
    next[slot] = 1 - (1 - t) ** 3;
    knobs.value = next;
    if (t < 1) frame = requestAnimationFrame(step);
  };
  frame = requestAnimationFrame(step);
  return () => cancelAnimationFrame(frame);
}

type Hit = { point: [number, number, number]; ms: number; at: number };

// Marches a ray through the solid on the CPU, with the block's own function
// and the numbers the GPU is drawing it with, as the shader does.
function probeOnCpu(
  solid: Solid,
  values: number[],
  ray: number[],
  time: number
): Hit | null {
  const started = performance.now();
  const knobs = Array.from({ length: KNOBS / 4 }, (_, i) =>
    d.vec4f(
      values[i * 4] ?? 0,
      values[i * 4 + 1] ?? 0,
      values[i * 4 + 2] ?? 0,
      values[i * 4 + 3] ?? 0
    )
  );
  const sdf = onCpu(solid.shape, { __knobs: knobs });
  const [ox, oy, oz, dx, dy, dz] = ray as [
    number,
    number,
    number,
    number,
    number,
    number,
  ];
  const radius = RADIUS * 1.3;
  const b = ox * dx + oy * dy + oz * dz;
  const disc = b * b - (ox * ox + oy * oy + oz * oz - radius * radius);
  if (disc < 0) return null;
  let t = Math.max(-b - Math.sqrt(disc), 0);
  const far = -b + Math.sqrt(disc);
  for (let i = 0; i < 110 && t < far; i++) {
    const point: [number, number, number] = [
      ox + dx * t,
      oy + dy * t,
      oz + dz * t,
    ];
    let h: number;
    try {
      h = sdf(d.vec3f(...point), time);
    } catch {
      return null;
    }
    if (h < 0.0005 * t) {
      return { point, ms: performance.now() - started, at: started };
    }
    t += h * 0.85;
  }
  return null;
}

// Moves the first number along `curve`, from 0 to 1 over `ms`, then hands
// back null once it is done.
function playFirst(
  base: number[],
  ms: number,
  curve: (t: number) => number,
  apply: (next: number[] | null) => void
) {
  let frame = 0;
  let start = 0;
  const step = (now: number) => {
    start ||= now;
    const t = Math.min((now - start) / ms, 1);
    if (t === 1) return apply(null);
    const next = base.slice();
    next[0] = curve(t);
    apply(next);
    frame = requestAnimationFrame(step);
  };
  frame = requestAnimationFrame(step);
  return () => cancelAnimationFrame(frame);
}

// The code as typed so far: it catches up with what has streamed in over a
// few frames, a couple of characters at a time.
function useTyped(code: string) {
  const [length, setLength] = useState(0);
  useEffect(() => {
    if (length >= code.length) return;
    const frame = requestAnimationFrame(() =>
      setLength((typed) =>
        Math.min(
          code.length,
          typed + Math.max(2, Math.ceil((code.length - typed) / TYPE_FRAMES))
        )
      )
    );
    return () => cancelAnimationFrame(frame);
  }, [length, code.length]);
  return length >= code.length ? code : code.slice(0, length);
}

// The closing fence arrives a few characters at a time before the block is
// whole; it is never code, so it never shows.
function withoutFence(code: string) {
  return code.replace(/\n[ \t]*`[^\n]*$/, '');
}

// What the stage shows before a moving number: what it is assigned to,
// `n = ` in `const n = 8 + ...`, or else the code before it on its line,
// `std.length(p) - ` in `return std.length(p) - 1;`.
function readingOf(code: string, knob: Knob) {
  const line = code.slice(code.lastIndexOf('\n', knob.start) + 1, knob.start);
  const name = line.match(/(\w+)\s*=\s*$/)?.[1];
  return name ? `${name} = ` : line.trim().replace(/^return\s+/, '') + ' ';
}

function format(value: number, raw: string) {
  const decimals = Math.max(raw.split('.')[1]?.length ?? 0, 2);
  return value.toFixed(decimals);
}

function useScrub(
  solid: Solid | null,
  values: number[] | null,
  setValues: (values: number[] | null) => void,
  setActive: (index: number) => void,
  knobs: { value: number[] },
  interrupt: { current: (() => void) | null }
) {
  const drag = useRef<{ base: number[]; index: number } | null>(null);
  const current = values ?? solid?.knobs.map((knob) => knob.value) ?? [];
  const latest = useRef(current);
  latest.current = current;

  const onScrub = useCallback(
    (index: number, phase: 'start' | 'move' | 'end', dx = 0) => {
      if (!solid) return;
      if (phase === 'start') {
        const moving = interrupt.current;
        moving?.();
        drag.current = {
          base: moving
            ? solid.knobs.map((knob) => knob.value)
            : latest.current.slice(),
          index,
        };
        setActive(index);
        return;
      }
      if (phase === 'end') {
        drag.current = null;
        setActive(-1);
        return;
      }
      const state = drag.current;
      if (!state) return;
      const written = solid.knobs[index]!.value;
      const step = Math.max(Math.abs(written), 0.3) / SCRUB_PT;
      const next = state.base.slice();
      next[index] = state.base[index]! + dx * step;
      knobs.value = next;
      setValues(next);
    },
    [solid, knobs, setValues, setActive, interrupt]
  );

  const reset = useCallback(() => {
    if (!solid) return;
    knobs.value = solid.knobs.map((knob) => knob.value);
    setValues(null);
  }, [solid, knobs, setValues]);

  return { onScrub, reset };
}

type Scrub = ReturnType<typeof useScrub>['onScrub'];

// One drag for every number in the code: the font is monospaced, so where a
// finger lands says which number it is on.
function useKnobDrag(lines: ShownLine[], onScrub?: Scrub) {
  const charWidth = useRef(0);
  const latest = useRef({ lines, onScrub });
  latest.current = { lines, onScrub };
  const gesture = useMemo(() => {
    // Each callback becomes a worklet with its own copy of plain variables,
    // so the drag keeps its number in an object they share.
    const drag = { index: -1 };
    return Gesture.Pan()
      .runOnJS(true)
      .activeOffsetX([-3, 3])
      .failOffsetY([-10, 10])
      .onBegin((e) => {
        drag.index = knobAt(latest.current.lines, e.x, e.y, charWidth.current);
      })
      .onStart(() => {
        if (drag.index !== -1) latest.current.onScrub?.(drag.index, 'start');
      })
      .onUpdate((e) => {
        if (drag.index !== -1)
          latest.current.onScrub?.(drag.index, 'move', e.translationX);
      })
      .onFinalize(() => {
        if (drag.index !== -1) latest.current.onScrub?.(drag.index, 'end');
        drag.index = -1;
      });
  }, []);
  const onProbeLayout = useCallback((e: LayoutChangeEvent) => {
    charWidth.current = e.nativeEvent.layout.width / PROBE.length;
  }, []);
  return { gesture, onProbeLayout };
}

function knobAt(lines: ShownLine[], x: number, y: number, charWidth: number) {
  const line = lines[Math.floor(y / LINE_HEIGHT)];
  if (!line || !charWidth) return -1;
  const col = (x - GUTTER) / charWidth;
  const knob = line.knobs.find(
    (k) => col >= k.col - 0.6 && col <= k.col + k.length + 0.6
  );
  return knob?.index ?? -1;
}

type CodeLineProps = {
  number: number;
  text: string;
  knobs?: LineKnob[];
  knobsKey?: string;
  active?: number;
  accent?: string;
  underline?: string;
  caret?: boolean;
};

// One line of code. Only the line being written changes as the code streams,
// so every other line skips its render. Its numbers are spans of the same
// text, so they cost nothing to mount.
const CodeLine = memo(
  function CodeLine({
    number,
    text,
    knobs,
    active = -1,
    accent,
    underline,
    caret,
  }: CodeLineProps) {
    const parts: ReactNode[] = [];
    let at = 0;
    for (const knob of knobs ?? []) {
      parts.push(
        <HighlightedLine key={`t${at}`} line={text.slice(at, knob.col)} />,
        <Text
          key={`k${knob.index}`}
          style={[
            styles.number,
            { textDecorationColor: underline },
            knob.index === active && [
              styles.numberActive,
              { backgroundColor: accent },
            ],
          ]}
        >
          {text.slice(knob.col, knob.col + knob.length)}
        </Text>
      );
      at = knob.col + knob.length;
    }
    parts.push(<HighlightedLine key="end" line={text.slice(at)} />);
    return (
      <View style={styles.row}>
        <Text style={styles.gutter}>{number}</Text>
        <Text style={styles.line}>
          {parts}
          {caret && <Caret at={text.length} />}
        </Text>
      </View>
    );
  },
  (a, b) =>
    a.text === b.text &&
    a.caret === b.caret &&
    a.active === b.active &&
    a.knobsKey === b.knobsKey &&
    a.accent === b.accent &&
    a.underline === b.underline
);

function Status({
  block,
  preview,
  compiled,
  nudging,
}: {
  block: MarkdownCodeBlock;
  preview: Solid | null;
  compiled: Compiled | null;
  nudging: boolean;
}) {
  let text = 'writing…';
  let color = TEXT_SOFT;
  if (!block.isComplete && preview) {
    text = 'live';
    color = '#9D7BFF';
  }
  if (block.isComplete && !compiled) text = 'compiling…';
  if (compiled?.ok) {
    text = `→ WGSL in ${Math.max(1, Math.round(compiled.ms))} ms`;
    color = '#7BE0A6';
  }
  if (compiled && !compiled.ok) {
    text = 'did not compile';
    color = '#FF6B7A';
  }
  if (nudging) {
    text = 'drag a number ↔';
    color = '#9D7BFF';
  }
  return (
    <Animated.Text
      key={text}
      entering={FadeIn.duration(200)}
      style={[styles.status, { color }]}
    >
      {text}
    </Animated.Text>
  );
}

// The raymarcher's backdrop, drawn the same way, so the canvas fades in over
// its own background.
const BACKDROP_STOPS = [
  ['0', '#272637'],
  ['0.247', '#252434'],
  ['0.495', '#1F1E2C'],
  ['0.707', '#191A24'],
  ['1', '#14151D'],
] as const;

function Backdrop() {
  return (
    <Svg style={StyleSheet.absoluteFill}>
      <Defs>
        <RadialGradient id="stage" cx="0.5" cy="0.5" r="0.7071">
          {BACKDROP_STOPS.map(([offset, color]) => (
            <Stop key={offset} offset={offset} stopColor={color} />
          ))}
        </RadialGradient>
      </Defs>
      <Rect width="100%" height="100%" fill="url(#stage)" />
    </Svg>
  );
}

// Solid while code arrives and blinking once it stops, like an editor's.
function Caret({ at }: { at: number }) {
  const blink = useSharedValue(1);
  useEffect(() => {
    blink.value = 1;
    blink.value = withDelay(
      CARET_REST_MS,
      withRepeat(
        withSequence(
          withTiming(0, { duration: 420 }),
          withTiming(1, { duration: 420 })
        ),
        -1
      )
    );
  }, [at, blink]);
  const style = useAnimatedStyle(() => ({ opacity: blink.value }));
  return <Animated.Text style={[styles.caret, style]}>▍</Animated.Text>;
}

const styles = StyleSheet.create({
  // The cell itself is drawn by its parts, so the card's bottom edge moves
  // with the stage as a line opens up, rather than with the cell's height.
  cell: {
    marginTop: 4,
    marginBottom: 22,
  },
  header: {
    backgroundColor: PANEL,
    borderColor: RULE,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderLeftWidth: StyleSheet.hairlineWidth,
    borderRightWidth: StyleSheet.hairlineWidth,
    borderTopLeftRadius: CARD_RADIUS,
    borderTopRightRadius: CARD_RADIUS,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingTop: 10,
    paddingBottom: 8,
    gap: 8,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  name: {
    fontFamily: FONTS.monoMedium,
    fontSize: 13,
    color: '#E7E5F2',
  },
  status: {
    flex: 1,
    fontFamily: FONTS.mono,
    fontSize: 11.5,
    textAlign: 'right',
  },
  toggle: {
    borderWidth: 1,
    borderColor: RULE,
    borderRadius: 6,
    paddingHorizontal: 7,
    paddingVertical: 2,
  },
  toggleText: {
    fontFamily: FONTS.monoMedium,
    fontSize: 10.5,
    color: TEXT_SOFT,
    letterSpacing: 0.5,
  },
  side: {
    backgroundColor: PANEL,
    borderColor: RULE,
    borderLeftWidth: StyleSheet.hairlineWidth,
    borderRightWidth: StyleSheet.hairlineWidth,
  },
  foot: {
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomLeftRadius: CARD_RADIUS,
    borderBottomRightRadius: CARD_RADIUS,
    overflow: 'hidden',
  },
  wgsl: {
    maxHeight: 260,
  },
  code: {
    paddingBottom: 12,
    paddingRight: 8,
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
  },
  gutter: {
    width: GUTTER,
    paddingRight: 8,
    textAlign: 'right',
    fontFamily: FONTS.mono,
    fontSize: 11,
    lineHeight: LINE_HEIGHT,
    color: '#45425E',
  },
  line: {
    fontFamily: FONTS.mono,
    fontSize: 11,
    lineHeight: LINE_HEIGHT,
    color: '#E7E5F2',
  },
  probe: {
    position: 'absolute',
    opacity: 0,
  },
  number: {
    color: '#FFB86B',
    textDecorationLine: 'underline',
  },
  numberActive: {
    color: '#0B0B14',
  },
  caret: {
    color: '#9D7BFF',
  },
  stage: {
    aspectRatio: 1.1,
    alignItems: 'center',
    justifyContent: 'center',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: RULE,
  },
  reading: {
    position: 'absolute',
    left: 12,
    bottom: 12,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 6,
    backgroundColor: 'rgba(11, 11, 20, 0.7)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: RULE,
  },
  readingText: {
    fontFamily: FONTS.mono,
    fontSize: 12,
    color: '#E7E5F2',
  },
  cpuChip: {
    position: 'absolute',
    right: 12,
    bottom: 12,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 6,
    backgroundColor: 'rgba(11, 11, 20, 0.7)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: RULE,
  },
  readingValue: {
    color: '#FFB86B',
  },
  stageHint: {
    fontFamily: FONTS.mono,
    fontSize: 11.5,
    color: '#5E5A7E',
  },
  error: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#5A2433',
    backgroundColor: '#1E0E14',
    padding: 12,
  },
  errorText: {
    fontFamily: FONTS.mono,
    fontSize: 11.5,
    lineHeight: 17,
    color: '#FF8A96',
  },
});
