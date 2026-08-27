interface DelimiterPair {
  open: string;
  close: string;
  symmetric: boolean;
}

// Longest first, so '***' matches before '**' and '**' before '*'.
const DELIMITER_PAIRS: DelimiterPair[] = [
  { open: '***', close: '***', symmetric: true },
  { open: '**', close: '**', symmetric: true },
  { open: '*', close: '*', symmetric: true },
  { open: '_', close: '_', symmetric: true },
  { open: '~~', close: '~~', symmetric: true },
  { open: '||', close: '||', symmetric: true },
  { open: '`', close: '`', symmetric: true },
  { open: '[', close: ']', symmetric: false },
];

function closingFor(entry: string): string {
  return DELIMITER_PAIRS.find((pair) => pair.open === entry)?.close ?? entry;
}

// Appends the closing delimiters missing from truncated or half-typed
// markdown, so the parser sees complete spans instead of literal delimiter
// characters.
export function completeMarkdown(markdown: string): string {
  if (markdown.length === 0) {
    return markdown;
  }

  const stack: string[] = [];
  let inLinkParen = false;
  const length = markdown.length;
  let i = 0;

  while (i < length) {
    const c = markdown.charAt(i);

    if (c === '\\' && i + 1 < length) {
      i += 2;
      continue;
    }

    // Link URL parentheses are a special two-character transition from "](".
    if (c === ']' && !inLinkParen && markdown.charAt(i + 1) === '(') {
      const bracketIndex = stack.lastIndexOf('[');
      if (bracketIndex !== -1) {
        // Styles left open inside the link text are contained by the bracket.
        stack.length = bracketIndex;
      }
      inLinkParen = true;
      i += 2;
      continue;
    }

    if (inLinkParen && c === ')') {
      inLinkParen = false;
      i++;
      continue;
    }

    if (inLinkParen) {
      i++;
      continue;
    }

    let matched = false;
    for (const pair of DELIMITER_PAIRS) {
      const openLen = pair.open.length;

      if (i + openLen > length) {
        continue;
      }

      if (pair.symmetric) {
        if (markdown.startsWith(pair.open, i)) {
          if (stack.length > 0 && stack[stack.length - 1] === pair.open) {
            stack.pop();
          } else {
            stack.push(pair.open);
          }
          i += openLen;
          matched = true;
          break;
        }
      } else {
        if (markdown.startsWith(pair.open, i)) {
          stack.push(pair.open);
          i += openLen;
          matched = true;
          break;
        }
        const closeLen = pair.close.length;
        if (i + closeLen <= length && markdown.startsWith(pair.close, i)) {
          if (stack.length > 0 && stack[stack.length - 1] === pair.open) {
            stack.pop();
          }
          i += closeLen;
          matched = true;
          break;
        }
      }
    }

    if (!matched) {
      i++;
    }
  }

  let suffix = '';

  if (inLinkParen) {
    suffix += ')';
  }

  for (let s = stack.length - 1; s >= 0; s--) {
    suffix += closingFor(stack[s]!);
  }

  if (suffix.length === 0) {
    return markdown;
  }

  return markdown + suffix;
}
