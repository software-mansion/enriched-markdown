import { Suspense, act } from 'react';
import type { ReactElement } from 'react';
import { View } from 'react-native';
import { createRoot } from 'test-renderer';
import type { Root, TestInstance } from 'test-renderer';
import { EnrichedMarkdownText } from '../src/native/EnrichedMarkdownText';
import type {
  NativeBlockSlot,
  NativeImageOccurrence,
  NativeStreamingOptions,
} from '../src/NativeEnrichedMarkdownParser';

type CollectArgs = [string, unknown, boolean, NativeStreamingOptions];
let mockSlots: ReadonlyArray<NativeBlockSlot> = [];
let mockImages: ReadonlyArray<NativeImageOccurrence> = [];
const mockCollect = jest.fn<
  {
    slots: ReadonlyArray<NativeBlockSlot>;
    images: ReadonlyArray<NativeImageOccurrence>;
  },
  CollectArgs
>(() => ({ slots: mockSlots, images: mockImages }));

jest.mock('../src/NativeEnrichedMarkdownParser', () => ({
  __esModule: true,
  default: {
    collect: (...args: CollectArgs) => mockCollect(...args),
  },
}));

jest.mock('../src/EnrichedMarkdownNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownNativeComponent',
}));

jest.mock('../src/EnrichedMarkdownTextNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownTextNativeComponent',
}));

jest.mock('../src/EnrichedMarkdownBlockSlotNativeComponent', () => ({
  __esModule: true,
  default: 'EnrichedMarkdownBlockSlot',
}));

const IMAGE_BLOCK: NativeBlockSlot = {
  id: 'image:0123456789abcdef:0',
  kind: 'image',
  url: 'https://e.com/a.png',
  altText: 'Hero',
  title: '',
  placement: 'root',
};

const VIDEO_BLOCK: NativeBlockSlot = {
  id: 'video:fedcba9876543210:0',
  kind: 'video',
  url: 'https://e.com/v.mp4',
  altText: '',
  title: '',
  placement: 'blockquote',
};

function render(element: ReactElement): Root {
  const root: Root = createRoot({
    textComponentTypes: [
      'EnrichedMarkdownNativeComponent',
      'EnrichedMarkdownTextNativeComponent',
      'EnrichedMarkdownBlockSlot',
    ],
  });
  act(() => root.render(element));
  return root;
}

function host(root: Root): TestInstance {
  const [view] = root.container.queryAll(
    (instance) => instance.type === 'EnrichedMarkdownNativeComponent'
  );
  if (!view) throw new Error('Native markdown view was not rendered');
  return view;
}

function slots(root: Root): TestInstance[] {
  return root.container.queryAll(
    (instance) => instance.type === 'EnrichedMarkdownBlockSlot'
  );
}

beforeEach(() => {
  mockCollect.mockClear();
  mockSlots = [IMAGE_BLOCK, VIDEO_BLOCK];
  mockImages = [];
});

it('mounts one slot child per block the renderer replaced, keyed by id', () => {
  const image = jest.fn(({ altText }: { altText: string }) => (
    <View testID={`figure-${altText}`} />
  ));
  const root = render(
    <EnrichedMarkdownText
      markdown="![Hero](https://e.com/a.png)"
      flavor="github"
      renderers={{ image }}
    />
  );

  expect(mockCollect).toHaveBeenCalledWith(
    '![Hero](https://e.com/a.png)',
    expect.objectContaining({ admonitions: true }),
    true,
    expect.objectContaining({ enabled: false })
  );
  expect(image).toHaveBeenCalledWith(
    expect.objectContaining({
      kind: 'image',
      id: IMAGE_BLOCK.id,
      url: IMAGE_BLOCK.url,
      altText: 'Hero',
      placement: 'root',
    })
  );
  const mounted = slots(root);
  expect(mounted).toHaveLength(1);
  expect(mounted[0]!.props.slotId).toBe(IMAGE_BLOCK.id);
  expect(host(root).children.length).toBe(1);
  expect(
    root.container.queryAll(
      (instance) => instance.props.testID === 'figure-Hero'
    )
  ).toHaveLength(1);
});

