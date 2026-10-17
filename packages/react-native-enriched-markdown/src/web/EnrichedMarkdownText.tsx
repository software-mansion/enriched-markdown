import {
  useState,
  useEffect,
  useMemo,
  useRef,
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
import { parseMarkdown } from './parseMarkdown';
import { recognizeTextLinks } from './recognizeTextLinks';
import { RenderNode } from './renderers';
import type { ASTNode, RendererCallbacks, RenderCapabilities } from './types';
import { indexTaskItems, markInlineImages } from './utils';
import { collectBlocks } from './blockSlots';
import { useResolvedImageSources } from '../imageSources';
import { renderBlock } from '../blockRenderers';
import type {
  MarkdownBlock,
  MarkdownImageOccurrence,
} from '../types/MarkdownTextProps';
import { loadKaTeX } from './katex';
import type { KaTeXInstance } from './katex';
import { ENRM_TEXT_CLASS, ENRM_SELECTION_BG_VAR } from './globalStyles';
import { filterNativeOnlyProps } from './nativeProps';

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
  ...rest
}: EnrichedMarkdownTextProps) => {
  const normalizedStyle = useMemo(
    () => normalizeMarkdownStyle(markdownStyle),
    [markdownStyle]
  );

  const [ast, setAst] = useState<ASTNode | null>(null);
  const [collected, setCollected] = useState<{
    blocks: MarkdownBlock[];
    images: MarkdownImageOccurrence[];
  }>({ blocks: [], images: [] });
  const [katex, setKatex] = useState<KaTeXInstance | null>(null);
  const [parseError, setParseError] = useState<boolean>(false);

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
  const linkRecognitionRef = useRef(linkRecognition);
  linkRecognitionRef.current = linkRecognition;
  const textLinkKey = linkRecognition?.text?.toString() ?? null;
  const inlineCodeLinkKey = linkRecognition?.inlineCode?.toString() ?? null;

  useEffect(() => {
    let cancelled = false;

    const katexPromise = latexMath ? loadKaTeX() : Promise.resolve(null);

    Promise.all([
      parseMarkdown(markdown, {
        underline,
        latexMath,
        superscript,
        subscript,
        highlight,
        hardSoftBreaks,
        preserveBlankLines,
        admonitions,
      }),
      katexPromise,
    ])
      .then(([result, katexInstance]) => {
        if (!cancelled) {
          indexTaskItems(result);
          markInlineImages(result);
          setCollected(collectBlocks(result));

          setParseError(false);
          setKatex(katexInstance);
          setAst(
            recognizeTextLinks(
              result,
              linkRecognitionRef.current?.text,
              linkRecognitionRef.current?.inlineCode
            )
          );
        }
      })
      .catch((error) => {
        if (!cancelled) {
          if (__DEV__) {
            console.error('[EnrichedMarkdownText] Parse failed:', error);
          }

          setParseError(true);
          setAst(null);
          setKatex(null);
        }
      });

    return () => {
      cancelled = true;
    };
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
  ]);

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

  const renderImage = renderers?.image;
  const renderVideo = renderers?.video;
  const renderLink = renderers?.link;
  const blockSlots = useMemo(() => {
    if (!renderImage && !renderVideo && !renderLink) return undefined;
    const slots = new Map<string, ReactNode>();
    const kinds = { image: renderImage, video: renderVideo, link: renderLink };
    for (const block of collected.blocks) {
      const element = renderBlock(kinds, block);
      if (element != null) slots.set(block.id, element);
    }
    return slots;
  }, [collected, renderImage, renderVideo, renderLink]);

  const imageSources = useImageSources(collected.images, resolveImageSource);

  const capabilities = useMemo<RenderCapabilities>(
    () => ({ katex, enableTaskListItemToggle, blockSlots, imageSources }),
    [katex, enableTaskListItemToggle, blockSlots, imageSources]
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

  if (parseError) {
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
    for (const [id, source] of resolved) {
      if (source === null) continue;
      result.set(id, source === undefined ? null : source.uri || null);
    }
    return result;
  }, [resolved]);
}

export default EnrichedMarkdownText;
