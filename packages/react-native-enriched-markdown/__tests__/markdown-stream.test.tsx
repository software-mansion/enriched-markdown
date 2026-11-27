import { act } from 'react';
import type { ReactElement } from 'react';
import { createRoot } from 'test-renderer';
import type { Root, TestInstance } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';
import NativeEnrichedMarkdownParser from '../src/NativeEnrichedMarkdownParser';
import {
  createMarkdownStream,
  setNativeMarkdownStreams,
} from '../src/markdownStream';
import type { MarkdownStream } from '../src/markdownStream';

// The C++ streams, by id: the text the component descriptor would fill in.
const mockStreams = new Map<number, string>();
let mockNextId = 1;
const mockCollectStream = jest.fn((..._args: unknown[]) => ({
  slots: [],
  images: [],
  links: [],
}));

jest.mock('../src/NativeEnrichedMarkdownParser', () => ({
  __esModule: true,
  default: {
    collect: () => ({ slots: [], images: [], links: [] }),
    collectStream: (...args: unknown[]) => mockCollectStream(...args),
    createStream: (text: string) => {
      mockStreams.set(mockNextId, text);
      return mockNextId++;
    },
    appendToStream: (id: number, chunk: string) => {
      if (!mockStreams.has(id)) return 0;
      mockStreams.set(id, mockStreams.get(id)! + chunk);
      // In bytes, as the C++ buffer counts.
      return new TextEncoder().encode(mockStreams.get(id)!).length;
    },
    readStream: (id: number) => mockStreams.get(id) ?? '',
    disposeStream: (id: number) => mockStreams.delete(id),
  },
}));

// Called once per render of EnrichedMarkdownText itself, not of the view it renders.
const mockParentRenders = jest.fn();
jest.mock('../src/streamingEffects', () => {
  const actual = jest.requireActual('../src/streamingEffects');
  return {
    ...actual,
    useStreamingEffects: (...args: unknown[]) => {
      mockParentRenders();
      return actual.useStreamingEffects(...args);
    },
  };
});

jest.mock('../src/EnrichedMarkdownTextNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextNativeComponent',
}));

jest.mock('../src/EnrichedMarkdownNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownNativeComponent',
}));

let frames: Array<() => void> = [];
const realRequestAnimationFrame = global.requestAnimationFrame;
// The frame clock, moved by runFrame().
let clock = 0;
jest.spyOn(performance, 'now').mockImplementation(() => clock);

beforeEach(() => {
  setNativeMarkdownStreams(NativeEnrichedMarkdownParser);
  mockStreams.clear();
  mockCollectStream.mockClear();
  frames = [];
  global.requestAnimationFrame = ((callback: () => void) => {
    frames.push(callback);
    return frames.length;
  }) as typeof requestAnimationFrame;
});

afterAll(() => {
  global.requestAnimationFrame = realRequestAnimationFrame;
});

function runFrame(ms: number) {
  clock += ms;
  const pending = frames;
  frames = [];
  act(() => pending.forEach((callback) => callback()));
}

/** A frame late enough for a stream to publish again. */
function nextFrame() {
  runFrame(34);
}

function render(element: ReactElement): Root {
  const root = createRoot({
    textComponentTypes: [
      'EnrichedMarkdownTextNativeComponent',
      'EnrichedMarkdownNativeComponent',
    ],
  });
  act(() => root.render(element));
  return root;
}

// The text is freed after the commit's effects.
async function unmount(root: Root) {
  await act(async () => root.unmount());
}

function view(root: Root): TestInstance {
  const [found] = root.container.queryAll(
    (instance) =>
      instance.type === 'EnrichedMarkdownTextNativeComponent' ||
      instance.type === 'EnrichedMarkdownNativeComponent'
  );
  if (!found) throw new Error('Native markdown view was not rendered');
  return found;
}

it('gets the parser module from the package entry, before any view renders', () => {
  jest.isolateModules(() => {
    const { createMarkdownStream: create } = require('../src/index');
    const before = mockStreams.size;
    create('text');
    expect(mockStreams.size).toBe(before + 1);
  });
});

