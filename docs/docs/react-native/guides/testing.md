---
sidebar_label: Testing
sidebar_position: 6
---

# Testing with Jest

[`EnrichedMarkdownTextInput`](/react-native/api-reference/enriched-markdown-text-input) and [`EnrichedMarkdownText`](/react-native/api-reference/enriched-markdown-text) are Fabric/codegen native components. Under Jest there is no native view manager, so they render as opaque host views with no text children, and every imperative ref method - `focus()`, `setValue()`, `toggleBold()` - is a silent no-op. Nothing throws, which is exactly the problem: you cannot query the rendered Markdown, drive `onChangeText`, or assert that a toolbar button reached the editor, and the test passes anyway. To make those screens testable, the package ships an importable mock that renders plain React Native primitives and exposes every imperative method as a [`jest.fn()`](https://jestjs.io/docs/mock-functions) spy.

## Setup

Point Jest at the shipped mock from a setup file (for example `jest.setup.js`) listed in your config's `setupFilesAfterEnv`:

```js
// jest.setup.js
jest.mock('react-native-enriched-markdown', () =>
  require('react-native-enriched-markdown/jest'),
);
```

The mock is distributed as compiled ES modules, so - like most React Native libraries - the package must be transformed by Jest. The `react-native` and `jest-expo` presets transform `react-native` / `@react-native` packages but not third-party ones, so add `react-native-enriched-markdown` to `transformIgnorePatterns`:

```js
// jest.config.js
module.exports = {
  preset: '@react-native/jest-preset', // or 'jest-expo'
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native|@react-native(-community)?|react-native-enriched-markdown)/)',
  ],
};
```

:::note
On React Native 0.80 and newer the preset lives in its own package: `react-native/jest-preset` is a shim that throws unless `@react-native/jest-preset` is installed, and that package is an **optional** peer dependency of `react-native`. Install it (`npm i -D @react-native/jest-preset`) and reference it by its real name, as above.
:::

:::note
Your config's `transformIgnorePatterns` replaces the preset's rather than merging with it, so the pattern has to keep the entries the preset needs. The one above extends the `react-native` preset's default. `jest-expo` ships a longer allow-list (Expo and other packages), so with that preset append `react-native-enriched-markdown` to the pattern it already defines instead of using this one verbatim.
:::

## What the mock does

- **Renders a real `TextInput`.** React Native Testing Library queries (`getByTestId`, `getByPlaceholderText`, ...) and `fireEvent.changeText` work out of the box. `EnrichedMarkdownText` renders its `markdown` prop as plain text.
- **Emits change events on user input.** Typing fires `onChangeText` and, when a handler is provided, `onChangeMarkdown`. The mock cannot parse markdown, so it forwards the raw text to `onChangeMarkdown` as a stand-in.
- **Mirrors `setValue` suppression.** Calling `setValue()` updates the rendered text so the programmatic value is observable, but emits **no** change events - matching the native component's suppression of emits for programmatic updates.
- **Exposes every imperative method as a spy.** `toggleBold`, `insertMention`, `setSelection`, and the rest are `jest.fn()`s you can assert against. So are `focus`/`blur` (which forward to the inner `TextInput`) and `measure`/`measureInWindow`/`measureLayout`, which immediately invoke their callback with all zeros rather than hanging. The async methods resolve sensible values: `getMarkdown()` resolves the current text and `getCaretRect()` resolves `{ x: 0, y: 0, width: 0, height: 0 }`.
- **Forwards the ordinary `TextInput` props.** `onFocus`/`onBlur`, `editable`, `placeholder`, `placeholderTextColor`, `autoFocus`, `multiline`, `scrollEnabled`, `style`, `nativeID` and the whole `accessibility*` set reach the underlying `TextInput`, and `defaultValue` seeds the value - it is the only way to pre-fill the mock.
- **Replaces the module completely.** `react-native-enriched-markdown` has exactly four runtime exports (`EnrichedMarkdownText`, `EnrichedMarkdownTextInput`, `DEFAULT_ACCESSIBILITY_LABELS`, `resolveAccessibilityLabels`) and the mock re-exports all four, so mocking the whole module is safe.
- **Wires the display callbacks.** When you pass `onLinkPress`, `onLinkLongPress`, or `onTaskListItemPress` to `EnrichedMarkdownText`, links and task items render as pressable elements (accessibility roles `link` and `checkbox`), so those handlers are exercisable in tests too.

The ref object is authored against the library's real `EnrichedMarkdownTextInputInstance` type, so the **method** surface is type-checked on every release and cannot silently fall behind. Props are not covered by that guarantee - the mock only destructures the ones it uses, and TypeScript does not require destructuring to be exhaustive, so a newly added prop can go unforwarded without a type error.

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
import { render } from '@testing-library/react-native';
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
test('reads a programmatic value back', async () => {
  ref.current!.setValue('**bold**');
  await expect(ref.current!.getMarkdown()).resolves.toBe('**bold**');
});
```

## Limitations

The mock does not parse or render Markdown formatting. It mostly stores and echoes raw text; the two exceptions are the display callbacks above - with `onLinkPress`/`onLinkLongPress` set it rewrites `[text](url)` into a pressable element (stripping `*` and `_`), and with `onTaskListItemPress` set it rewrites `- [ ] item` into a checkbox glyph plus text. Everything else arrives verbatim.

It is meant for testing your components' wiring (event handlers, ref calls, conditional rendering), not the library's rendering or parsing behavior. That is covered by the library's own Maestro end-to-end suite - see [Contributing](/misc/contributing).