it('keeps native rendering for blocks the renderer declines or does not cover', () => {
  const root = render(
    <EnrichedMarkdownText
      markdown="x"
      flavor="github"
      renderers={{ image: () => null, video: () => <View testID="player" /> }}
    />
  );

  const mounted = slots(root);
  expect(mounted).toHaveLength(1);
  expect(mounted[0]!.props.slotId).toBe(VIDEO_BLOCK.id);
});

it('does not collect blocks when no renderer is set', () => {
  render(<EnrichedMarkdownText markdown="x" flavor="github" />);
  render(<EnrichedMarkdownText markdown="x" flavor="github" renderers={{}} />);
  expect(mockCollect).not.toHaveBeenCalled();
});

it('passes the streaming filter settings so the collector sees the rendered document', () => {
  render(
    <EnrichedMarkdownText
      markdown="x"
      flavor="github"
      streamingAnimation
      streamingConfig={{ mediaMode: 'hidden', tableMode: 'hidden' }}
      renderers={{ image: () => <View /> }}
    />
  );
  expect(mockCollect).toHaveBeenCalledWith('x', expect.anything(), true, {
    enabled: true,
    tableMode: 'hidden',
    codeBlockMode: 'progressive',
    mediaMode: 'hidden',
  });
});

it('parses once per flag values, not per md4cFlags object identity', () => {
  const root = render(
    <EnrichedMarkdownText
      markdown="x"
      flavor="github"
      md4cFlags={{ latexMath: false }}
      renderers={{ image: () => <View /> }}
    />
  );
  act(() =>
    root.render(
      <EnrichedMarkdownText
        markdown="x"
        flavor="github"
        md4cFlags={{ latexMath: false }}
        renderers={{ image: () => <View /> }}
      />
    )
  );
  expect(mockCollect).toHaveBeenCalledTimes(1);
});

it('keeps the native block when a renderer throws or returns text', () => {
  const error = jest.spyOn(console, 'error').mockImplementation(() => {});
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  const root = render(
    <EnrichedMarkdownText
      markdown="x"
      flavor="github"
      renderers={{
        image: () => {
          throw new Error('boom');
        },
        video: () => 'Loading…' as unknown as ReactElement,
      }}
    />
  );
  expect(slots(root)).toHaveLength(0);
  expect(error).toHaveBeenCalledTimes(1);
  expect(warn).toHaveBeenCalledTimes(1);
  error.mockRestore();
  warn.mockRestore();
});

it('keeps the native block when an array result contains text', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  const root = render(
    <EnrichedMarkdownText
      markdown="x"
      flavor="github"
      renderers={{
        image: () => [<View key="a" testID="a" />, null, [<View key="b" />]],
        video: () => ['Loading…'] as unknown as ReactElement,
      }}
    />
  );
  expect(slots(root)).toHaveLength(1);
  expect(slots(root)[0]!.props.slotId).toBe(IMAGE_BLOCK.id);
  expect(warn).toHaveBeenCalledTimes(1);
  warn.mockRestore();
});

it('keeps the native block when a fragment holds text, not elements', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  const root = render(
    <EnrichedMarkdownText
      markdown="x"
      flavor="github"
      renderers={{
        image: () => (
          <>
            <View testID="a" />
            {null}
          </>
        ),
        video: () => <>Loading…</>,
      }}
    />
  );
  expect(slots(root)).toHaveLength(1);
  expect(slots(root)[0]!.props.slotId).toBe(IMAGE_BLOCK.id);
  expect(warn).toHaveBeenCalledTimes(1);
  warn.mockRestore();
});

