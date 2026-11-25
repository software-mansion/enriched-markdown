import { Text } from 'react-native';

const COLORS = {
  keyword: '#FF7AB6',
  namespace: '#6FD3FF',
  number: '#FFB86B',
  name: '#E7E5F2',
  punctuation: '#7D7A99',
  arrow: '#FF7AB6',
};

const KEYWORDS = new Set([
  'const',
  'let',
  'for',
  'if',
  'return',
  'break',
  'else',
  'while',
]);
const NAMESPACES = new Set(['std', 'd', 'tgpu', 'Sdf']);
const TOKEN = /(\s+)|(=>)|(\d+(?:\.\d+)?)|([A-Za-z_$][\w$]*)|(.)/g;

/** A line of a code block, coloured like an editor would: just enough for JS. */
export function HighlightedLine({ line }: { line: string }) {
  const spans: { text: string; color: string }[] = [];
  let previous = '';
  for (const [, space, arrow, number, word, other] of line.matchAll(TOKEN)) {
    let text: string;
    let color: string;
    if (space !== undefined) {
      text = space;
      color = COLORS.name;
    } else if (arrow !== undefined) {
      text = arrow;
      color = COLORS.arrow;
    } else if (number !== undefined) {
      text = number;
      color = COLORS.number;
    } else if (word !== undefined) {
      text = word;
      color = KEYWORDS.has(word)
        ? COLORS.keyword
        : NAMESPACES.has(word) && previous !== '.'
          ? COLORS.namespace
          : COLORS.name;
    } else {
      text = other!;
      color = COLORS.punctuation;
    }
    if (space === undefined) previous = text;
    const last = spans[spans.length - 1];
    if (last && last.color === color) last.text += text;
    else spans.push({ text, color });
  }
  return (
    <>
      {spans.map((span, i) => (
        <Text key={i} style={{ color: span.color }}>
          {span.text}
        </Text>
      ))}
    </>
  );
}
