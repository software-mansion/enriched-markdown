import type { MarkdownRenderers } from 'react-native-enriched-markdown';
import { loopFor } from '../loops';
import { DescentTrace } from './DescentTrace';
import { Dsky } from './Dsky';
import { Flowchart } from './Flowchart';
import { Printout } from './Printout';
import { Timeline } from './Timeline';
import { Transmission } from './Transmission';

// Named by hand: function names do not survive minification.
const CODE_RENDERERS = {
  timeline: { name: 'Timeline', Renderer: Timeline },
  flowchart: { name: 'Flowchart', Renderer: Flowchart },
  chart: { name: 'DescentTrace', Renderer: DescentTrace },
  dsky: { name: 'Dsky', Renderer: Dsky },
  agc: { name: 'Printout', Renderer: Printout },
  descent: { name: 'DescentTrace', Renderer: DescentTrace },
};

type Language = keyof typeof CODE_RENDERERS;

function isLanguage(language: string): language is Language {
  return language in CODE_RENDERERS;
}

export const journalRenderers: MarkdownRenderers = {
  code: (block) => {
    if (!isLanguage(block.language)) return undefined;
    const { Renderer } = CODE_RENDERERS[block.language];
    return <Renderer block={block} />;
  },
  link: (block) => {
    const loop = loopFor(block.url);
    return loop ? <Transmission block={block} loop={loop} /> : undefined;
  },
};

// The component a line of the source becomes, by the same rules as above,
// for the Duo's source page; null for a line that stays text.
export function rendererFor(line: string) {
  const fence = line.match(/^```(\w+)/)?.[1];
  if (fence) return isLanguage(fence) ? CODE_RENDERERS[fence].name : null;
  const target = line.match(/^\[[^\]]*\]\(([^\s)]+)/)?.[1];
  return target && loopFor(target) ? 'Transmission' : null;
}
