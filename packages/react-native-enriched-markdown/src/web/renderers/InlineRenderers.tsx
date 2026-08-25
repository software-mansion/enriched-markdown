import type { MouseEvent } from 'react';
import type { RendererProps, RendererMap } from '../types';
import { extractNodeText } from '../utils';
import { KaTeXRenderer } from './KaTeXRenderer';
import { linkStyleForUrl } from '../styles';

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

function LinkRenderer({
  node,
  style,
  callbacks,
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
