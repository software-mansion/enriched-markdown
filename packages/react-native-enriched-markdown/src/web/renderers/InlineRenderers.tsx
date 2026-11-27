import { useContext, useState } from 'react';
import type { CSSProperties, KeyboardEvent, MouseEvent } from 'react';
import type { ASTNode, RendererProps, RendererMap } from '../types';
import { extractNodeText, hasNonImageContent } from '../utils';
import { KaTeXRenderer } from './KaTeXRenderer';
import {
  ConcealedSpoilerContext,
  ImageOnlySpoilerContext,
  InsideLinkContext,
} from './ConcealedSpoilerContext';
import { linkStyleForUrl } from '../styles';
import {
  ENRM_SPOILER_CLASS,
  ENRM_SPOILER_CONTENT_CLASS,
} from '../globalStyles';

function TextRenderer({ node }: RendererProps) {
  return <>{node.content ?? ''}</>;
}

function LineBreakRenderer(_props: RendererProps) {
  return <br />;
}

function SoftBreakRenderer(_props: RendererProps) {
  return <> </>;
}

function StrongRenderer({ node, styles, renderChildren }: RendererProps) {
  return <strong style={styles.strong}>{renderChildren(node)}</strong>;
}

function EmphasisRenderer({ node, styles, renderChildren }: RendererProps) {
  return <em style={styles.emphasis}>{renderChildren(node)}</em>;
}

function StrikethroughRenderer({
  node,
  styles,
  renderChildren,
}: RendererProps) {
  return <s style={styles.strikethrough}>{renderChildren(node)}</s>;
}

function UnderlineRenderer({ node, styles, renderChildren }: RendererProps) {
  return <u style={styles.underline}>{renderChildren(node)}</u>;
}

function SuperscriptRenderer({ node, styles, renderChildren }: RendererProps) {
  return <sup style={styles.superscript}>{renderChildren(node)}</sup>;
}

function SubscriptRenderer({ node, styles, renderChildren }: RendererProps) {
  return <sub style={styles.subscript}>{renderChildren(node)}</sub>;
}

function HighlightRenderer({ node, styles, renderChildren }: RendererProps) {
  return <mark style={styles.highlight}>{renderChildren(node)}</mark>;
}

const CONCEALED_CONTENT_STYLE: CSSProperties = { opacity: 0 };

function SpoilerRenderer({ node, styles, renderChildren }: RendererProps) {
  const isAncestorConcealed = useContext(ConcealedSpoilerContext);
  const text = extractNodeText(node);
  const [isRevealed, setIsRevealed] = useState(false);
  const [seenText, setSeenText] = useState(text);
  if (seenText !== text) {
    setSeenText(text);
    setIsRevealed(false);
  }

  const handleClick = (event: MouseEvent) => {
    event.preventDefault();
    event.stopPropagation();
    if (window.getSelection()?.isCollapsed === false) return;
    setIsRevealed(true);
  };

  const handleKeyDown = (event: KeyboardEvent) => {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    event.preventDefault();
    event.stopPropagation();
    setIsRevealed(true);
    if (event.currentTarget instanceof HTMLElement) {
      event.currentTarget.closest('a')?.focus();
    }
  };

  const handleContextMenu = (event: MouseEvent) => {
    event.stopPropagation();
  };

  const isActive = !isRevealed && !isAncestorConcealed;
  const isImageOnly = !hasNonImageContent(node);
  const coverStyle = isRevealed
    ? styles.spoilerRevealed
    : isImageOnly
      ? { ...styles.spoilerRevealed, cursor: 'pointer' }
      : styles.spoiler;

  return (
    <span
      className={ENRM_SPOILER_CLASS}
      style={coverStyle}
      data-revealed={isRevealed ? '' : undefined}
      role={isActive ? 'button' : undefined}
      tabIndex={isActive ? 0 : isRevealed ? -1 : undefined}
      onClick={isActive ? handleClick : undefined}
      onKeyDown={isActive ? handleKeyDown : undefined}
      onContextMenu={isActive ? handleContextMenu : undefined}
    >
      <span
        className={ENRM_SPOILER_CONTENT_CLASS}
        style={isRevealed || isImageOnly ? undefined : CONCEALED_CONTENT_STYLE}
      >
        <ConcealedSpoilerContext.Provider
          value={isAncestorConcealed || !isRevealed}
        >
          <ImageOnlySpoilerContext.Provider value={isImageOnly}>
            {renderChildren(node)}
          </ImageOnlySpoilerContext.Provider>
        </ConcealedSpoilerContext.Provider>
      </span>
    </span>
  );
}

