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
    disposeStream: (id: number) => mockStreams.delete(id),
  },
}));

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

function nextFrame() {
  const pending = frames;
  frames = [];
  act(() => pending.forEach((callback) => callback()));
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

function view(root: Root): TestInstance {
  const [found] = root.container.queryAll(
    (instance) =>
      instance.type === 'EnrichedMarkdownTextNativeComponent' ||
      instance.type === 'EnrichedMarkdownNativeComponent'
  );
  if (!found) throw new Error('Native markdown view was not rendered');
  return found;
}

it('gets the parser module from the native entry', () => {
  jest.isolateModules(() => {
    require('../src/native/EnrichedMarkdownText');
    const { createMarkdownStream: create } = require('../src/markdownStream');
    const before = mockStreams.size;
    create('text');
    expect(mockStreams.size).toBe(before + 1);
  });
});

it('keeps the text in a native stream and sends its id and length once per frame', () => {
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

it('sends a markdown unique to the stream, so leaving it sends markdown again', () => {
  const stream = createMarkdownStream('same');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  const placeholder = view(root).props.markdown;
  expect(placeholder).not.toBe('same');
  act(() => root.render(<EnrichedMarkdownText markdown="same" />));
  expect(view(root).props.markdown).toBe('same');
  expect(view(root).props.streamId).toBe(0);
});

it('stops streaming at end() and takes an explicit streaming prop over it', () => {
  const stream = createMarkdownStream('text');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  stream.end();
  nextFrame();
  expect(view(root).props.streaming).toBe(false);
  expect(() => stream.append('more')).toThrow('after end()');

  act(() => root.render(<EnrichedMarkdownText stream={stream} streaming />));
  expect(view(root).props.streaming).toBe(true);
});

it('starts a new native stream on reset() and frees it on dispose()', () => {
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
  act(() => root.unmount());
  expect(mockStreams.has(secondId)).toBe(false);
  expect(() => stream.append('x')).toThrow('after dispose()');
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

it('keeps the native text while a view shows a disposed stream', () => {
  const stream = createMarkdownStream('kept');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  const { streamId } = view(root).props;
  stream.dispose();
  expect(mockStreams.get(streamId)).toBe('kept');
  act(() => root.unmount());
  expect(mockStreams.has(streamId)).toBe(false);
});

it('counts the length in bytes', () => {
  const stream = createMarkdownStream('é');
  const root = render(<EnrichedMarkdownText stream={stream} />);
  expect(view(root).props.streamLength).toBe(2);
});

it('shows nothing in a view that mounts after dispose', () => {
  const stream = createMarkdownStream('gone');
  stream.dispose();
  const root = render(<EnrichedMarkdownText stream={stream} />);
  expect(view(root).props.streamId).toBe(0);
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
});
