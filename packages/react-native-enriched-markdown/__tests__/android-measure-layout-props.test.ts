import { existsSync, readFileSync } from 'fs';
import { join } from 'path';

// Android measures in Kotlin with only the props conversions.h sends (measureLayoutConfig). A prop
// that changes layout but is missing there measures with its default, and the measured height
// disagrees with the rendered one. Every native prop, and every field
// of the streaming config and md4c flags, must be listed here as not laying the document out, or
// be sent and read by MeasureConfig.

const root = join(__dirname, '..');

// Props that don't lay the document out on Android, for both components.
const NOT_LAYOUT = new Set([
  // The markdown goes with the keys, not the config; a stream's text arrives as the markdown.
  'markdown',
  'streamId',
  'streamLength',
  'enableImagePress',
  'enableTextPress',
  'enableTaskListItemToggle',
  'enableCodeBlockPress',
  'enableBlockContextMenu',
  'enableLinkPreview',
  'selectable',
  'selectionColor',
  'selectionHandleColor',
  'spoilerOverlay',
  'contextMenuItems',
  'linkContextMenuItems',
  'selectionMenuConfig',
  'accessibilityLabels',
  'lineBreakStrategyIOS',
  // No-op on Android: each paragraph takes its first strong character's direction.
  'writingDirection',
]);

// EnrichedMarkdown ignores a line cap on Android: block segments can't honor one.
const NOT_LAYOUT_FOR_GFM = new Set(['numberOfLines', 'ellipsizeMode']);

// The animation draws over the same layout.
const STREAMING_NOT_LAYOUT = new Set([
  'animation',
  'animationDuration',
  'animationLength',
  'animationStartColor',
  'animationEndColor',
]);

function read(path: string): string {
  const file = join(root, path);
  if (!existsSync(file)) throw new Error(`Missing ${path}`);
  return readFileSync(file, 'utf8');
}

// The source between `anchor` and the end of its function, failing when the anchor is gone.
function functionBody(source: string, anchor: string): string {
  const start = source.indexOf(anchor);
  if (start < 0) throw new Error(`Missing ${anchor}`);
  return source.slice(start, source.indexOf('\n}\n', start));
}

const withoutComments = (source: string) =>
  source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');

const conversions = read(
  'android/src/main/jni/react/renderer/components/EnrichedMarkdownTextSpec/conversions.h'
);
// What Kotlin reads the config and the md4c flags with.
const kotlinReads = [
  'android/src/main/java/com/swmansion/enriched/markdown/MeasureConfig.kt',
  'android/src/main/java/com/swmansion/enriched/markdown/utils/common/MarkdownViewManagerUtils.kt',
]
  .map((path) => withoutComments(read(path)))
  .join('\n');
const readsKey = (key: string) =>
  new RegExp(`(get\\w+|hasKey)\\("${key}"`).test(kotlinReads);

// The props as codegen sees them: `extends`, intersections and comments resolved, events apart.
type Prop = { name: string; typeAnnotation: { properties?: Prop[] } };
function specProps(specFile: string): Prop[] {
  const parserPath = require.resolve(
    '@react-native/codegen/lib/parsers/typescript/parser',
    { paths: [require.resolve('react-native/package.json')] }
  );
  const { TypeScriptParser } = require(parserPath);
  const schema = new TypeScriptParser().parseFile(join(root, 'src', specFile));
  const [module] = Object.values(schema.modules) as {
    components: Record<string, { props: Prop[] }>;
  }[];
  const [component] = Object.values(module!.components);
  return component!.props;
}

const fieldsOf = (props: Prop[], name: string) =>
  (
    props.find((prop) => prop.name === name)?.typeAnnotation.properties ?? []
  ).map((field) => field.name);

it('sends the streaming options that lay a document out, and Kotlin reads them', () => {
  const sent = [
    ...functionBody(conversions, 'streamingLayoutConfig(const').matchAll(
      /"([A-Za-z_$][\w$]*)", config\./g
    ),
  ].map((match) => match[1]!);

  for (const specFile of [
    'EnrichedMarkdownNativeComponent.ts',
    'EnrichedMarkdownTextNativeComponent.ts',
  ]) {
    const fields = fieldsOf(specProps(specFile), 'streamingConfig');
    expect(fields).toContain('tableMode');
    expect(
      fields.filter(
        (field) => !STREAMING_NOT_LAYOUT.has(field) && !sent.includes(field)
      )
    ).toEqual([]);
  }
  expect(sent.filter((key) => !readsKey(key))).toEqual([]);
});

describe.each([
  ['EnrichedMarkdownNativeComponent.ts', 'EnrichedMarkdownProps', true],
  [
    'EnrichedMarkdownTextNativeComponent.ts',
    'EnrichedMarkdownTextProps',
    false,
  ],
])('%s', (specFile, component, gfm) => {
  const props = specProps(specFile);
  const names = props.map((prop) => prop.name);
  const sent = [
    ...functionBody(
      conversions,
      `measureLayoutConfig(const ${component} &props)`
    ).matchAll(/serializedProps\["([A-Za-z_$][\w$]*)"\]/g),
  ].map((match) => match[1]!);
  const notLayout = (prop: string) =>
    NOT_LAYOUT.has(prop) || (gfm && NOT_LAYOUT_FOR_GFM.has(prop));

  it('finds the props of the spec and of conversions.h', () => {
    expect(names).toContain('md4cFlags');
    expect(sent).toContain('md4cFlags');
  });

  it('sends every prop that lays the document out to Android measurement', () => {
    expect(
      names.filter((prop) => !notLayout(prop) && !sent.includes(prop))
    ).toEqual([]);
  });

  it('sends only props of the component, none listed as not laying it out', () => {
    expect(
      sent.filter((prop) => !names.includes(prop) || notLayout(prop))
    ).toEqual([]);
  });

  it('reads every prop it sends, and every md4c flag, in Kotlin', () => {
    expect(sent.filter((prop) => !readsKey(prop))).toEqual([]);
    expect(
      fieldsOf(props, 'md4cFlags').filter((flag) => !readsKey(flag))
    ).toEqual([]);
  });
});