it('ignores renderers for the CommonMark flavor', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  const root = render(
    <EnrichedMarkdownText
      markdown="x"
      flavor="commonmark"
      renderers={{ image: () => <View testID="img" /> }}
    />
  );
  expect(mockCollect).not.toHaveBeenCalled();
  expect(slots(root)).toHaveLength(0);
  warn.mockRestore();
});

const OCCURRENCES: ReadonlyArray<NativeImageOccurrence> = [
  {
    id: 'image:a:0',
    url: 'https://e.com/a.png',
    altText: '',
    title: '',
    placement: 'root',
  },
  {
    id: 'image:b:0',
    url: 'https://e.com/b.png',
    altText: '',
    title: '',
    placement: 'inline',
  },
  {
    id: 'image:c:0',
    url: 'https://e.com/c.png',
    altText: '',
    title: '',
    placement: 'list',
  },
];

it('resolves each image once and keeps settled sources across markdown changes', async () => {
  mockSlots = [];
  mockImages = OCCURRENCES;
  const resolver = jest.fn(({ id }: { id: string }) =>
    Promise.resolve({ uri: `https://cdn/${id}` })
  );
  const root = render(
    <EnrichedMarkdownText
      markdown="x"
      flavor="github"
      resolveImageSource={resolver}
    />
  );
  expect(resolver).toHaveBeenCalledTimes(3);
  expect(host(root).props.imageSources).toEqual(
    OCCURRENCES.map(({ id }) => ({ id, uri: '', headers: [] }))
  );
  await act(async () => {
    await Promise.resolve();
  });
  expect(host(root).props.imageSources[0]).toEqual({
    id: 'image:a:0',
    uri: 'https://cdn/image:a:0',
    headers: [],
  });

  // A streaming append adds one image: only that one is resolved, the rest stay.
  mockImages = [
    ...OCCURRENCES,
    {
      id: 'image:d:0',
      url: 'https://e.com/d.png',
      altText: '',
      title: '',
      placement: 'root',
    },
  ];
  act(() =>
    root.render(
      <EnrichedMarkdownText
        markdown="x more"
        flavor="github"
        resolveImageSource={({ id }) =>
          Promise.resolve({ uri: `https://cdn/${id}` })
        }
      />
    )
  );
  expect(resolver).toHaveBeenCalledTimes(3);
  expect(host(root).props.imageSources).toEqual([
    { id: 'image:a:0', uri: 'https://cdn/image:a:0', headers: [] },
    { id: 'image:b:0', uri: 'https://cdn/image:b:0', headers: [] },
    { id: 'image:c:0', uri: 'https://cdn/image:c:0', headers: [] },
    { id: 'image:d:0', uri: '', headers: [] },
  ]);
});

it('sends sync image sources to native and keeps pending ones as empty uris', async () => {
  mockSlots = [];
  mockImages = OCCURRENCES;
  let resolveB!: (source: { uri: string }) => void;
  const pending = new Promise<{ uri: string }>((resolve) => {
    resolveB = resolve;
  });
  const root = render(
    <EnrichedMarkdownText
      markdown="x"
      flavor="github"
      resolveImageSource={({ id }) => {
        if (id === 'image:a:0') {
          return {
            uri: 'https://cdn/a.png',
            headers: { 'X-Token': 't', 'Authorization': 'Bearer x' },
          };
        }
        if (id === 'image:b:0') return pending;
        return null;
      }}
    />
  );

  expect(host(root).props.imageSources).toEqual([
    {
      id: 'image:a:0',
      uri: 'https://cdn/a.png',
      headers: [
        { name: 'Authorization', value: 'Bearer x' },
        { name: 'X-Token', value: 't' },
      ],
    },
    { id: 'image:b:0', uri: '', headers: [] },
  ]);

  await act(async () => {
    resolveB({ uri: 'https://cdn/b.png' });
    await pending;
  });

  expect(host(root).props.imageSources).toEqual([
    {
      id: 'image:a:0',
      uri: 'https://cdn/a.png',
      headers: [
        { name: 'Authorization', value: 'Bearer x' },
        { name: 'X-Token', value: 't' },
      ],
    },
    { id: 'image:b:0', uri: 'https://cdn/b.png', headers: [] },
  ]);
});

