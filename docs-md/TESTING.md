# Testing with Jest

`EnrichedMarkdownTextInput` and `EnrichedMarkdownText` are Fabric/codegen native
components. Under Jest there is no native view manager, so rendering them — or
calling any imperative ref method such as `focus()`, `setValue()`, or
`toggleBold()`, which dispatch native commands — throws. To let you test screens
that embed these components, the package ships an importable mock that renders
plain React Native primitives and exposes every imperative method as a
[`jest.fn()`](https://jestjs.io/docs/mock-functions) spy.

## Setup

Point Jest at the shipped mock from a setup file (for example `jest.setup.js`)
listed in your config's `setupFilesAfterEnv`:

```js
// jest.setup.js
jest.mock('react-native-enriched-markdown', () =>
  require('react-native-enriched-markdown/jest'),
);
```

The mock is distributed as compiled ES modules, so — like most React Native
libraries — the package must be transformed by Jest. Add it to
`transformIgnorePatterns` in your Jest config:

```js
// jest.config.js
module.exports = {
  preset: 'jest-expo', // or 'react-native'
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native|@react-native(-community)?|expo(nent)?|@expo(nent)?/.*|react-native-enriched-markdown))',
  ],
};
```

## What the mock does

- **Renders a real `TextInput`.** React Native Testing Library queries
  (`getByTestId`, `getByPlaceholderText`, …) and `fireEvent.changeText` work out
  of the box. `EnrichedMarkdownText` renders its `markdown` prop as plain text.
- **Emits change events on user input.** Typing fires `onChangeText` and, when a
  handler is provided, `onChangeMarkdown`. The mock cannot parse markdown, so it
  forwards the raw text to `onChangeMarkdown` as a stand-in.
- **Mirrors `setValue` suppression.** Calling `setValue()` updates the rendered
  text so the programmatic value is observable, but emits **no** change events —
  matching the native component's suppression of emits for programmatic updates.
- **Exposes every imperative method as a spy.** `toggleBold`, `insertMention`,
  `setSelection`, and the rest are `jest.fn()`s you can assert against. The async
  methods resolve sensible values: `getMarkdown()` resolves the current text and
  `getCaretRect()` resolves `{ x: 0, y: 0, width: 0, height: 0 }`.

The mock is authored against the library's real public types, so it is
type-checked against the actual component API on every release and cannot
silently fall behind when methods or props are added.

## Examples

Asserting user input reaches your handlers:

```tsx
import { render, screen, fireEvent } from '@testing-library/react-native';
import { EnrichedMarkdownTextInput } from 'react-native-enriched-markdown';

test('reports typed text', () => {
  const onChangeMarkdown = jest.fn();
  render(
    <EnrichedMarkdownTextInput
      testID="composer"
      onChangeMarkdown={onChangeMarkdown}
    />,
  );

  fireEvent.changeText(screen.getByTestId('composer'), 'hello');

  expect(onChangeMarkdown).toHaveBeenCalledWith('hello');
});
```

Asserting a toolbar button invokes the right imperative method:

```tsx
import { createRef } from 'react';
import { render, screen, fireEvent } from '@testing-library/react-native';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
} from 'react-native-enriched-markdown';

test('bold button toggles bold', () => {
  const ref = createRef<EnrichedMarkdownTextInputInstance>();
  render(<EnrichedMarkdownTextInput ref={ref} />);

  ref.current!.toggleBold();

  expect(ref.current!.toggleBold).toHaveBeenCalledTimes(1);
});
```

Reading a programmatic value back out:

```tsx
ref.current!.setValue('**bold**');
await expect(ref.current!.getMarkdown()).resolves.toBe('**bold**');
```

## Limitations

The mock does not parse or render markdown formatting — it stores and echoes raw
text. It is meant for testing your components' wiring (event handlers, ref calls,
conditional rendering), not the library's rendering or parsing behavior, which is
covered by the library's own end-to-end tests.
