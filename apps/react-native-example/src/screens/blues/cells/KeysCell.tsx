import { useCallback, useMemo, useRef, useState } from 'react';
import type { MarkdownCodeBlock } from 'react-native-enriched-markdown';
import { engine, STEP_SECONDS } from '../audio';
import { Keyboard, useHits } from '../Keyboard';
import { isBlack, noteName, parseNote } from '../theory';
import { BRASS } from '../theme';
import { Card, PlayButton, splitCode, useArrivals } from './Card';

// The keyboard a lesson block shows unless its notes need more: middle C up
// to the E above, ten white keys, big enough for a thumb.
const LOW = 60;
const HIGH = 76;

/** A ```keys block's notes: `C4 E4 G4` one after another, `C4+E4+G4` at once. */
export function parseGroups(words: string[]) {
  return words
    .map((word) =>
      word
        .split('+')
        .map(parseNote)
        .filter((m): m is number => m !== null)
    )
    .filter((group) => group.length > 0);
}

export function keyRange(notes: number[]) {
  let low = Math.min(LOW, ...notes);
  let high = Math.max(HIGH, ...notes);
  // Start and end on white keys, so the keyboard has clean edges.
  while (isBlack(low)) low--;
  while (isBlack(high)) high++;
  return { low, high };
}

/**
 * A ```keys block: the notes it names, on a keyboard. Each note sounds and
 * lights the moment the answer writes it; once the block is whole, ▶ plays
 * it back, and the keyboard is the reader's to play.
 */
export function KeysCell({ block }: { block: MarkdownCodeBlock }) {
  const { caption, body } = splitCode(block.code);
  // Fences stream a line at a time, so every line that has arrived is whole.
  const words = body.join(' ').split(/\s+/).filter(Boolean);
  const groups = useMemo(() => parseGroups(words), [words.join(' ')]); // eslint-disable-line react-hooks/exhaustive-deps
  const { hits, flash } = useHits();
  const [playing, setPlaying] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const all = groups.flat();
  // The range is set by the whole block once it is known, and only grows
  // while it streams, so the keys never shift under a note being written.
  const range = useRef(keyRange(all));
  const next = keyRange(all);
  if (next.low < range.current.low || next.high > range.current.high) {
    range.current = {
      low: Math.min(next.low, range.current.low),
      high: Math.max(next.high, range.current.high),
    };
  }

  const strike = useCallback(
    (group: number[], at?: number, len = 0.9) => {
      const time = at ?? engine.now();
      group.forEach((midi, i) => {
        engine.piano(midi, time + i * 0.012, len);
        flash(midi, engine.wall(time));
      });
    },
    [flash]
  );

  useArrivals(block, groups.length, (index) => {
    const group = groups[index];
    if (group) strike(group, undefined, group.length > 1 ? 1.4 : 0.7);
  });

  const playAll = () => {
    if (timer.current) clearTimeout(timer.current);
    if (playing) {
      setPlaying(false);
      return;
    }
    const start = engine.now();
    let t = 0;
    for (const group of groups) {
      const len = group.length > 1 ? 1.2 : STEP_SECONDS * 1.6;
      strike(group, start + t, len);
      t += group.length > 1 ? 1.1 : STEP_SECONDS * 1.4;
    }
    setPlaying(true);
    timer.current = setTimeout(() => setPlaying(false), t * 1000 + 300);
  };

  const { marks, labels } = useMemo(() => {
    const dots: Record<number, string> = {};
    const names: Record<number, string> = {};
    for (const midi of all) {
      dots[midi] = BRASS;
      names[midi] = noteName(midi);
    }
    return { marks: dots, labels: names };
  }, [all.join(',')]); // eslint-disable-line react-hooks/exhaustive-deps

  const play = useCallback((midi: number) => strike([midi]), [strike]);

  return (
    <Card
      tag="KEYS"
      caption={caption}
      action={
        block.isComplete && groups.length > 0 ? (
          <PlayButton playing={playing} onPress={playAll} testID="keys-play" />
        ) : null
      }
    >
      <Keyboard
        low={range.current.low}
        high={range.current.high}
        hits={hits}
        marks={marks}
        labels={labels}
        onKey={play}
      />
    </Card>
  );
}
