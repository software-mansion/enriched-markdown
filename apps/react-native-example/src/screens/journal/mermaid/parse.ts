// The slice of Mermaid the journal's charts use, parsed a line at a time so a
// chart can draw whatever has streamed in so far.

export interface XYChart {
  kind: 'xychart';
  title: string | null;
  x: string[];
  bars: number[];
}

export interface PieChart {
  kind: 'pie';
  title: string | null;
  slices: { label: string; value: number }[];
}

export interface Journey {
  kind: 'journey';
  title: string | null;
  sections: { name: string; tasks: { name: string; score: number }[] }[];
}

export type MermaidChart = XYChart | PieChart | Journey;

function unquote(text: string) {
  return text.trim().replace(/^"(.*)"$/, '$1');
}

// `[5, 6, 7]` or `["Mon", "Tue"]`.
function list(text: string) {
  const inner = text.match(/\[(.*)\]/)?.[1];
  if (inner === undefined) return [];
  return inner
    .split(',')
    .map((item) => unquote(item))
    .filter((item) => item !== '');
}

function xychart(lines: string[]): XYChart {
  const chart: XYChart = { kind: 'xychart', title: null, x: [], bars: [] };
  for (const line of lines) {
    const [keyword = '', ...rest] = line.trim().split(/\s+/);
    const value = rest.join(' ');
    if (keyword === 'title') chart.title = unquote(value);
    else if (keyword === 'x-axis') chart.x = list(value);
    else if (keyword === 'bar') chart.bars = list(value).map(Number);
  }
  return chart;
}

function pie(first: string, lines: string[]): PieChart {
  const chart: PieChart = {
    kind: 'pie',
    title: first.match(/^pie\s+(?:showData\s+)?title\s+(.+)$/)?.[1] ?? null,
    slices: [],
  };
  for (const line of lines) {
    const title = line.trim().match(/^title\s+(.+)$/);
    if (title) {
      chart.title = title[1]!.trim();
      continue;
    }
    const slice = line.trim().match(/^"([^"]+)"\s*:\s*([\d.]+)$/);
    if (slice) chart.slices.push({ label: slice[1]!, value: Number(slice[2]) });
  }
  return chart;
}

function journey(lines: string[]): Journey {
  const chart: Journey = { kind: 'journey', title: null, sections: [] };
  for (const line of lines) {
    const text = line.trim();
    if (text.startsWith('title ')) {
      chart.title = text.slice(6).trim();
    } else if (text.startsWith('section ')) {
      chart.sections.push({ name: text.slice(8).trim(), tasks: [] });
    } else {
      // `Task name: 5: Me`, the actors optional.
      const task = text.match(/^([^:]+):\s*([1-5])\s*(?::.*)?$/);
      if (!task) continue;
      if (chart.sections.length === 0) {
        chart.sections.push({ name: '', tasks: [] });
      }
      chart.sections[chart.sections.length - 1]!.tasks.push({
        name: task[1]!.trim(),
        score: Number(task[2]),
      });
    }
  }
  return chart;
}

export function parseMermaid(code: string): MermaidChart | null {
  const lines = code
    .split('\n')
    .filter((line) => line.trim() !== '' && !line.trim().startsWith('%%'));
  const [first = '', ...rest] = lines;
  const type = first.trim();
  if (type.startsWith('xychart')) return xychart(rest);
  if (type.startsWith('pie')) return pie(type, rest);
  if (type === 'journey') return journey(rest);
  return null;
}