it('keeps the text in a native stream and sends its id and length on a frame', () => {
  const stream = createMarkdownStream('# Title');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  const { streamId } = view(root).props;
  expect(streamId).toBeGreaterThan(0);
  expect(view(root).props.streamLength).toBe(7);
  expect(view(root).props.streaming).toBe(true);

  stream.append('\n\nOne');
  stream.append(' two');
  expect(view(root).props.streamLength).toBe(7);
  expect(frames).toHaveLength(1);

  nextFrame();
  expect(view(root).props.streamLength).toBe(16);
  expect(mockStreams.get(streamId)).toBe('# Title\n\nOne two');
});

it("re-renders only the native view on a stream's frames", () => {
  const stream = createMarkdownStream('# Title');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  const renders = mockParentRenders.mock.calls.length;
  stream.append('\n\nOne');
  nextFrame();
  stream.append(' two');
  nextFrame();
  expect(view(root).props.streamLength).toBe(16);
  expect(mockParentRenders.mock.calls.length).toBe(renders);

  // Ending the stream turns `streaming` off (a re-render) with the final length.
  stream.append(' three');
  stream.end();
  nextFrame();
  expect(view(root).props.streaming).toBe(false);
  expect(view(root).props.streamLength).toBe(22);
});

it('passes the github props through while the view follows the stream', () => {
  const stream = createMarkdownStream('text');
  const root = render(
    <EnrichedMarkdownText
      stream={stream}
      flavor="github"
      enableCodeBlockWrapToggle
    />
  );
  expect(view(root).type).toBe('EnrichedMarkdownNativeComponent');
  expect(view(root).props.enableCodeBlockWrapToggle).toBe(true);
  stream.append(' more');
  nextFrame();
  expect(view(root).props.streamLength).toBe(9);
  expect(view(root).props.enableCodeBlockWrapToggle).toBe(true);
});

it('keeps the view and the stream when collecting turns on and off mid-stream', () => {
  const stream = createMarkdownStream('one');
  const root = render(<EnrichedMarkdownText stream={stream} flavor="github" />);
  const shown = view(root);
  const { streamId } = shown.props;
  const onLinksChange = jest.fn();
  act(() =>
    root.render(
      <EnrichedMarkdownText
        stream={stream}
        flavor="github"
        onLinksChange={onLinksChange}
      />
    )
  );
  stream.append(' two');
  nextFrame();
  expect(view(root)).toBe(shown);
  expect(view(root).props.streamLength).toBe(7);
  act(() =>
    root.render(<EnrichedMarkdownText stream={stream} flavor="github" />)
  );
  stream.append(' three');
  nextFrame();
  expect(view(root)).toBe(shown);
  expect(view(root).props.streamId).toBe(streamId);
  expect(view(root).props.streamLength).toBe(13);
  expect(mockStreams.get(streamId)).toBe('one two three');
});

it('publishes a reset at once, also without the native module', () => {
  for (const native of [true, false]) {
    setNativeMarkdownStreams(native ? NativeEnrichedMarkdownParser : null);
    const stream = createMarkdownStream('old');
    const root = render(<EnrichedMarkdownText stream={stream} />);
    stream.append(' text');
    nextFrame();
    stream.reset('new');
    runFrame(17);
    const shown = view(root).props;
    expect(native ? mockStreams.get(shown.streamId) : shown.markdown).toBe(
      'new'
    );
  }
});

it('publishes a long text less often, about 16 times a second', () => {
  const stream = createMarkdownStream('x'.repeat(17 * 1024));
  const root = render(<EnrichedMarkdownText stream={stream} />);
  stream.append('a');
  runFrame(70);
  const published = view(root).props.streamLength;

  // Three 60 Hz frames are too soon for a text past 16 KiB; the fourth publishes.
  stream.append('b');
  runFrame(17);
  runFrame(17);
  runFrame(17);
  expect(view(root).props.streamLength).toBe(published);
  runFrame(17);
  expect(view(root).props.streamLength).toBe(published + 1);
});

it('slows publishing gradually between 4 and 16 KiB', () => {
  const stream = createMarkdownStream('x'.repeat(10 * 1024));
  const root = render(<EnrichedMarkdownText stream={stream} />);
  stream.append('a');
  runFrame(70);
  const published = view(root).props.streamLength;

  // Halfway, about 43 ms: the second frame is too soon, the third publishes.
  stream.append('b');
  runFrame(17);
  runFrame(17);
  expect(view(root).props.streamLength).toBe(published);
  runFrame(17);
  expect(view(root).props.streamLength).toBe(published + 1);
});

