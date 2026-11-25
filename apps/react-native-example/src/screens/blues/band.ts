import { makeMutable } from 'react-native-reanimated';
import { engine, STEPS_PER_BAR, type Loop } from './audio';
import {
  boogieLine,
  chordMask,
  compVoicing,
  parseChord,
  type Chord,
} from './theory';

// The twelve bars the lesson wrote, shared by the progression and the jam:
// whichever plays, the band plays this tune.
const DEFAULT = 'C7 C7 C7 C7 F7 F7 C7 C7 G7 F7 C7 G7';

let tune: Chord[] = parse(DEFAULT);

// Each bar's chord tones as a pitch-class mask, so a keyboard on the UI
// thread can ring the notes that fit the bar being played.
export const tuneMasks = makeMutable<number[]>(tune.map(chordMask));

function parse(text: string) {
  return text
    .split(/[\s|]+/)
    .map(parseChord)
    .filter((c): c is Chord => c !== null);
}

export function setTune(chords: Chord[]) {
  if (chords.length === 0) return;
  tune = chords;
  tuneMasks.value = chords.map(chordMask);
}

export function tuneSymbol(bar: number) {
  return tune[bar]?.symbol ?? null;
}

export const BLUES_LOOP = 'blues';

/**
 * The band on the tune: a boogie bass on every swung eighth, the piano
 * comping on the two and the and-of-three, and the groove on the kit.
 * `drums: false` leaves the reader the beat to keep.
 */
export function bluesLoop(drums = true): Loop {
  const bars = tune;
  return {
    id: BLUES_LOOP,
    steps: bars.length * STEPS_PER_BAR,
    onStep: (step, at) => {
      const chord = bars[Math.floor(step / STEPS_PER_BAR)]!;
      const sub = step % STEPS_PER_BAR;
      engine.bass(boogieLine(chord)[sub]!, at, 0.24, sub % 2 ? 0.6 : 0.85);
      if (sub === 2 || sub === 5) {
        const len = sub === 2 ? 0.3 : 0.5;
        compVoicing(chord).forEach((midi, i) =>
          engine.piano(midi, at + i * 0.008, len, 0.55)
        );
      }
      if (drums) engine.playGrooveStep(sub, at);
    },
  };
}
