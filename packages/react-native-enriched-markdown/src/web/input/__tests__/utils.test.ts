import { graphemeLengthBefore, graphemeLengthAfter } from '../utils';

// Both natives measure a delete step by delegating to the platform, which
// steps by user-perceived character. These are the sequences where a code
// point step and a cluster step disagree, so they are the ones that decide
// whether one Backspace on web means the same as one Backspace on native.
const CLUSTERS: [name: string, cluster: string, units: number][] = [
  ['an astral emoji', '\u{1F600}', 2],
  ['an emoji with a variation selector', '❤️', 2],
  ['a combining mark', 'é', 2],
  ['a flag of two regional indicators', '\u{1F1F5}\u{1F1F1}', 4],
  ['a ZWJ family', '\u{1F468}‍\u{1F469}‍\u{1F467}', 8],
  ['a keycap sequence', '1️⃣', 3],
];

describe('grapheme stepping', () => {
  it.each(CLUSTERS)(
    'steps over %s in one move, alone in the buffer',
    (_name, cluster, units) => {
      expect(cluster).toHaveLength(units);
      expect(graphemeLengthBefore(cluster, units)).toBe(units);
      expect(graphemeLengthAfter(cluster, 0)).toBe(units);
    }
  );

  it.each(CLUSTERS)(
    'steps over %s between neighbours',
    (_name, cluster, units) => {
      const text = `a${cluster}b`;
      expect(graphemeLengthBefore(text, 1 + units)).toBe(units);
      expect(graphemeLengthAfter(text, 1)).toBe(units);
      // The neighbours are still single units, so the cluster cannot have
      // swallowed them.
      expect(graphemeLengthBefore(text, 1)).toBe(1);
      expect(graphemeLengthAfter(text, 1 + units)).toBe(1);
    }
  );

  it('reports 0 at the ends of the buffer', () => {
    expect(graphemeLengthBefore('abc', 0)).toBe(0);
    expect(graphemeLengthAfter('abc', 3)).toBe(0);
    expect(graphemeLengthBefore('', 0)).toBe(0);
    expect(graphemeLengthAfter('', 0)).toBe(0);
  });

  it('never splits a surrogate pair, wherever the pair sits', () => {
    for (const text of ['\u{1F600}', 'a\u{1F600}', '\u{1F600}a', 'a\u{1F600}a'])
      for (let position = 0; position <= text.length; position++) {
        const before = graphemeLengthBefore(text, position);
        const after = graphemeLengthAfter(text, position);
        expect(isWholeCharacters(text.slice(position - before, position))).toBe(
          true
        );
        expect(isWholeCharacters(text.slice(position, position + after))).toBe(
          true
        );
      }
  });

  // A cluster has no length limit, so the segmentation window has to widen
  // rather than cut a long one short.
  it('steps over a cluster longer than the segmentation window', () => {
    const longCluster = `e${'́'.repeat(200)}`;
    expect(graphemeLengthBefore(longCluster, longCluster.length)).toBe(
      longCluster.length
    );
    expect(graphemeLengthAfter(longCluster, 0)).toBe(longCluster.length);
  });

  it('treats a newline as its own cluster', () => {
    expect(graphemeLengthBefore('a\nb', 2)).toBe(1);
    expect(graphemeLengthAfter('a\nb', 1)).toBe(1);
  });
});

// No lone surrogate on either end: a half pair is not text, and the stores
// would carry the broken offset onwards.
function isWholeCharacters(slice: string): boolean {
  return [...slice].join('') === slice;
}