it('publishes about every other frame, and the end at once', () => {
  const stream = createMarkdownStream('a');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  stream.append('b');
  nextFrame();
  expect(view(root).props.streamLength).toBe(2);

  // The next 60 Hz frame is too soon; the one after it publishes, even a few ms early.
  stream.append('c');
  runFrame(17);
  expect(view(root).props.streamLength).toBe(2);
  runFrame(12);
  expect(view(root).props.streamLength).toBe(3);

  stream.append('d');
  stream.end();
  runFrame(17);
  expect(view(root).props.streamLength).toBe(4);
  expect(view(root).props.streaming).toBe(false);
});

it('sends a markdown unique to the stream, so leaving it sends markdown again', () => {
  const stream = createMarkdownStream('same');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  const placeholder = view(root).props.markdown;
  expect(placeholder).not.toBe('same');
  const shown = view(root);
  act(() => root.render(<EnrichedMarkdownText markdown="same" />));
  expect(view(root).props.markdown).toBe('same');
  expect(view(root).props.streamId).toBe(0);
  // The same view: the final text replaces the stream without a remount.
  expect(view(root)).toBe(shown);
});

it('stops streaming at end() and takes an explicit streaming prop over it', () => {
  const stream = createMarkdownStream('text');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  stream.end();
  nextFrame();
  expect(view(root).props.streaming).toBe(false);
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  stream.append('more');
  expect(warn).toHaveBeenCalledWith(
    expect.stringContaining('append() after end() is ignored')
  );
  warn.mockRestore();
  expect(stream.getText()).toBe('text');

  act(() => root.render(<EnrichedMarkdownText stream={stream} streaming />));
  expect(view(root).props.streaming).toBe(true);
});

it('starts a new native stream on reset() and frees it on dispose()', async () => {
  const stream = createMarkdownStream('first');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  const firstId = view(root).props.streamId;
  stream.end();
  stream.reset('second');
  // The old text stays until the new stream is published.
  expect(mockStreams.has(firstId)).toBe(true);
  nextFrame();
  const secondId = view(root).props.streamId;
  expect(secondId).not.toBe(firstId);
  expect(mockStreams.has(firstId)).toBe(false);
  expect(mockStreams.get(secondId)).toBe('second');
  expect(view(root).props.streaming).toBe(true);

  stream.dispose();
  // Freed once the view showing it unmounts.
  expect(mockStreams.has(secondId)).toBe(true);
  await unmount(root);
  expect(mockStreams.has(secondId)).toBe(false);
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  stream.append('x');
  expect(warn).toHaveBeenCalledWith(
    expect.stringContaining('append() after dispose() is ignored')
  );
  warn.mockRestore();
  expect(stream.getText()).toBe('');
});

it('collects block slots from the stream without its text crossing to JS', () => {
  const stream = createMarkdownStream('![a](https://e.com/a.png)');
  render(
    <EnrichedMarkdownText
      stream={stream}
      flavor="github"
      renderers={{ image: () => undefined }}
    />
  );
  expect(mockCollectStream).toHaveBeenCalledWith(
    expect.any(Number),
    25,
    expect.anything(),
    true,
    expect.objectContaining({ enabled: true })
  );
});

it('collects again only when the stream grows', () => {
  const stream = createMarkdownStream('![a](https://e.com/a.png)');
  render(
    <EnrichedMarkdownText
      stream={stream}
      streaming
      flavor="github"
      renderers={{ image: () => undefined }}
    />
  );
  const calls = mockCollectStream.mock.calls.length;
  stream.end();
  nextFrame();
  expect(mockCollectStream.mock.calls.length).toBe(calls);
});

it('keeps the native text while a view shows a disposed stream', async () => {
  const stream = createMarkdownStream('kept');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  const { streamId } = view(root).props;
  stream.dispose();
  nextFrame();
  expect(mockStreams.get(streamId)).toBe('kept');
  // Disposing ends it: the view renders it in full and stops streaming.
  expect(view(root).props.streaming).toBe(false);
  await unmount(root);
  expect(mockStreams.has(streamId)).toBe(false);
});

// A key change, or one of two components showing the stream picked by state.
it('keeps a disposed stream shown by a view that takes over in the same commit', async () => {
  const stream = createMarkdownStream('kept');
  const root = render(<EnrichedMarkdownText key="a" stream={stream} />);
  const { streamId } = view(root).props;
  stream.dispose();
  await act(async () =>
    root.render(<EnrichedMarkdownText key="b" stream={stream} />)
  );
  expect(mockStreams.get(streamId)).toBe('kept');
  expect(view(root).props.streamId).toBe(streamId);

  await unmount(root);
  expect(mockStreams.has(streamId)).toBe(false);
});

