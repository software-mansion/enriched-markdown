// Just enough music theory for the lesson: note names, chord symbols and the
// blues scale, all as MIDI numbers (middle C, C4, is 60).

const LETTERS: Record<string, number> = {
  C: 0,
  D: 2,
  E: 4,
  F: 5,
  G: 7,
  A: 9,
  B: 11,
};

const FLAT_NAMES = [
  'C',
  'D♭',
  'D',
  'E♭',
  'E',
  'F',
  'G♭',
  'G',
  'A♭',
  'A',
  'B♭',
  'B',
];

/** `C4`, `Eb4`, `F#3`; without an octave, the one from middle C up. */
export function parseNote(text: string): number | null {
  const match = /^([A-Ga-g])(#|b|♭|♯)?(-?\d)?$/.exec(text.trim());
  if (!match) return null;
  const letter = LETTERS[match[1]!.toUpperCase()]!;
  const accidental =
    match[2] === '#' || match[2] === '♯'
      ? 1
      : match[2] === 'b' || match[2] === '♭'
        ? -1
        : 0;
  const octave = match[3] === undefined ? 4 : Number(match[3]);
  return 12 * (octave + 1) + letter + accidental;
}

export function pitchClass(midi: number) {
  return ((midi % 12) + 12) % 12;
}

export function noteName(midi: number, octave = false) {
  const name = FLAT_NAMES[pitchClass(midi)]!;
  return octave ? `${name}${Math.floor(midi / 12) - 1}` : name;
}

export function isBlack(midi: number) {
  return [1, 3, 6, 8, 10].includes(pitchClass(midi));
}

const QUALITIES: Record<string, number[]> = {
  '': [0, 4, 7],
  'm': [0, 3, 7],
  '7': [0, 4, 7, 10],
  'm7': [0, 3, 7, 10],
  'maj7': [0, 4, 7, 11],
};

export interface Chord {
  symbol: string;
  root: number;
  intervals: number[];
}

/** `C`, `Cm`, `F7`, `Bbmaj7`. */
export function parseChord(symbol: string): Chord | null {
  const match = /^([A-G])(#|b)?(maj7|m7|m|7)?$/.exec(symbol.trim());
  if (!match) return null;
  const root = parseNote(match[1]! + (match[2] ?? '') + '3');
  if (root === null) return null;
  return {
    symbol: symbol.trim(),
    root,
    intervals: QUALITIES[match[3] ?? '']!,
  };
}

/** The chord in root position from `octave`, for a keyboard to show. */
export function chordNotes(chord: Chord, octave = 4) {
  const root = 12 * (octave + 1) + pitchClass(chord.root);
  return chord.intervals.map((i) => root + i);
}

/** The chord's pitch classes as a 12-bit mask, for the UI thread. */
export function chordMask(chord: Chord) {
  return chord.intervals.reduce(
    (mask, i) => mask | (1 << pitchClass(chord.root + i)),
    0
  );
}

// A pianist's left hand behind a band: no root (the bass has it), the third,
// the sixth and the seventh, kept in the middle of the keyboard so the comp
// moves as little as it can from chord to chord.
export function compVoicing(chord: Chord) {
  const dominant = chord.intervals.includes(10);
  const tones = dominant ? [4, 9, 10] : chord.intervals.slice(1).concat(12);
  return tones
    .map((i) => {
      let midi = chord.root + i;
      while (midi < 52) midi += 12;
      while (midi >= 65) midi -= 12;
      return midi;
    })
    .sort((a, b) => a - b);
}

// The boogie bass line under a dominant chord, a note per swung eighth:
// root, third, fifth, sixth, flat seven, and back down.
export function boogieLine(chord: Chord) {
  const root = 36 + pitchClass(chord.root);
  return [0, 4, 7, 9, 10, 9, 7, 4].map((i) => root + i);
}

export const BLUES_SCALE = [0, 3, 5, 6, 7, 10];
// The flat five: the note the blues bends into.
export const BLUE_NOTE = 6;

export function inScale(midi: number, tonic: number, scale: number[]) {
  return scale.includes(pitchClass(midi - tonic));
}

/** The chord's Roman numeral in `key`: I, IV and V carry the blues. */
export function numeral(chord: Chord, key: number) {
  const degree = pitchClass(chord.root - key);
  const base =
    { 0: 'I', 2: 'II', 4: 'III', 5: 'IV', 7: 'V', 9: 'VI', 10: '♭VII' }[
      degree
    ] ?? '?';
  return chord.intervals.includes(10) ? `${base}7` : base;
}