it('applies a source that settles after the document changed', async () => {
  mockSlots = [];
  mockImages = OCCURRENCES;
  let resolveB!: (source: { uri: string }) => void;
  const pending = new Promise<{ uri: string }>((resolve) => {
    resolveB = resolve;
  });
  const resolveImageSource = ({ id }: { id: string }) =>
    id === 'image:b:0' ? pending : { uri: `https://cdn/${id}` };
  const root = render(
    <EnrichedMarkdownText
      markdown="x"
      flavor="github"
      resolveImageSource={resolveImageSource}
    />
  );
  expect(host(root).props.imageSources).toEqual([
    { id: 'image:a:0', uri: 'https://cdn/image:a:0', headers: [] },
    { id: 'image:b:0', uri: '', headers: [] },
    { id: 'image:c:0', uri: 'https://cdn/image:c:0', headers: [] },
  ]);

  // A streaming append lands while b is still pending, then the stream ends.
  mockImages = [
    ...OCCURRENCES,
    {
      id: 'image:d:0',
      url: 'https://e.com/d.png',
      altText: '',
      title: '',
      placement: 'root',
    },
  ];
  act(() =>
    root.render(
      <EnrichedMarkdownText
        markdown="x more"
        flavor="github"
        resolveImageSource={resolveImageSource}
      />
    )
  );
  expect(host(root).props.imageSources[1]).toEqual({
    id: 'image:b:0',
    uri: '',
    headers: [],
  });

  await act(async () => {
    resolveB({ uri: 'https://cdn/b.png' });
    await pending;
  });
  expect(host(root).props.imageSources).toEqual([
    { id: 'image:a:0', uri: 'https://cdn/image:a:0', headers: [] },
    { id: 'image:b:0', uri: 'https://cdn/b.png', headers: [] },
    { id: 'image:c:0', uri: 'https://cdn/image:c:0', headers: [] },
    { id: 'image:d:0', uri: 'https://cdn/image:d:0', headers: [] },
  ]);
});

it('subscribes to a source started by an update render that was thrown away', async () => {
  mockSlots = [];
  mockImages = OCCURRENCES.slice(0, 1);
  let release!: () => void;
  let released = false;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  }).then(() => {
    released = true;
  });
  // A sibling that suspends the update which first asks about image b.
  function Suspender({ wait }: { wait: boolean }) {
    if (wait && !released) throw gate;
    return null;
  }
  let resolveB!: (source: { uri: string }) => void;
  const pending = new Promise<{ uri: string }>((resolve) => {
    resolveB = resolve;
  });
  const resolveImageSource = ({ id }: { id: string }) =>
    id === 'image:b:0' ? pending : { uri: `https://cdn/${id}` };
  const tree = (wait: boolean) => (
    <Suspense fallback={null}>
      <EnrichedMarkdownText
        markdown={wait ? 'x more' : 'x'}
        flavor="github"
        resolveImageSource={resolveImageSource}
      />
      <Suspender wait={wait} />
    </Suspense>
  );
  const root = render(tree(false));
  expect(host(root).props.imageSources).toEqual([
    { id: 'image:a:0', uri: 'https://cdn/image:a:0', headers: [] },
  ]);

  mockImages = OCCURRENCES.slice(0, 2);
  act(() => root.render(tree(true)));
  await act(async () => {
    release();
    await gate;
  });
  expect(host(root).props.imageSources[1]).toEqual({
    id: 'image:b:0',
    uri: '',
    headers: [],
  });

  await act(async () => {
    resolveB({ uri: 'https://cdn/b.png' });
    await pending;
  });
  expect(host(root).props.imageSources[1]).toEqual({
    id: 'image:b:0',
    uri: 'https://cdn/b.png',
    headers: [],
  });
});
