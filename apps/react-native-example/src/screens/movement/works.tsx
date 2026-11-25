import { createContext, memo, useContext, type ReactNode } from 'react';
import {
  Image,
  StyleSheet,
  View,
  type ImageStyle,
  type StyleProp,
} from 'react-native';
import Animated, {
  useAnimatedStyle,
  type SharedValue,
} from 'react-native-reanimated';
import { BEATS_PER_SECOND, clock } from './clock';
import { PART_IDS, type PartId } from './movementMarkdown';
import { DISC } from './theme';

// Every instrument is drawn once, on a disc of this size, and only ever
// scaled: a shared element transition animates a transform smoothly, while a
// change of width would leave the drawing behind until the flight lands.
export const WORKS_SIZE = 320;
const C = WORKS_SIZE / 2;

// The time the instruments under it read. A layout that is out of sight hands
// down a stopped one, so its works cost nothing until it is shown again.
export const WorksTime = createContext<SharedValue<number>>(clock);

// The works are baked images: a plate bed, the turning parts, and the bridges
// and jewels that stand over them. Only transforms move, on the UI thread.
// `scripts/movement-textures` draws them; its geometry mirrors this file's.
const ART = {
  barrelBed: require('./assets/barrel_bed.webp'),
  barrelWheel: require('./assets/barrel_wheel.webp'),
  barrelSpring: require('./assets/barrel_spring.webp'),
  barrelTop: require('./assets/barrel_top.webp'),
  trainBed: require('./assets/train_bed.webp'),
  trainA: require('./assets/train_a.webp'),
  trainB: require('./assets/train_b.webp'),
  trainC: require('./assets/train_c.webp'),
  trainTop: require('./assets/train_top.webp'),
  escapementBed: require('./assets/escapement_bed.webp'),
  escapementWheel: require('./assets/escapement_wheel.webp'),
  escapementFork: require('./assets/escapement_fork.webp'),
  escapementTop: require('./assets/escapement_top.webp'),
  balanceBed: require('./assets/balance_bed.webp'),
  balanceWheel: require('./assets/balance_wheel.webp'),
  balanceSpring: require('./assets/balance_spring.webp'),
  balanceTop: require('./assets/balance_top.webp'),
  rateBed: require('./assets/rate_bed.webp'),
  ratePaper: require('./assets/rate_paper.webp'),
  rateTop: require('./assets/rate_top.webp'),
  secondsBed: require('./assets/seconds_bed.webp'),
  secondsHand: require('./assets/seconds_hand.webp'),
  secondsShadow: require('./assets/seconds_shadow.webp'),
  rim: require('./assets/rim.webp'),
  glass: require('./assets/glass.webp'),
  band: require('./assets/band.webp'),
} as const;

type Art = (typeof ART)[keyof typeof ART];

function gearBox(pitch: number, teeth: number) {
  return Math.ceil((pitch + (2 * pitch) / teeth + 2) * 2);
}

// A layer that fills the disc and stays put.
function Still({ art }: { art: Art }) {
  return <Image source={art} style={styles.still} fadeDuration={0} />;
}

// A part that turns about its own centre, placed by that centre.
function Turning({
  art,
  cx,
  cy,
  box,
  rotation,
}: {
  art: Art;
  cx: number;
  cy: number;
  box: number;
  rotation: ReturnType<typeof useAnimatedStyle>;
}) {
  return (
    <Animated.Image
      source={art}
      fadeDuration={0}
      style={[
        styles.turning,
        { left: cx - box / 2, top: cy - box / 2, width: box, height: box },
        rotation as StyleProp<ImageStyle>,
      ]}
    />
  );
}

function Wheel({
  art,
  cx,
  cy,
  teeth,
  pitch,
  speed,
  phase,
}: {
  art: Art;
  cx: number;
  cy: number;
  teeth: number;
  pitch: number;
  speed: number;
  phase: number;
}) {
  const time = useContext(WorksTime);
  const rotation = useAnimatedStyle(() => ({
    transform: [{ rotate: `${phase + speed * time.value}rad` }],
  }));
  return (
    <Turning
      art={art}
      cx={cx}
      cy={cy}
      box={gearBox(pitch, teeth)}
      rotation={rotation}
    />
  );
}

