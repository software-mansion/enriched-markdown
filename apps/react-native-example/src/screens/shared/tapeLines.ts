export interface TapeLine {
  number: number;
  text: string;
  // The component the line's block becomes, null for a line of plain text.
  renderer: string | null;
  // The first line of that block, which carries the tag.
  opens: boolean;
  block: number;
}

// Each line of the source with the block it belongs to: a fence and
// everything inside it, or a renderer's line on its own.
export function tapeLines(
  markdown: string,
  rendererFor: (line: string) => string | null
): TapeLine[] {
  let inFence = false;
  let fenceRenderer: string | null = null;
  let block = -1;
  return markdown.split('\n').map((text, i) => {
    const fence = text.startsWith('```');
    let renderer: string | null = null;
    let opens = false;
    if (fence && !inFence) {
      fenceRenderer = rendererFor(text);
      if (fenceRenderer) {
        block++;
        opens = true;
      }
      renderer = fenceRenderer;
      inFence = true;
    } else if (fence) {
      renderer = fenceRenderer;
      inFence = false;
      fenceRenderer = null;
    } else if (inFence) {
      renderer = fenceRenderer;
    } else {
      renderer = rendererFor(text);
      if (renderer) {
        block++;
        opens = true;
      }
    }
    return { number: i + 1, text, renderer, opens, block };
  });
}

// The block the answer is writing now, the one the tape lights.
export function latestBlock(lines: TapeLine[]) {
  return Math.max(-1, ...lines.map((l) => (l.renderer ? l.block : -1)));
}
