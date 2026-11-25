import { memo } from 'react';
import Svg, { G, Polygon } from 'react-native-svg';
import { EL, EL_DIM } from '../theme';

const W = 12;
const H = 21;
const PITCH = 15;

type Points = Array<[number, number]>;

function horizontal(cy: number, x1 = 1.6, x2 = 10.4): Points {
  return [
    [x1, cy],
    [x1 + 1, cy - 1],
    [x2 - 1, cy - 1],
    [x2, cy],
    [x2 - 1, cy + 1],
    [x1 + 1, cy + 1],
  ];
}

function vertical(cx: number, y1: number, y2: number): Points {
  return [
    [cx, y1],
    [cx + 1, y1 + 1],
    [cx + 1, y2 - 1],
    [cx, y2],
    [cx - 1, y2 - 1],
    [cx - 1, y1 + 1],
  ];
}

const SEGMENTS = {
  a: horizontal(1),
  b: vertical(11, 1.6, 10),
  c: vertical(11, 11, 19.4),
  d: horizontal(20),
  e: vertical(1, 11, 19.4),
  f: vertical(1, 1.6, 10),
  g: horizontal(10.5),
  // The upright of a plus sign, above and below the bar.
  p: vertical(6, 5.5, 9.6),
  q: vertical(6, 11.4, 15.5),
};

type Segment = keyof typeof SEGMENTS;

const GLYPHS: Record<string, string> = {
  '0': 'abcdef',
  '1': 'bc',
  '2': 'abged',
  '3': 'abgcd',
  '4': 'fgbc',
  '5': 'afgcd',
  '6': 'afgedc',
  '7': 'abc',
  '8': 'abcdefg',
  '9': 'abcdfg',
  '+': 'gpq',
  '-': 'g',
  ' ': '',
};

const DIGIT_SEGMENTS: Segment[] = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
const SIGN_SEGMENTS: Segment[] = ['g', 'p', 'q'];

function points(list: Points) {
  return list.map(([x, y]) => `${x},${y}`).join(' ');
}

// Electroluminescent seven-segment digits, unlit segments faintly visible as
// on the real panel. A sign position (`+`, `-` or blank) only has its cross.
export const Segments = memo(function Segments({
  text,
  height,
  sign = false,
}: {
  text: string;
  height: number;
  sign?: boolean;
}) {
  const chars = text.split('');
  const width = (chars.length * PITCH - (PITCH - W)) * (height / H);
  return (
    <Svg
      width={width}
      height={height}
      viewBox={`-1 0 ${chars.length * PITCH - (PITCH - W) + 2} ${H + 1}`}
    >
      {chars.map((char, i) => {
        const lit = GLYPHS[char] ?? '';
        const slots = sign && i === 0 ? SIGN_SEGMENTS : DIGIT_SEGMENTS;
        return (
          <G key={i} transform={`translate(${i * PITCH + 1.2} 0) skewX(-5)`}>
            {slots.map((segment) => (
              <Polygon
                key={segment}
                points={points(SEGMENTS[segment])}
                fill={lit.includes(segment) ? EL : EL_DIM}
              />
            ))}
          </G>
        );
      })}
    </Svg>
  );
});
