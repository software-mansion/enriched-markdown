import { act } from 'react';
import { createRoot } from 'test-renderer';
import type { Root, TestInstance } from 'test-renderer';
import { EnrichedMarkdownTextInput } from '../src/EnrichedMarkdownTextInput';
import type { EnrichedMarkdownTextInputProps } from '../src/EnrichedMarkdownTextInput';
import { TextInputState } from '../src/utils/textInputState';

jest.mock('../src/EnrichedMarkdownTextInputNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextInputNativeComponent',
  Commands: {},
}));

type Point = { pageX: number; pageY: number };

const INPUT_FRAME = { width: 320, height: 120, pageX: 0, pageY: 100 };
const START: Point = { pageX: 160, pageY: 160 };

function responderEvent(nativeEvent: Point) {
  return {
    persist: () => {},
    currentTarget: {
      measure: (callback: (...frame: number[]) => void) => {
        const { width, height, pageX, pageY } = INPUT_FRAME;
        callback(0, 0, width, height, pageX, pageY);
      },
    },
    nativeEvent,
  };
}

let root: Root;
let focusTextInput: jest.SpyInstance;

function renderInput(props: EnrichedMarkdownTextInputProps = {}): TestInstance {
  root = createRoot();
  act(() => root.render(<EnrichedMarkdownTextInput {...props} />));

  const [nativeView] = root.container.queryAll(
    (instance) => instance.type === 'EnrichedMarkdownTextInputNativeComponent'
  );
  if (!nativeView) throw new Error('Native input view was not rendered');
  return nativeView;
}

function press(view: TestInstance, ...moves: Point[]) {
  act(() => view.props.onResponderGrant(responderEvent(START)));
  for (const point of moves) {
    act(() => view.props.onResponderMove(responderEvent(point)));
  }
  act(() =>
    view.props.onResponderRelease(responderEvent(moves.at(-1) ?? START))
  );
}

beforeEach(() => {
  focusTextInput = jest
    .spyOn(TextInputState, 'focusTextInput')
    .mockImplementation(() => {});
});

afterEach(() => {
  act(() => root.unmount());
  focusTextInput.mockRestore();
});

it.each<[string, Point[], number]>([
  ['focuses on a tap released where it started', [], 1],
  [
    'focuses when the finger shifts a few points during a tap',
    [{ pageX: 163, pageY: 166 }],
    1,
  ],
  [
    'does not focus after a short drag that stays inside the input',
    [
      { pageX: 160, pageY: 147 },
      { pageX: 160, pageY: 134 },
    ],
    0,
  ],
  [
    'does not focus after a drag that returns to where it started',
    [{ pageX: 160, pageY: 140 }, START],
    0,
  ],
  [
    'does not focus after a drag that leaves the press area and comes back',
    [
      { pageX: 160, pageY: 60 },
      { pageX: 160, pageY: 85 },
    ],
    0,
  ],
])('%s', (_name, moves, focusCalls) => {
  const onPress = jest.fn();

  press(renderInput({ onPress }), ...moves);

  expect(onPress).toHaveBeenCalledTimes(1);
  expect(focusTextInput).toHaveBeenCalledTimes(focusCalls);
});

it('focuses on a tap that follows a drag', () => {
  const view = renderInput();

  press(view, { pageX: 160, pageY: 134 });
  press(view);

  expect(focusTextInput).toHaveBeenCalledTimes(1);
});

it.each<[string, boolean | undefined, boolean]>([
  ['keeps the responder during a press by default', undefined, false],
  ['gives up the responder with rejectResponderTermination off', false, true],
])('%s', (_name, rejectResponderTermination, yields) => {
  const view = renderInput({ rejectResponderTermination });

  expect(view.props.onResponderTerminationRequest()).toBe(yields);
});