// I. The barrel: one slow drum, the spring wound inside it. Hurried along, as
// the notes admit: at its real pace nothing would be seen to move in the half
// second a plate is in the air.
const SPRING_SPEED = 1.1;

function Barrel() {
  const time = useContext(WorksTime);
  const spring = useAnimatedStyle(() => ({
    transform: [{ rotate: `${-SPRING_SPEED * time.value}rad` }],
  }));
  return (
    <>
      <Still art={ART.barrelBed} />
      <Wheel
        art={ART.barrelWheel}
        cx={C}
        cy={C}
        teeth={54}
        pitch={112}
        speed={0.3}
        phase={0}
      />
      <Turning
        art={ART.barrelSpring}
        cx={C}
        cy={C}
        box={120}
        rotation={spring}
      />
      <Still art={ART.barrelTop} />
    </>
  );
}

// II. The going train: three wheels in mesh. Each wheel's angle follows from
// the one that drives it, so the teeth stay engaged at any instant.
const TRAIN = (() => {
  const a = { cx: 112, cy: 196, teeth: 36, pitch: 76, speed: 0.42, phase: 0 };
  const mesh = (from: typeof a, teeth: number, direction: number): typeof a => {
    const pitch = (from.pitch / from.teeth) * teeth;
    const reach = from.pitch + pitch;
    return {
      cx: from.cx + reach * Math.cos(direction),
      cy: from.cy + reach * Math.sin(direction),
      teeth,
      pitch,
      speed: (-from.speed * from.teeth) / teeth,
      phase:
        direction +
        Math.PI +
        Math.PI / teeth -
        ((from.phase - direction) * from.teeth) / teeth,
    };
  };
  const b = mesh(a, 24, -0.95);
  const c = mesh(b, 15, 0.75);
  return [a, b, c];
})();

function Train() {
  return (
    <>
      <Still art={ART.trainBed} />
      <Wheel art={ART.trainA} {...TRAIN[0]!} />
      <Wheel art={ART.trainB} {...TRAIN[1]!} />
      <Wheel art={ART.trainC} {...TRAIN[2]!} />
      <Still art={ART.trainTop} />
    </>
  );
}

// The escapement's beat: the wheel and the fork snap over at the start of each
// beat, then rest. `beat` counts whole beats, `snap` runs 0 → 1 within one.
function beatOf(time: number) {
  'worklet';
  const beats = time * BEATS_PER_SECOND;
  const beat = Math.floor(beats);
  const part = Math.min(1, (beats - beat) / 0.22);
  const snap = 1 - (1 - part) * (1 - part) * (1 - part);
  return { beat, snap, beats };
}

// III. The escapement: a 15-tooth club wheel, and the fork that gates it.
const ESCAPE_STEP = (Math.PI * 2) / 15;

function Escapement() {
  const time = useContext(WorksTime);
  const wheel = useAnimatedStyle(() => {
    const { beat, snap } = beatOf(time.value);
    return {
      transform: [{ rotate: `${((beat + snap) * ESCAPE_STEP) / 2}rad` }],
    };
  });
  const fork = useAnimatedStyle(() => {
    const { beat, snap } = beatOf(time.value);
    const side = beat % 2 === 0 ? 1 : -1;
    return { transform: [{ rotate: `${side * (2 * snap - 1) * 7.5}deg` }] };
  });
  return (
    <>
      <Still art={ART.escapementBed} />
      <Turning
        art={ART.escapementWheel}
        cx={C}
        cy={118}
        box={148}
        rotation={wheel}
      />
      <Turning
        art={ART.escapementFork}
        cx={C}
        cy={214}
        box={200}
        rotation={fork}
      />
      <Still art={ART.escapementTop} />
    </>
  );
}

