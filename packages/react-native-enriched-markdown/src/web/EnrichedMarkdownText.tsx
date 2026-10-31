import {
  use,
  useState,
  useEffect,
  useMemo,
  useSyncExternalStore,
  type CSSProperties,
  type ReactNode,
} from 'react';
import type { EnrichedMarkdownTextProps } from '../types/MarkdownTextProps.web';
import { normalizeMarkdownStyle } from '../normalizeMarkdownStyle.web';
import {
  zeroTrailingMargins,
  parseErrorFallbackStyle,
  buildStyles,
} from './styles';
import {
  isParserReady,
  loadParser,
  parseMarkdownSync,
  subscribeParserReady,
  waitForParser,
} from './parseMarkdown';
import { recognizeTextLinks } from './recognizeTextLinks';
import { RenderNode } from './renderers';
import type { ASTNode, RendererCallbacks, RenderCapabilities } from './types';
import { indexTaskItems, markInlineImages } from './utils';
import { collectBlocks, type CollectedBlocks } from './blockSlots';
import { useResolvedImageSources } from '../imageSources';
import { hasRenderers, useRenderedBlocks } from '../blockRenderers';
import type { MarkdownImageOccurrence } from '../types/markdownBlocks';
import { loadKaTeX } from './katex';
import { ENRM_TEXT_CLASS, ENRM_SELECTION_BG_VAR } from './globalStyles';
import { filterNativeOnlyProps } from './nativeProps';
import { isDev } from '../utils/isDev';

const EMPTY: CollectedBlocks = { blocks: [], images: [] };

// `ast` is null when the parse threw; `error` is what it threw.
interface ParseResult {
  ast: ASTNode | null;
  collected: CollectedBlocks;
  error: unknown;
}

// Without `suspense`, the server never waits for the WASM, so hydration starts
// from "not ready" too.
const isParserReadyOnServer = () => false;

