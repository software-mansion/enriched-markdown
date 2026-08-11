import { useState, useEffect, useMemo, type CSSProperties } from 'react';
import type { EnrichedMarkdownTextProps } from '../types/MarkdownTextProps.web';
import { normalizeMarkdownStyle } from '../normalizeMarkdownStyle.web';
import {
  zeroTrailingMargins,
  parseErrorFallbackStyle,
  buildStyles,
} from './styles';
import { parseMarkdown } from './parseMarkdown';
import { RenderNode } from './renderers';
import type { ASTNode, RendererCallbacks, RenderCapabilities } from './types';
import { indexTaskItems, markInlineImages } from './utils';
import { loadKaTeX } from './katex';
import type { KaTeXInstance } from './katex';
import { ENRM_TEXT_CLASS, ENRM_SELECTION_BG_VAR } from './globalStyles';

export const EnrichedMarkdownText = ({
  markdown,
  markdownStyle = {},
  md4cFlags = {},
  onLinkPress,
  onLinkLongPress,
  onTaskListItemPress,
  enableTaskListItemToggle = true,
  allowTrailingMargin = false,
  containerStyle,
  selectable = true,
  dir,
  selectionColor,
  ...rest
}: EnrichedMarkdownTextProps) => {
  const normalizedStyle = useMemo(
    () => normalizeMarkdownStyle(markdownStyle),
    [markdownStyle]
  );

  const [ast, setAst] = useState<ASTNode | null>(null);
  const [katex, setKatex] = useState<KaTeXInstance | null>(null);
  const [parseError, setParseError] = useState<boolean>(false);

  const {
    underline = false,
    latexMath = true,
    superscript = false,
    subscript = false,
    highlight = false,
    hardSoftBreaks = false,
  } = md4cFlags;

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
      }),
      katexPromise,
    ])
      .then(([result, katexInstance]) => {
        if (!cancelled) {
          indexTaskItems(result);
          markInlineImages(result);

          setParseError(false);
          setKatex(katexInstance);
          setAst(result);
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
  ]);

  const callbacks = useMemo<RendererCallbacks>(
    () => ({ onLinkPress, onLinkLongPress, onTaskListItemPress }),
    [onLinkPress, onLinkLongPress, onTaskListItemPress]
  );

  const capabilities = useMemo<RenderCapabilities>(
    () => ({ katex, enableTaskListItemToggle }),
    [katex, enableTaskListItemToggle]
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

  if (parseError) {
    return (
      <div className={ENRM_TEXT_CLASS} style={wrapperStyle} dir={dir} {...rest}>
        <pre style={parseErrorFallbackStyle}>{markdown}</pre>
      </div>
    );
  }

  if (!ast) return null;

  const children = ast.children ?? [];
  const lastIdx = children.length - 1;

  return (
    <div className={ENRM_TEXT_CLASS} style={wrapperStyle} dir={dir} {...rest}>
      {children.map((child, index) => (
        <RenderNode
          key={`${child.type}-${index}`}
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

export default EnrichedMarkdownText;