// IV. The balance: the rim swings a beat each way, the hairspring winds and
// unwinds with it.
function Balance() {
  const time = useContext(WorksTime);
  const rim = useAnimatedStyle(() => {
    const { beats } = beatOf(time.value);
    return {
      transform: [
        { rotate: `${Math.sin(Math.PI * beats + Math.PI / 2) * -140}deg` },
      ],
    };
  });
  const spring = useAnimatedStyle(() => {
    const { beats } = beatOf(time.value);
    const swing = Math.sin(Math.PI * beats + Math.PI / 2);
    return {
      transform: [{ rotate: `${swing * -46}deg` }, { scale: 1 + swing * 0.07 }],
    };
  });
  return (
    <>
      <Still art={ART.balanceBed} />
      <Turning art={ART.balanceWheel} cx={C} cy={C} box={236} rotation={rim} />
      <Turning
        art={ART.balanceSpring}
        cx={C}
        cy={C}
        box={104}
        rotation={spring}
      />
      <Still art={ART.balanceTop} />
    </>
  );
}

// V. The rate trace: a timing machine's screen, two rows of ticks sliding by.
const TRACE_PERIOD = 96;

function Rate() {
  const time = useContext(WorksTime);
  const paper = useAnimatedStyle(() => ({
    transform: [
      // Rotated first, so the trace slides along its own tilted rows and the
      // wrap from one period to the next cannot be seen.
      { rotate: '-7deg' },
      { translateX: -((time.value * 26) % TRACE_PERIOD) },
    ],
  }));
  return (
    <>
      <Still art={ART.rateBed} />
      <Animated.Image
        source={ART.ratePaper}
        fadeDuration={0}
        style={[styles.paper, paper]}
      />
      <Still art={ART.rateTop} />
    </>
  );
}

// VI. The small seconds: the phone's own second, a fifth at a time. The hand
// stands off the dial, so its shadow turns with it, away from the lamp.
function Seconds() {
  const time = useContext(WorksTime);
  const hand = useAnimatedStyle(() => ({
    transform: [{ rotate: `${(Math.floor(time.value * 5) / 5) * 6}deg` }],
  }));
  return (
    <>
      <Still art={ART.secondsBed} />
      <Turning
        art={ART.secondsShadow}
        cx={C + 4}
        cy={C + 6}
        box={260}
        rotation={hand}
      />
      <Turning art={ART.secondsHand} cx={C} cy={C} box={260} rotation={hand} />
    </>
  );
}

const WORKS: Record<PartId, () => ReactNode> = {
  barrel: Barrel,
  train: Train,
  escapement: Escapement,
  balance: Balance,
  rate: Rate,
  seconds: Seconds,
};

const BAND_TRAVEL = 760;

export const Works = memo(function Works({ id }: { id: PartId }) {
  const Drawing = WORKS[id];
  const time = useContext(WorksTime);
  const lead = PART_IDS.indexOf(id) * 130;
  // The reflection drifts across the crystal, as if the bench lamp swayed,
  // and a bar of its light crosses the works every so often.
  const glint = useAnimatedStyle(() => ({
    transform: [{ rotate: `${Math.sin(time.value * 0.45) * 18}deg` }],
  }));
  const band = useAnimatedStyle(() => ({
    transform: [
      {
        translateX: ((time.value * 46 + lead) % BAND_TRAVEL) - BAND_TRAVEL / 2,
      },
    ],
  }));
  return (
    <View style={styles.works}>
      <Drawing />
      <Animated.Image
        source={ART.band}
        fadeDuration={0}
        style={[styles.still, band]}
      />
      <Animated.Image
        source={ART.glass}
        fadeDuration={0}
        style={[styles.still, glint]}
      />
      <Still art={ART.rim} />
    </View>
  );
});

const styles = StyleSheet.create({
  works: {
    width: WORKS_SIZE,
    height: WORKS_SIZE,
    borderRadius: C,
    overflow: 'hidden',
    backgroundColor: DISC,
  },
  still: {
    position: 'absolute',
    left: 0,
    top: 0,
    width: WORKS_SIZE,
    height: WORKS_SIZE,
  },
  turning: { position: 'absolute' },
  paper: {
    position: 'absolute',
    left: -TRACE_PERIOD,
    top: 0,
    width: TRACE_PERIOD * 6,
    height: WORKS_SIZE,
  },
});
