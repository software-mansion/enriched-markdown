import type { MarkdownStyle } from 'react-native-enriched-markdown';

// A full default palette shared by the docs examples. Pass the current color
// scheme and spread the result into `markdownStyle`, then override just the
// elements you care about:
//
//   markdownStyle={{ ...defaultMarkdownStyle(isDark), h1: { color: '#57b495' } }}
//
// Overriding a key replaces that element's object, so spread the element too if
// you only want to change one field: `h1: { ...defaultMarkdownStyle(isDark).h1, color }`.
//
// Each page re-exports this through a colocated `theme.ts` so examples can
// `import { defaultMarkdownStyle } from './theme'`.
export function defaultMarkdownStyle(isDark: boolean): MarkdownStyle {
  const text = isDark ? '#e7eaf6' : '#232736';
  const muted = isDark ? '#aeb6d4' : '#5b6479';
  // Links, blockquote bar, and task accent. A touch darker in light mode so the
  // teal reads clearly on a light background; the lighter tone stays for dark.
  const accent = isDark ? '#57b495' : '#3f9e82';
  const codeText = isDark ? '#79d6c6' : '#0e7c6f';
  const codeBg = isDark ? '#1d322e' : '#e2f2ef';
  const codeBorder = isDark ? '#315049' : '#bfe3db';
  const surface = isDark ? '#25322d' : '#e6f4ee';
  const border = isDark ? '#3a4360' : '#d7dbe8';
  const highlightBg = isDark ? '#4a4327' : '#fdf3c9';

  return {
    paragraph: { fontSize: 16, color: text },
    h1: { fontSize: 28, color: text },
    h2: { fontSize: 22, color: text },
    h3: { fontSize: 20, color: text },
    h4: { fontSize: 18, color: text },
    h5: { fontSize: 16, color: text },
    h6: { fontSize: 14, color: muted },
    strong: { color: text },
    em: { color: text },
    // The underline decoration color defaults to a fixed dark value, so it
    // disappears on the dark card unless the palette drives it too.
    underline: { color: text },
    link: { color: accent },
    // Teal chip with a border only a shade off the background - defined but not
    // harsh. The web renderer always draws a 1px border, so borderColor must be
    // set explicitly (an unset value falls back to a contrasting color).
    code: { color: codeText, backgroundColor: codeBg, borderColor: codeBorder },
    codeBlock: { color: text, backgroundColor: codeBg, borderRadius: 8 },
    blockquote: {
      color: text,
      borderColor: accent,
      backgroundColor: surface,
      borderWidth: 4,
      gapWidth: 12,
    },
    list: { color: text },
    highlight: { color: text, backgroundColor: highlightBg },
    // Math defaults to a fixed dark color on a fixed light box, so drive both
    // from the palette to keep equations legible in dark mode.
    inlineMath: { color: text },
    math: { color: text, backgroundColor: surface },
    // Task lists default to a fixed black checked-item color (invisible on the
    // dark card) and an iOS-blue checkbox, so drive them from the palette:
    // the accent fill matches links, checked text dims like a completed item.
    taskList: {
      checkedColor: accent,
      checkedTextColor: muted,
      checkedStrikethrough: true,
      borderColor: muted,
      checkmarkColor: '#ffffff',
    },
    thematicBreak: { color: border },
    table: {
      color: text,
      borderColor: border,
      borderRadius: 8,
      headerBackgroundColor: surface,
    },
  };
}