export const EnrichedMarkdownText = ({
  markdown,
  markdownStyle = {},
  md4cFlags = {},
  linkRecognition,
  onLinkPress,
  onLinkLongPress,
  onImagePress,
  onTaskListItemPress,
  onCodeBlockPress,
  renderers,
  resolveImageSource,
  enableTaskListItemToggle = true,
  allowTrailingMargin = false,
  containerStyle,
  selectable = true,
  dir,
  selectionColor,
  testID,
  suspense = false,
  ...rest
}: EnrichedMarkdownTextProps) => {
  const normalizedStyle = useMemo(
    () => normalizeMarkdownStyle(markdownStyle),
    [markdownStyle]
  );

  const renderersEnabled = hasRenderers(renderers);
  // Collecting hashes every image and link: only when something reads it.
  const collectEnabled = renderersEnabled || resolveImageSource != null;
  const [loadFailed, setLoadFailed] = useState(false);

  const {
    underline = false,
    latexMath = true,
    superscript = false,
    subscript = false,
    highlight = false,
    hardSoftBreaks = false,
    preserveBlankLines = false,
    admonitions = true,
  } = md4cFlags;

  // A regex literal in JSX is a new object every render; re-parse only when its text changes.
  const textLinkRegex = linkRecognition?.text;
  const inlineCodeLinkRegex = linkRecognition?.inlineCode;
  const textLinkKey = textLinkRegex?.toString() ?? null;
  const inlineCodeLinkKey = inlineCodeLinkRegex?.toString() ?? null;

  // With `suspense`, the first load suspends instead, so that the first commit
  // has the markdown: on the server, which then renders it, and while
  // hydrating, which keeps the server's HTML until the WASM has loaded.
  if (suspense && !isParserReady()) {
    if (typeof use !== 'function') {
      throw new Error('[EnrichedMarkdownText] `suspense` needs React 19');
    }
    use(waitForParser());
  }

  const parserReady = useSyncExternalStore(
    subscribeParserReady,
    isParserReady,
    // With `suspense`, the server (and so hydration) waited for the WASM.
    suspense ? isParserReady : isParserReadyOnServer
  );

  // Only the first load waits; once the WASM is up, every render parses the
  // markdown it was given, so no commit shows empty or previous content.
  useEffect(() => {
    if (parserReady) return;
    let cancelled = false;
    // A load that succeeds flips `parserReady`, which supersedes `loadFailed`.
    loadParser().catch((error) => {
      if (cancelled) return;
      if (isDev) {
        console.error('[EnrichedMarkdownText] Parse failed:', error);
      }
      setLoadFailed(true);
    });
    return () => {
      cancelled = true;
    };
    // A new markdown retries a load that failed, as each parse used to.
  }, [parserReady, markdown]);

  const parsed = useMemo<ParseResult | null>(() => {
    if (!parserReady) return null;
    try {
      const result = parseMarkdownSync(markdown, {
        underline,
        latexMath,
        superscript,
        subscript,
        highlight,
        hardSoftBreaks,
        preserveBlankLines,
        admonitions,
      });
      indexTaskItems(result);
      markInlineImages(result);
      return {
        collected: collectEnabled ? collectBlocks(result) : EMPTY,
        ast: recognizeTextLinks(result, textLinkRegex, inlineCodeLinkRegex),
        error: null,
      };
    } catch (error) {
      return { ast: null, collected: EMPTY, error };
    }
    // The regexes are keyed by their text, see above.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    parserReady,
    markdown,
    underline,
    latexMath,
    superscript,
    subscript,
    highlight,
    hardSoftBreaks,
    preserveBlankLines,
    admonitions,
    textLinkKey,
    inlineCodeLinkKey,
    collectEnabled,
  ]);

  useEffect(() => {
    if (parsed && !parsed.ast && isDev) {
      console.error('[EnrichedMarkdownText] Parse failed:', parsed.error);
    }
  }, [parsed]);

  const ast = parsed?.ast ?? null;
  const collected = parsed?.collected ?? EMPTY;
  const katex = latexMath ? loadKaTeX() : null;

  const callbacks = useMemo<RendererCallbacks>(
    () => ({
      onLinkPress,
      onLinkLongPress,
      onImagePress,
      onTaskListItemPress,
      onCodeBlockPress,
    }),
    [
      onLinkPress,
      onLinkLongPress,
      onImagePress,
      onTaskListItemPress,
      onCodeBlockPress,
    ]
  );

  const renderedBlocks = useRenderedBlocks(collected.blocks, renderers);
  const blockSlots = useMemo(() => {
    if (!renderersEnabled) return undefined;
    const slots = new Map<string, ReactNode>();
    for (const { block, element } of renderedBlocks) {
      slots.set(block.id, element);
    }
    return slots;
  }, [renderersEnabled, renderedBlocks]);

  const imageSources = useImageSources(collected.images, resolveImageSource);

  const blockDir = dir === 'ltr' || dir === 'rtl' ? undefined : 'auto';
  const capabilities = useMemo<RenderCapabilities>(
    () => ({
      katex,
      enableTaskListItemToggle,
      blockSlots,
      imageSources,
      blockDir,
    }),
    [katex, enableTaskListItemToggle, blockSlots, imageSources, blockDir]
  );

  const lastChildStyle = useMemo(
    () =>
      allowTrailingMargin
        ? normalizedStyle
        : zeroTrailingMargins(normalizedStyle),
    [normalizedStyle, allowTrailingMargin]
  );

  const styles = useMemo(() => buildStyles(normalizedStyle), [normalizedStyle]);

  const lastChildStyles = useMemo(
    () => buildStyles(lastChildStyle),
    [lastChildStyle]
  );

  const wrapperStyle = useMemo<CSSProperties>(
    () => ({
      display: 'flex',
      flexDirection: 'column',
      ...(containerStyle as CSSProperties),
      ...(selectable ? undefined : { userSelect: 'none' }),
      ...(selectionColor
        ? ({ [ENRM_SELECTION_BG_VAR]: selectionColor } as CSSProperties)
        : null),
    }),
    [containerStyle, selectable, selectionColor]
  );

  const domProps = filterNativeOnlyProps(rest);

  if (parsed ? !parsed.ast : loadFailed) {
    return (
      <div
        className={ENRM_TEXT_CLASS}
        style={wrapperStyle}
        dir={dir}
        data-testid={testID}
        {...domProps}
      >
        <pre style={parseErrorFallbackStyle}>{markdown}</pre>
      </div>
    );
  }

  if (!ast) return null;

  const children = ast.children ?? [];
  const lastIdx = children.length - 1;

  return (
    <div
      className={ENRM_TEXT_CLASS}
      style={wrapperStyle}
      dir={dir}
      data-testid={testID}
      {...domProps}
    >
      {children.map((child, index) => (
        <RenderNode
          key={child.attributes?.blockSlotId ?? `${child.type}-${index}`}
          node={child}
          style={index === lastIdx ? lastChildStyle : normalizedStyle}
          styles={index === lastIdx ? lastChildStyles : styles}
          callbacks={callbacks}
          capabilities={capabilities}
        />
      ))}
    </div>
  );
};

/**
 * The `imageSources` capability: resolved `src` by occurrence id, `null` while
 * pending or without a usable uri, no entry for images that keep the Markdown
 * URL. Headers cannot be honored by `<img>` and are dropped. See
 * `useResolvedImageSources` for the resolution rules.
 */
function useImageSources(
  images: MarkdownImageOccurrence[],
  resolve: EnrichedMarkdownTextProps['resolveImageSource']
): ReadonlyMap<string, string | null> | undefined {
  const resolved = useResolvedImageSources(images, resolve, resolve != null);
  return useMemo(() => {
    if (!resolved) return undefined;
    const result = new Map<string, string | null>();
    for (const [id, resolution] of resolved) {
      if (resolution.state === 'markdown') continue;
      result.set(
        id,
        resolution.state === 'resolved' ? resolution.source.uri || null : null
      );
    }
    return result;
  }, [resolved]);
}

export default EnrichedMarkdownText;
