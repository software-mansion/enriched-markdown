import { useEffect, useMemo, type CSSProperties, type ReactNode } from 'react';
import type { EnrichedMarkdownTextProps } from '../types/MarkdownTextProps.web';
import { useMarkdownStreamSnapshot } from '../markdownStream';
import { normalizeMarkdownStyle } from '../normalizeMarkdownStyle.web';
import {
  zeroTrailingMargins,
  parseErrorFallbackStyle,
  buildStyles,
} from './styles';
import { parseMarkdownSync } from './parseMarkdown';
import { recognizeTextLinks } from './recognizeTextLinks';
import { RenderNode } from './renderers';
import type { ASTNode, RendererCallbacks, RenderCapabilities } from './types';
import { indexTaskItems, markInlineImages } from './utils';
import { collectBlocks, type CollectedBlocks } from './blockSlots';
import { useResolvedImageSources } from '../imageSources';
import { useLinksChange } from '../linkOccurrences';
import { hasRenderers, useRenderedBlocks } from '../blockRenderers';
import type { MarkdownImageOccurrence } from '../types/markdownBlocks';
import { loadKaTeX } from './katex';
import { ENRM_TEXT_CLASS, ENRM_SELECTION_BG_VAR } from './globalStyles';
import { filterNativeOnlyProps } from './nativeProps';
import { isDev } from '../utils/isDev';

const EMPTY: CollectedBlocks = { blocks: [], images: [], links: [] };

// `ast` is null when the parse or the WASM load threw; `error` is what threw.
interface ParseResult {
  ast: ASTNode | null;
  collected: CollectedBlocks;
  error: unknown;
}

export const EnrichedMarkdownText = ({
  markdown: markdownProp = '',
  stream,
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
  onLinksChange,
  enableTaskListItemToggle = true,
  allowTrailingMargin = false,
  containerStyle,
  selectable = true,
  dir,
  selectionColor,
  testID,
  ...rest
}: EnrichedMarkdownTextProps) => {
  const streamSnapshot = useMarkdownStreamSnapshot(stream);
  const markdown = streamSnapshot?.text ?? markdownProp;
  const normalizedStyle = useMemo(
    () => normalizeMarkdownStyle(markdownStyle),
    [markdownStyle]
  );

  const renderersEnabled = hasRenderers(renderers);
  // Collecting hashes every image and link: only when something reads it.
  const collectEnabled =
    renderersEnabled || resolveImageSource != null || onLinksChange != null;

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

  // The WASM loads synchronously on the first parse, so every render, on the
  // server and while hydrating too, has the markdown it was given.
  const parsed = useMemo<ParseResult>(() => {
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
    if (!parsed.ast && isDev) {
      console.error('[EnrichedMarkdownText] Parse failed:', parsed.error);
    }
  }, [parsed]);

  const { ast, collected } = parsed;
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
  // Nothing is known when the parse failed.
  useLinksChange(collected.links, onLinksChange, collected !== EMPTY);

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

  if (!ast) {
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
