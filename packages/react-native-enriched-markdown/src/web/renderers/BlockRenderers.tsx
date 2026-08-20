import type { CSSProperties } from 'react';
import { extractNodeText, filenameFromUrl } from '../utils';
import type { RendererProps, RendererMap } from '../types';
import { toHeadingLevel } from '../styles';
import { KaTeXRenderer } from './KaTeXRenderer';
import {
  ADMONITION_ICON_PATHS,
  ADMONITION_ICON_VIEWBOX,
  ADMONITION_TITLES,
} from './admonitionIcons';
import type { AdmonitionType } from '../../admonitionDefaults';

function ParagraphRenderer({
  node,
  styles,
  parentType,
  renderChildren,
}: RendererProps) {
  const isImageOnly =
    node.children?.length === 1 && node.children[0]?.type === 'Image';
  if (isImageOnly) return <>{renderChildren(node)}</>;

  if (parentType === 'Blockquote' || parentType === 'Admonition') {
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

function AdmonitionRenderer({
  node,
  style,
  styles,
  renderChildren,
}: RendererProps) {
  const type = (node.attributes?.admonitionType ?? 'note') as AdmonitionType;
  const blockquote = style.blockquote;
  const colors = blockquote.admonitions[type] ?? blockquote.admonitions.note;
  const tint = colors.color;
  const iconSize = Math.ceil(blockquote.fontSize);
  // Reuse the blockquote box geometry; override the accent bar + fill per type.
  const boxStyle: CSSProperties = {
    ...styles.blockquote,
    borderInlineStart: `${blockquote.borderWidth}px solid ${tint}`,
    backgroundColor: colors.backgroundColor,
  };
  const headerStyle: CSSProperties = {
    display: 'flex',
    alignItems: 'center',
    gap: Math.round(iconSize * 0.4),
    marginBottom: Math.round(blockquote.fontSize * 0.4),
    color: tint,
    fontWeight: 'bold',
    fontSize: blockquote.fontSize,
    lineHeight: 1.2,
  };
  return (
    <div style={boxStyle}>
      <div style={headerStyle}>
        <svg
          width={iconSize}
          height={iconSize}
          viewBox={`0 0 ${ADMONITION_ICON_VIEWBOX} ${ADMONITION_ICON_VIEWBOX}`}
          fill={tint}
          aria-hidden="true"
        >
          <path d={ADMONITION_ICON_PATHS[type]} />
        </svg>
        <span>{ADMONITION_TITLES[type]}</span>
      </div>
      {renderChildren(node)}
    </div>
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

function ImageRenderer({ node, styles }: RendererProps) {
  const url = node.attributes?.url;
  if (!url) return null;

  const title = node.attributes?.title;
  const alt = extractNodeText(node) || title || filenameFromUrl(url) || 'Image';
  const imgStyle = node.attributes?.isInline
    ? styles.inlineImage
    : styles.image;
  return <img src={url} alt={alt} title={title} style={imgStyle} />;
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
  Admonition: AdmonitionRenderer,
  CodeBlock: CodeBlockRenderer,
  ThematicBreak: ThematicBreakRenderer,
  Image: ImageRenderer,
  LatexMathDisplay: LatexMathDisplayRenderer,
};