it('reads the text appended so far from the native stream', () => {
  const stream = createMarkdownStream('# Title');
  stream.append('\n\nBody');
  // Before the next frame, and with half a surrogate pair held back.
  stream.append('\ud83d');
  expect(stream.getText()).toBe('# Title\n\nBody\ud83d');
});

it('counts the length in bytes', () => {
  const stream = createMarkdownStream('é');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  expect(view(root).props.streamLength).toBe(2);
});

it('warns once of a stream not from createMarkdownStream()', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  for (const flavor of ['commonmark', 'github'] as const) {
    warn.mockClear();
    render(
      <EnrichedMarkdownText
        flavor={flavor}
        stream={{} as MarkdownStream}
        onLinksChange={() => {}}
      />
    );
    const warnings = warn.mock.calls.filter(([message]) =>
      String(message).includes('takes a stream from createMarkdownStream()')
    );
    expect(warnings).toHaveLength(1);
  }
  warn.mockRestore();
});

it('shows nothing in a view that mounts after dispose', () => {
  const stream = createMarkdownStream('gone');
  stream.dispose();
  const root = render(<EnrichedMarkdownText stream={stream} />);
  expect(view(root).props.streamId).toBe(0);
});

it('holds back half a surrogate pair in the initial and reset text', () => {
  const emoji = '\u{1F600}';
  const stream = createMarkdownStream('a' + emoji[0]);
  const root = render(<EnrichedMarkdownText stream={stream} />);
  const firstId = view(root).props.streamId;
  expect(mockStreams.get(firstId)).toBe('a');
  expect(view(root).props.streamLength).toBe(1);
  expect(stream.getText()).toBe('a' + emoji[0]);
  stream.append(emoji[1] + 'b');
  expect(mockStreams.get(firstId)).toBe('a' + emoji + 'b');

  stream.reset('c' + emoji[0]);
  nextFrame();
  const secondId = view(root).props.streamId;
  expect(mockStreams.get(secondId)).toBe('c');
  stream.end();
  expect(mockStreams.get(secondId)).toBe('c' + emoji[0]);
});

it('frees the native text of a stream JS dropped without dispose()', () => {
  const realRegistry = global.FinalizationRegistry;
  let cleanup: ((held: unknown) => void) | undefined;
  const held: unknown[] = [];
  global.FinalizationRegistry = class {
    constructor(callback: (held: unknown) => void) {
      cleanup = callback;
    }
    register(_target: object, value: unknown) {
      held.push(value);
    }
    unregister() {
      return false;
    }
  } as unknown as typeof FinalizationRegistry;
  try {
    jest.isolateModules(() => {
      // No view rendered yet: the package entry has handed streams the native module.
      require('../src/index').createMarkdownStream('dropped');
    });
    const [id] = [...mockStreams.keys()];
    expect(mockStreams.get(id!)).toBe('dropped');
    cleanup!(held[0]);
    expect(mockStreams.has(id!)).toBe(false);
  } finally {
    global.FinalizationRegistry = realRegistry;
  }
});

it('holds back half a surrogate pair until the next chunk', () => {
  setNativeMarkdownStreams(null);
  const stream = createMarkdownStream();
  const root = render(<EnrichedMarkdownText stream={stream} />);
  const emoji = '\u{1F600}';
  stream.append('a' + emoji[0]);
  nextFrame();
  expect(view(root).props.markdown).toBe('a');
  stream.append(emoji[1] + 'b');
  nextFrame();
  expect(view(root).props.markdown).toBe('a' + emoji + 'b');
  // A chunk of only half a pair, then end(): the half is written as it is.
  stream.append(emoji[0]!);
  stream.end();
  nextFrame();
  expect(view(root).props.markdown).toBe('a' + emoji + 'b' + emoji[0]);
});

it('passes the text as markdown without the native module', () => {
  setNativeMarkdownStreams(null);
  const stream = createMarkdownStream('Hello');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  expect(view(root).props.markdown).toBe('Hello');
  expect(view(root).props.streamId).toBe(0);
  stream.append(' world');
  nextFrame();
  expect(view(root).props.markdown).toBe('Hello world');
  expect(stream.getText()).toBe('Hello world');
});
