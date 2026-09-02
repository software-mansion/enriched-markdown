import type { KeyboardEvent } from 'react';
import { extractNodeText, filenameFromUrl } from '../utils';
import type { RendererProps, RendererMap } from '../types';
import { toHeadingLevel } from '../styles';
import { KaTeXRenderer } from './KaTeXRenderer';

function ParagraphRenderer({
  node,
  styles,
  parentType,
  renderChildren,
}: RendererProps) {
  const isImageOnly =
    node.children?.length === 1 && node.children[0]?.type === 'Image';
  if (isImageOnly) return <>{renderChildren(node)}</>;

  if (parentType === 'Blockquote') {
    return <p style={styles.paragraphInBlockquote}>{renderChildren(node)}</p>;
  }

  if (parentType === 'ListItem') {
    return <span>{renderChildren(node)}</span>;
  }

  return <p style={styles.paragraph}>{renderChildren(node)}</p>;
}

function HeadingRenderer({ node, styles, renderChildren }: RendererProps) {
  const Tag = toHeadingLevel(node.attributes?.level ?? '1');
  return <Tag style={styles[Tag]}>{renderChildren(node)}</Tag>;
}

function BlockquoteRenderer({ node, styles, renderChildren }: RendererProps) {
  return (
    <blockquote style={styles.blockquote}>{renderChildren(node)}</blockquote>
  );
}

function CodeBlockRenderer({ node, styles, renderChildren }: RendererProps) {
  const language = node.attributes?.language;
  const label = language ? `Code block: ${language}` : 'Code block';

  return (
    <pre style={styles.codeBlock} aria-label={label}>
      <code style={styles.codeBlockFont}>{renderChildren(node)}</code>
    </pre>
  );
}

function ThematicBreakRenderer({ styles }: RendererProps) {
  return <hr style={styles.thematicBreak} />;
}

// Each blank line in the source becomes one empty line. Rendered as a spacer
// sized to the paragraph line height (rather than a run of <br>, whose height
// would follow the container line height) so the vertical rhythm matches the
// surrounding paragraphs. Any extra block spacing is left to the caller.
function BlankLineRenderer({ node, style }: RendererProps) {
  const count = Number.parseInt(node.attributes?.count ?? '0', 10);
  const lines = Number.isFinite(count) ? Math.max(0, count) : 0;
  if (lines === 0) return null;
  return (
    <div
      aria-hidden="true"
      style={{ height: lines * style.paragraph.lineHeight }}
    />
  );
}

function ImageRenderer({ node, styles, parentType, callbacks }: RendererProps) {
  const url = node.attributes?.url;
  if (!url) return null;

  const title = node.attributes?.title;
  const markdownAlt = extractNodeText(node).trim();
  const alt = markdownAlt || title || filenameFromUrl(url) || 'Image';
  const imgStyle = node.attributes?.isInline
    ? styles.inlineImage
    : styles.image;

  const interactive =
    callbacks.onImagePress != null &&
    parentType !== 'Link' &&
    parentType !== 'TableCell' &&
    parentType !== 'TableHeaderCell';
  if (!interactive) {
    return <img src={url} alt={alt} title={title} style={imgStyle} />;
  }

  const press = () => callbacks.onImagePress?.({ url, altText: markdownAlt });
  const handleKeyDown = (event: KeyboardEvent<HTMLImageElement>) => {
    if (event.repeat) return;
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      press();
    }
  };

  return (
    <img
      src={url}
      alt={alt}
      title={title}
      style={imgStyle}
      role="button"
      tabIndex={0}
      aria-label={alt}
      onClick={press}
      onKeyDown={handleKeyDown}
    />
  );
}

function LatexMathDisplayRenderer({
  node,
  styles,
  capabilities,
}: RendererProps) {
  const content = extractNodeText(node);

  return (
    <KaTeXRenderer
      content={content}
      katex={capabilities.katex}
      displayMode
      style={styles.mathDisplay}
    />
  );
}

export const blockRenderers: RendererMap = {
  Paragraph: ParagraphRenderer,
  Heading: HeadingRenderer,
  Blockquote: BlockquoteRenderer,
  CodeBlock: CodeBlockRenderer,
  ThematicBreak: ThematicBreakRenderer,
  BlankLine: BlankLineRenderer,
  Image: ImageRenderer,
  LatexMathDisplay: LatexMathDisplayRenderer,
};
