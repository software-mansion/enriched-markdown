import { useEffect, useState, type MouseEvent } from 'react';
import type { RendererProps, RendererMap } from '../types';
import { extractNodeText } from '../utils';
import { KaTeXRenderer } from './KaTeXRenderer';
import {
  linkPillIconStyle,
  linkPillLabelStyle,
  linkPillStyle,
  linkStyleForUrl,
} from '../styles';
import { iconFailedRecently, linkPillFor, markIconFailed } from '../linkPills';

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

function CodeRenderer({ node, styles, renderChildren }: RendererProps) {
  return (
    <code style={styles.code}>{node.content ?? renderChildren(node)}</code>
  );
}

/**
 * Like native, the icon keeps its slot while it loads and gives it up if the
 * source fails, and a source that failed is skipped for 30 seconds. A tint is a
 * CSS mask, which cannot report failure, so the source is probed with an Image.
 * Keyed by `iconUri`, so a new source starts over.
 */
function LinkPillIcon({
  iconUri,
  tintColor,
}: {
  iconUri: string;
  tintColor: string | undefined;
}) {
  const [failed, setFailed] = useState(() => iconFailedRecently(iconUri));
  const fail = () => {
    markIconFailed(iconUri);
    setFailed(true);
  };

  useEffect(() => {
    if (!tintColor || failed) return undefined;
    let active = true;
    const probe = new Image();
    probe.onerror = () => {
      if (!active) return;
      markIconFailed(iconUri);
      setFailed(true);
    };
    probe.src = iconUri;
    return () => {
      active = false;
    };
  }, [iconUri, tintColor, failed]);

  if (failed) return null;
  if (tintColor) {
    return <span aria-hidden style={linkPillIconStyle(iconUri, tintColor)} />;
  }
  return (
    <img
      alt=""
      src={iconUri}
      style={linkPillIconStyle(iconUri, undefined)}
      onError={fail}
    />
  );
}

function LinkRenderer({
  node,
  style,
  callbacks,
  capabilities,
  renderChildren,
}: RendererProps) {
  const url = node.attributes?.url;

  if (!url) return <>{renderChildren(node)}</>;

  const handleClick = (event: MouseEvent) => {
    if (callbacks.onLinkPress) {
      event.preventDefault();
      callbacks.onLinkPress({ url });
    }
  };

  const handleContextMenu = (event: MouseEvent) => {
    if (callbacks.onLinkLongPress) {
      event.preventDefault();
      callbacks.onLinkLongPress({ url });
    }
  };

  const variant = linkPillFor(style, node);
  if (variant) {
    const { pill } = variant;
    const content = capabilities.linkPillContent?.[url];
    const originalText = extractNodeText(node);
    const label = content?.label || pill.label || undefined;
    const iconUri = content?.iconUri || pill.iconUri;
    // A per-link icon keeps its colors unless its own entry tints it.
    const iconTintColor =
      content?.iconTintColor ??
      (content?.iconUri ? undefined : pill.iconTintColor);
    const accessibleName =
      label && label !== originalText ? `${label}, ${originalText}` : undefined;

    return (
      <a
        href={url}
        style={{
          ...linkStyleForUrl(style, url),
          ...linkPillStyle(pill, variant.backgroundColor),
        }}
        target="_blank"
        rel="noopener noreferrer"
        aria-label={accessibleName}
        onClick={handleClick}
        onContextMenu={handleContextMenu}
      >
        {iconUri ? (
          <LinkPillIcon
            key={iconUri}
            iconUri={iconUri}
            tintColor={iconTintColor ? String(iconTintColor) : undefined}
          />
        ) : null}
        <span style={linkPillLabelStyle}>{label ?? renderChildren(node)}</span>
      </a>
    );
  }

  return (
    <a
      href={url}
      style={linkStyleForUrl(style, url)}
      target="_blank"
      rel="noopener noreferrer"
      onClick={handleClick}
      onContextMenu={handleContextMenu}
    >
      {renderChildren(node)}
    </a>
  );
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
  Code: CodeRenderer,
  Link: LinkRenderer,
  LatexMathInline: LatexMathInlineRenderer,
};