function CodeRenderer({ node, styles, renderChildren }: RendererProps) {
  return (
    <code style={styles.code}>{node.content ?? renderChildren(node)}</code>
  );
}

const URL_SCHEME = /^([a-z][a-z0-9+.-]*):/i;
const BROWSER_SCHEMES = new Set(['http', 'https', 'mailto', 'tel', 'sms']);

// Relative URLs and the schemes above are links the browser can open itself.
function isBrowserOpenable(url: string): boolean {
  const scheme = URL_SCHEME.exec(url.trim())?.[1];
  return !scheme || BROWSER_SCHEMES.has(scheme.toLowerCase());
}

function LinkRenderer({
  node,
  style,
  callbacks,
  renderChildren,
}: RendererProps) {
  const url = node.attributes?.url;
  const isConcealed = useContext(ConcealedSpoilerContext);

  if (!url) return <>{renderChildren(node)}</>;

  if (isConcealed) {
    return (
      <span style={linkStyleForUrl(style, url)}>
        <InsideLinkContext.Provider value={true}>
          {renderChildren(node)}
        </InsideLinkContext.Provider>
      </span>
    );
  }

  const handleClick = (event: MouseEvent) => {
    // As in web routers, a modified click (new tab, new window) stays with the browser.
    const isModified =
      event.metaKey || event.ctrlKey || event.shiftKey || event.altKey;
    if (isModified && isBrowserOpenable(url)) return;

    if (callbacks.onLinkPress) {
      event.preventDefault();
      callbacks.onLinkPress({ url });
    }
  };

  const isLabelAllSpoilers = !hasContentOutsideSpoilers(node);
  const handleKeyDown = (event: KeyboardEvent<HTMLAnchorElement>) => {
    if (event.key !== 'Enter' || !isLabelAllSpoilers) return;
    if (event.target !== event.currentTarget) return;
    const link = event.currentTarget;
    if (link.querySelector(`.${ENRM_SPOILER_CLASS}[data-revealed]`)) return;
    const concealed = link.querySelectorAll<HTMLElement>(
      `.${ENRM_SPOILER_CLASS}`
    );
    if (concealed.length === 0) return;
    event.preventDefault();
    concealed.forEach((spoiler) =>
      spoiler.dispatchEvent(
        new window.KeyboardEvent('keydown', { key: 'Enter', bubbles: true })
      )
    );
  };

  const handleContextMenu = (event: MouseEvent) => {
    if (callbacks.onLinkLongPress) {
      event.preventDefault();
      callbacks.onLinkLongPress({ url });
    }
  };

  return (
    <a
      href={url}
      style={linkStyleForUrl(style, url)}
      target="_blank"
      rel="noopener noreferrer"
      onClick={handleClick}
      onKeyDown={handleKeyDown}
      onContextMenu={handleContextMenu}
    >
      <InsideLinkContext.Provider value={true}>
        {renderChildren(node)}
      </InsideLinkContext.Provider>
    </a>
  );
}

function hasContentOutsideSpoilers(node: ASTNode): boolean {
  if (node.type === 'Spoiler') return false;
  if (node.type === 'SoftBreak' || node.type === 'LineBreak') return false;
  if (!node.children?.length) {
    return node.type !== 'Text' || (node.content ?? '').trim() !== '';
  }
  return node.children.some(hasContentOutsideSpoilers);
}

function LatexMathInlineRenderer({
  node,
  styles,
  capabilities,
}: RendererProps) {
  const content = extractNodeText(node);

  return (
    <KaTeXRenderer
      content={content}
      katex={capabilities.katex}
      displayMode={false}
      style={styles.mathInline}
    />
  );
}

export const inlineRenderers: RendererMap = {
  Text: TextRenderer,
  LineBreak: LineBreakRenderer,
  SoftBreak: SoftBreakRenderer,
  Strong: StrongRenderer,
  Emphasis: EmphasisRenderer,
  Strikethrough: StrikethroughRenderer,
  Underline: UnderlineRenderer,
  Superscript: SuperscriptRenderer,
  Subscript: SubscriptRenderer,
  Highlight: HighlightRenderer,
  Spoiler: SpoilerRenderer,
  Code: CodeRenderer,
  Link: LinkRenderer,
  LatexMathInline: LatexMathInlineRenderer,
};
