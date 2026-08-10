import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import { githubFlavorArgTypes } from '../shared/storybookMarkdownStyles';
import { splitStyleControls } from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

const MARKDOWN = [
  '```javascript',
  'const greet = (name) => `hi ${name}`; // arrow fn',
  'export default greet(42);',
  '```',
  '',
  '```typescript',
  'type Pair<T> = { left: T; right: T };',
  'function swap<T>(p: Pair<T>): Pair<T> {',
  '  return { left: p.right, right: p.left };',
  '}',
  '```',
  '',
  '```python',
  'def fib(n: int) -> int:',
  '    return n if n < 2 else fib(n - 1) + fib(n - 2)  # recursion',
  '```',
  '',
  '```json',
  '{ "id": 7, "tags": ["a", "b"], "active": true }',
  '```',
  '',
  '```go',
  'package main',
  'func main() { println("hello") }',
  '```',
  '',
  '```rust',
  'fn main() { let x: u32 = 3; println!("{x}"); }',
  '```',
  '',
  '```c',
  '#include <stdio.h>',
  'int main(void) { return 0; }',
  '```',
  '',
  '```java',
  'record Point(int x, int y) {}',
  '```',
  '',
  '```bash',
  'for f in *.ts; do echo "$f"; done',
  '```',
  '',
  '```css',
  '.title { color: #cf222e; font-weight: 600; }',
  '```',
  '',
  '```html',
  '<a href="/x" class="link">go</a>',
  '```',
  '',
  '```yaml',
  'name: build',
  'on: [push]',
  '```',
].join('\n');

const BASE_TEXT_COLOR = '#f3f4f6';
const syntaxColorDefaults = {
  keyword: '#cf222e',
  operator: BASE_TEXT_COLOR,
  punctuation: BASE_TEXT_COLOR,
  string: '#0a3069',
  number: '#0550ae',
  constant: '#0550ae',
  comment: '#6e7781',
  function: '#8250df',
  type: '#953800',
  variable: BASE_TEXT_COLOR,
  property: '#0550ae',
  tag: '#116329',
  attribute: '#0550ae',
  embedded: BASE_TEXT_COLOR,
};

type SyntaxColorControls = typeof syntaxColorDefaults;

const colorControl = (token: keyof SyntaxColorControls) => ({
  control: 'color' as const,
  description: `markdownStyle.codeBlock.syntaxColors.${token}`,
});

const argTypes = {
  ...githubFlavorArgTypes(
    'commonmark — highlighted spans inside the single TextView. github — highlighted block component.'
  ),
  keyword: colorControl('keyword'),
  operator: colorControl('operator'),
  punctuation: colorControl('punctuation'),
  string: colorControl('string'),
  number: colorControl('number'),
  constant: colorControl('constant'),
  comment: colorControl('comment'),
  function: colorControl('function'),
  type: colorControl('type'),
  variable: colorControl('variable'),
  property: colorControl('property'),
  tag: colorControl('tag'),
  attribute: colorControl('attribute'),
  embedded: colorControl('embedded'),
};

export default storyMeta('Block', 'Code Highlight');

export const Default: TextStory<SyntaxColorControls> = {
  args: {
    markdown: MARKDOWN,
    flavor: 'github',
    ...syntaxColorDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, syntaxColorDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Code Highlight"
        description="Per-token syntax colors via markdownStyle.codeBlock.syntaxColors. Colors render only when the optional highlighting module is compiled in; otherwise code blocks stay plain. Retheme any token with the color controls, and switch flavor to compare the block and inline renderers."
        {...rest}
        style={{ codeBlock: { syntaxColors: controls } }}
      />
    );
  },
};
