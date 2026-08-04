import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import { githubFlavorArgTypes } from '../shared/storybookMarkdownStyles';
import { splitStyleControls } from '../shared/storybookStyleBuilders';
import type { TextStory } from '../shared/storyTypes';

// A per-language sample split into two labelled sections so a tester can verify
// language coverage at a glance (see docs/TESTING_CODE_HIGHLIGHT_VENDORING.md,
// step 4): the "Defaults" section lists every language in the default registry,
// which highlights out of the box; the "Extended List" section lists the
// non-default grammars, which stay plain unless a build opts them in via the
// language-subset override (steps 4a/5a). One short block per language.
const MARKDOWN = [
  '## Defaults',
  '',
  '```javascript',
  'const sum = (a, b) => a + b; // add two numbers',
  '```',
  '',
  '```typescript',
  'const id: number = 7; type Name = string;',
  '```',
  '',
  '```tsx',
  'const El = () => <View title="x" id={7} />;',
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
  '```yaml',
  'name: demo',
  'port: 8080  # comment',
  '```',
  '',
  '```bash',
  'echo "hi $USER"  # greet',
  '```',
  '',
  '```go',
  'func main() { x := 3; _ = x }',
  '```',
  '',
  '```java',
  'class A { int x = 3; }',
  '```',
  '',
  '```c',
  'int main(void) { return 0; }',
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
  '',
  '```markdown',
  '# Heading with **bold** and _em_ [link](/x)',
  '```',
  '',
  '## Extended List',
  '',
  '```cpp',
  'int main() { auto x = 3; return x; }',
  '```',
  '',
  '```swift',
  'let x: Int = 3; print(x)',
  '```',
  '',
  '```php',
  '<?php echo "hi $name"; ?>',
  '```',
  '',
  '```ruby',
  'def greet(name) = "hi #{name}"',
  '```',
  '',
  '```csharp',
  'class A { int X = 3; }',
  '```',
].join('\n');

// Two blocks that together exercise every token type except embedded (which
// needs language injection, unsupported by the single-grammar highlighter). The
// Rust block covers comment, attribute (#[derive]), keyword, type, function,
// property (fields), variable, number, string, constant, operator and
// punctuation; the HTML block adds tag and attribute (plus doctype -> constant).
const MARKDOWN_ALL_TOKENS = [
  '```rust',
  '// distance between two points',
  '#[derive(Debug, Clone)]',
  'struct Point {',
  '    x: f64,',
  '    y: f64,',
  '}',
  '',
  'impl Point {',
  '    fn dist(&self, other: &Point) -> f64 {',
  '        let dx = self.x - other.x;',
  '        (dx * dx).sqrt()',
  '    }',
  '}',
  '',
  'fn main() {',
  '    const SCALE: u32 = 2;',
  '    let p = Point { x: 1.5, y: 3.0 };',
  '    println!("dist = {}", p.dist(&p) * SCALE as f64);',
  '}',
  '```',
  '',
  '```html',
  '<!doctype html>',
  '<!-- a labelled link -->',
  '<a href="/x" class="link" data-id="7">go</a>',
  '```',
].join('\n');

// GitHub-dark palette; the four "inherit" tokens use the code block base color.
const BASE_TEXT_COLOR = '#f3f4f6';
const syntaxColorDefaults = {
  keyword: '#ff7b72',
  operator: BASE_TEXT_COLOR,
  punctuation: BASE_TEXT_COLOR,
  string: '#a5d6ff',
  number: '#79c0ff',
  constant: '#79c0ff',
  comment: '#8b949e',
  function: '#d2a8ff',
  type: '#ffa657',
  variable: BASE_TEXT_COLOR,
  property: '#79c0ff',
  tag: '#7ee787',
  attribute: '#79c0ff',
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
        description="Per-token syntax colors via markdownStyle.codeBlock.syntaxColors. The Defaults section lists every language in the default registry (highlighted out of the box); the Extended List section lists non-default grammars that stay plain unless a build opts them in via the language-subset override. Colors render only when the optional highlighting module is compiled in; otherwise code blocks stay plain. Retheme any token with the color controls, and switch flavor to compare the block and inline renderers."
        {...rest}
        style={{ codeBlock: { syntaxColors: controls } }}
      />
    );
  },
};

export const AllTokens: TextStory<SyntaxColorControls> = {
  args: {
    markdown: MARKDOWN_ALL_TOKENS,
    flavor: 'github',
    ...syntaxColorDefaults,
  },
  argTypes,
  render: (args) => {
    const { controls, rest } = splitStyleControls(args, syntaxColorDefaults);
    return (
      <EnrichedMarkdownTextStory
        title="Code Highlight — All Tokens"
        description="A Rust block plus an HTML block that together exercise every syntax token type except embedded (which needs language injection), each rethemable with its own color control below. Colors render only when the optional highlighting module is compiled in with the rust and html grammars; otherwise the code blocks stay plain."
        {...rest}
        style={{ codeBlock: { syntaxColors: controls } }}
      />
    );
  },
};
