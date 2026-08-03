import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import { githubFlavorArgTypes } from '../shared/storybookMarkdownStyles';
import { splitStyleControls } from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

// A compact multi-language sample that still exercises every token type, kept
// short so the story fits the preview like the other block stories.
const MARKDOWN = [
  '```javascript',
  'const sum = (a, b) => a + b; // add two numbers',
  '```',
  '',
  '```python',
  'def greet(name): return f"hi {name}"  # f-string',
  '```',
  '',
  '```json',
  '{ "id": 7, "tags": ["a"], "active": true }',
  '```',
  '',
  '```rust',
  'fn main() { let x: u32 = 3; }',
  '```',
  '',
  '```html',
  '<a href="/x" class="link">go</a>',
  '```',
  '',
  '```css',
  '.title { color: #cf222e; }',
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
