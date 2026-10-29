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
  occurrenceId: 'img:0123456789abcdef:0',
  language: '',
  code: '',
  isComplete: true,
};

const VIDEO_BLOCK: NativeBlockSlot = {
  id: 'video:fedcba9876543210:0',
  kind: 'video',
  url: 'https://e.com/v.mp4',
  altText: '',
  title: '',
  placement: 'blockquote',
  occurrenceId: '',
  language: '',
  code: '',
  isComplete: true,
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
      renderers={{
        image: () => undefined,
        video: () => <View testID="player" />,
      }}
    />
  );

  const mounted = slots(root);
  expect(mounted).toHaveLength(1);
  expect(mounted[0]!.props.slotId).toBe(VIDEO_BLOCK.id);
});

it('keeps the native block for null or false from untyped callers', () => {
  const root = render(
    <EnrichedMarkdownText
      markdown="x"
      flavor="github"
      renderers={{
        image: () => null as unknown as undefined,
        video: () => false as unknown as undefined,
      }}
    />
  );
  expect(slots(root)).toHaveLength(0);
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

it('renders an unchanged block once while the markdown keeps changing', () => {
  let figureRenders = 0;
  function Figure({ altText }: { altText: string }) {
    figureRenders++;
    return <View testID={`figure-${altText}`} />;
  }
  const image = jest.fn((block: { altText: string }) => (
    <Figure altText={block.altText} />
  ));
  const renderers = { image };
  const root = render(
    <EnrichedMarkdownText markdown="a" flavor="github" renderers={renderers} />
  );
  act(() =>
    root.render(
      <EnrichedMarkdownText
        markdown="ab"
        flavor="github"
        renderers={renderers}
      />
    )
  );
  expect(image).toHaveBeenCalledTimes(1);
  expect(figureRenders).toBe(1);

  mockSlots = [{ ...IMAGE_BLOCK, altText: 'Hero, at dawn' }, VIDEO_BLOCK];
  act(() =>
    root.render(
      <EnrichedMarkdownText
        markdown="abc"
        flavor="github"
        renderers={renderers}
      />
    )
  );
  expect(image).toHaveBeenCalledTimes(2);
  expect(figureRenders).toBe(2);

  act(() =>
    root.render(
      <EnrichedMarkdownText
        markdown="abc"
        flavor="github"
        renderers={{ image: (block) => image(block) }}
      />
    )
  );
  expect(image).toHaveBeenCalledTimes(3);
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
        image: () =>
          [
            <View key="a" testID="a" />,
            null,
            [<View key="b" />],
          ] as unknown as ReactElement,
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
  await act(async () => {
    await Promise.resolve();
  });
});

it('keeps the imageSources prop while a tick adds no image', () => {
  mockSlots = [];
  mockImages = OCCURRENCES;
  const resolveImageSource = ({ id }: { id: string }) => ({
    uri: `https://cdn/${id}`,
  });
  const root = render(
    <EnrichedMarkdownText
      markdown="x"
      flavor="github"
      resolveImageSource={resolveImageSource}
    />
  );
  const first = host(root).props.imageSources;
  // The collector returns new objects every tick.
  mockImages = OCCURRENCES.map((image) => ({ ...image }));
  act(() =>
    root.render(
      <EnrichedMarkdownText
        markdown="x and more"
        flavor="github"
        resolveImageSource={resolveImageSource}
      />
    )
  );
  expect(host(root).props.imageSources).toBe(first);
});

it('asks again when an image moves to another placement, and forgets removed images', () => {
  mockSlots = [];
  mockImages = OCCURRENCES;
  const resolver = jest.fn(({ id }: { id: string }) => ({
    uri: `https://cdn/${id}`,
  }));
  const tree = (markdown: string) => (
    <EnrichedMarkdownText
      markdown={markdown}
      flavor="github"
      resolveImageSource={resolver}
    />
  );
  const root = render(tree('x'));
  expect(resolver).toHaveBeenCalledTimes(3);

  // An edit moves image a into a quote: its old answer may not fit there.
  mockImages = [
    { ...OCCURRENCES[0]!, placement: 'blockquote' },
    ...OCCURRENCES.slice(1),
  ];
  act(() => root.render(tree('y')));
  expect(resolver).toHaveBeenCalledTimes(4);
  expect(resolver).toHaveBeenLastCalledWith(
    expect.objectContaining({ id: 'image:a:0', placement: 'blockquote' })
  );

  // b leaves the document and comes back: it is asked about again.
  mockImages = [mockImages[0]!, mockImages[2]!];
  act(() => root.render(tree('z')));
  mockImages = [mockImages[0]!, OCCURRENCES[1]!, mockImages[1]!];
  act(() => root.render(tree('z b')));
  expect(resolver).toHaveBeenCalledTimes(5);
});

it('never asks the resolver during a render that does not commit', async () => {
  mockSlots = [];
  mockImages = OCCURRENCES.slice(0, 1);
  let release!: () => void;
  let released = false;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  }).then(() => {
    released = true;
  });
  function Suspender({ wait }: { wait: boolean }) {
    if (wait && !released) throw gate;
    return null;
  }
  const resolver = jest.fn(({ id }: { id: string }) => ({
    uri: `https://cdn/${id}`,
  }));
  const tree = (wait: boolean) => (
    <Suspense fallback={null}>
      <EnrichedMarkdownText
        markdown={wait ? 'x more' : 'x'}
        flavor="github"
        resolveImageSource={resolver}
      />
      <Suspender wait={wait} />
    </Suspense>
  );
  const root = render(tree(false));
  expect(resolver).toHaveBeenCalledTimes(1);

  mockImages = OCCURRENCES.slice(0, 2);
  act(() => root.render(tree(true)));
  expect(resolver).toHaveBeenCalledTimes(1);
  await act(async () => {
    release();
    await gate;
  });
  expect(resolver).toHaveBeenCalledTimes(2);
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
        return undefined;
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

it('keeps the source of an image asked again for a new placement', async () => {
  mockSlots = [];
  mockImages = OCCURRENCES.slice(0, 1);
  const answers: Array<(source: { uri: string }) => void> = [];
  const resolver = jest.fn(
    () =>
      new Promise<{ uri: string }>((resolve) => {
        answers.push(resolve);
      })
  );
  const tree = (markdown: string) => (
    <EnrichedMarkdownText
      markdown={markdown}
      flavor="github"
      resolveImageSource={resolver}
    />
  );
  const root = render(tree('![a](x)'));
  await act(async () => {
    answers[0]!({ uri: 'https://cdn/root' });
    await Promise.resolve();
  });
  expect(host(root).props.imageSources[0].uri).toBe('https://cdn/root');

  // The paragraph streams on past the image, so it becomes inline.
  mockImages = [{ ...OCCURRENCES[0]!, placement: 'inline' }];
  act(() => root.render(tree('![a](x) and more text')));
  expect(resolver).toHaveBeenCalledTimes(2);
  expect(host(root).props.imageSources[0].uri).toBe('https://cdn/root');

  await act(async () => {
    answers[1]!({ uri: 'https://cdn/inline' });
    await Promise.resolve();
  });
  expect(host(root).props.imageSources[0].uri).toBe('https://cdn/inline');
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

describe('code renderers', () => {
  const codeSlot = (
    language: string,
    overrides: Partial<NativeBlockSlot> = {}
  ): NativeBlockSlot => ({
    id: `code:${language || 'none'}:0`,
    kind: 'code',
    url: '',
    altText: '',
    title: '',
    placement: 'root',
    occurrenceId: '',
    language,
    code: `${language} source`,
    isComplete: true,
    ...overrides,
  });

  const slotIds = (root: Root) => slots(root).map((slot) => slot.props.slotId);

  it('runs the language renderer whose pattern matches the fence language', () => {
    mockSlots = [
      codeSlot('mermaid', { placement: 'blockquote' }),
      codeSlot('ts'),
    ];
    const mermaid = jest.fn(() => <View testID="diagram" />);
    const root = render(
      <EnrichedMarkdownText
        markdown="x"
        flavor="github"
        renderers={{
          code: {
            languages: { mermaid: { pattern: '^mermaid$', content: mermaid } },
          },
        }}
      />
    );
    expect(mermaid).toHaveBeenCalledTimes(1);
    expect(mermaid).toHaveBeenCalledWith({
      kind: 'code',
      id: 'code:mermaid:0',
      language: 'mermaid',
      code: 'mermaid source',
      isComplete: true,
      placement: 'blockquote',
    });
    expect(slotIds(root)).toEqual(['code:mermaid:0']);
  });

  it('prefers the longest matching pattern', () => {
    mockSlots = [codeSlot('tsx')];
    const loose = jest.fn(() => <View />);
    const exact = jest.fn(() => <View />);
    render(
      <EnrichedMarkdownText
        markdown="x"
        flavor="github"
        renderers={{
          code: {
            languages: {
              loose: { pattern: 'ts', content: loose },
              exact: { pattern: /^tsx$/i, content: exact },
            },
          },
        }}
      />
    );
    expect(exact).toHaveBeenCalledTimes(1);
    expect(loose).not.toHaveBeenCalled();
  });

  it('falls back to default, and keeps the native block without one', () => {
    mockSlots = [codeSlot('mermaid'), codeSlot('ts'), codeSlot('')];
    const fallback = jest.fn(() => <View />);
    const mermaid = () => <View />;
    const withDefault = render(
      <EnrichedMarkdownText
        markdown="x"
        flavor="github"
        renderers={{
          code: {
            default: fallback,
            languages: { mermaid: { pattern: '^mermaid$', content: mermaid } },
          },
        }}
      />
    );
    expect(fallback).toHaveBeenCalledTimes(2);
    expect(slotIds(withDefault)).toEqual([
      'code:mermaid:0',
      'code:ts:0',
      'code:none:0',
    ]);

    const withoutDefault = render(
      <EnrichedMarkdownText
        markdown="x"
        flavor="github"
        renderers={{
          code: {
            languages: { mermaid: { pattern: '^mermaid$', content: mermaid } },
          },
        }}
      />
    );
    expect(slotIds(withoutDefault)).toEqual(['code:mermaid:0']);
  });

  it('keeps the native block when the matched language renderer declines, without trying default', () => {
    mockSlots = [codeSlot('mermaid')];
    const fallback = jest.fn(() => <View />);
    const root = render(
      <EnrichedMarkdownText
        markdown="x"
        flavor="github"
        renderers={{
          code: {
            default: fallback,
            languages: {
              mermaid: { pattern: '^mermaid$', content: () => undefined },
            },
          },
        }}
      />
    );
    expect(slots(root)).toHaveLength(0);
    expect(fallback).not.toHaveBeenCalled();
  });

  it('takes one function for every code block', () => {
    mockSlots = [codeSlot('ts'), codeSlot('')];
    const code = jest.fn(() => <View />);
    const root = render(
      <EnrichedMarkdownText markdown="x" flavor="github" renderers={{ code }} />
    );
    expect(code).toHaveBeenCalledTimes(2);
    expect(slotIds(root)).toEqual(['code:ts:0', 'code:none:0']);
  });

  it('does not collect blocks for a code entry with nothing to render', () => {
    render(
      <EnrichedMarkdownText
        markdown="x"
        flavor="github"
        renderers={{ code: { languages: {} } }}
      />
    );
    expect(mockCollect).not.toHaveBeenCalled();
  });

  it('ignores an invalid pattern with a warning', () => {
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
    mockSlots = [codeSlot('mermaid')];
    const broken = jest.fn(() => <View />);
    const fallback = jest.fn(() => <View />);
    render(
      <EnrichedMarkdownText
        markdown="x"
        flavor="github"
        renderers={{
          code: {
            default: fallback,
            languages: { broken: { pattern: '(mermaid', content: broken } },
          },
        }}
      />
    );
    expect(broken).not.toHaveBeenCalled();
    expect(fallback).toHaveBeenCalledTimes(1);
    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn.mock.calls[0]![0]).toContain('renderers.code.languages.broken');
    warn.mockRestore();
  });

  it('matches every block with a global pattern', () => {
    mockSlots = [codeSlot('sh'), codeSlot('sh', { id: 'code:sh:1' })];
    const shell = jest.fn(() => <View />);
    const root = render(
      <EnrichedMarkdownText
        markdown="x"
        flavor="github"
        renderers={{
          code: { languages: { shell: { pattern: /^sh$/g, content: shell } } },
        }}
      />
    );
    expect(slotIds(root)).toEqual(['code:sh:0', 'code:sh:1']);
  });

  it('names the language entry when its renderer throws', () => {
    const error = jest.spyOn(console, 'error').mockImplementation(() => {});
    mockSlots = [codeSlot('mermaid')];
    const root = render(
      <EnrichedMarkdownText
        markdown="x"
        flavor="github"
        renderers={{
          code: {
            languages: {
              mermaid: {
                pattern: '^mermaid$',
                content: () => {
                  throw new Error('boom');
                },
              },
            },
          },
        }}
      />
    );
    expect(slots(root)).toHaveLength(0);
    expect(error.mock.calls[0]![0]).toContain(
      'renderers.code.languages.mermaid threw for code:mermaid:0'
    );
    error.mockRestore();
  });

  it('does not render unchanged blocks again for an inline renderers literal', () => {
    mockSlots = [codeSlot('mermaid'), codeSlot('ts')];
    const mermaid = jest.fn(() => <View />);
    const fallback = jest.fn(() => <View />);
    const tree = (markdown: string, pattern: string | RegExp = '^mermaid$') => (
      <EnrichedMarkdownText
        markdown={markdown}
        flavor="github"
        renderers={{
          code: {
            default: fallback,
            languages: { mermaid: { pattern, content: mermaid } },
          },
        }}
      />
    );
    const root = render(tree('a'));
    act(() => root.render(tree('ab')));
    act(() => root.render(tree('abc', /^mermaid$/)));
    act(() => root.render(tree('abcd', /^mermaid$/)));
    expect(mermaid).toHaveBeenCalledTimes(2);
    expect(fallback).toHaveBeenCalledTimes(2);
  });

  it('re-renders a streaming fence in place until it completes', () => {
    mockSlots = [codeSlot('ts', { code: 'let', isComplete: false })];
    const code = jest.fn(() => <View />);
    const renderers = { code };
    const root = render(
      <EnrichedMarkdownText
        markdown="a"
        flavor="github"
        renderers={renderers}
      />
    );
    const first = slots(root)[0]!;

    mockSlots = [codeSlot('ts', { code: 'let a;', isComplete: true })];
    act(() =>
      root.render(
        <EnrichedMarkdownText
          markdown="ab"
          flavor="github"
          renderers={renderers}
        />
      )
    );
    expect(code).toHaveBeenCalledTimes(2);
    expect(code).toHaveBeenLastCalledWith(
      expect.objectContaining({ code: 'let a;', isComplete: true })
    );
    expect(slots(root)[0]).toBe(first);
  });
});
