import type { ReactNode } from 'react';
import type {
  ASTNode,
  NodeType,
  RendererCallbacks,
  RenderCapabilities,
  RendererMap,
} from '../types';
import type { MarkdownStyleInternal } from '../../types/MarkdownStyleInternal';
import type { Styles } from '../styles';
import { blockRenderers } from './BlockRenderers';
import { inlineRenderers } from './InlineRenderers';
import { listRenderers } from './ListRenderers';
import { tableRenderers } from './TableRenderers';
import { hasStrongText } from '../utils';

// Their `dir` would hide the cells' text from the table, so the cells resolve
// instead.
const TABLE_PARTS = new Set<NodeType>([
  'Table',
  'TableHead',
  'TableBody',
  'TableRow',
]);

// A replaceable block keeps its identity across inserts above it, so the
// renderer's element (a playing video, a card's state) survives them.
function nodeKey(node: ASTNode, index: number): string | number {
  const blockSlotId = node.attributes?.blockSlotId;
  if (blockSlotId !== undefined) return blockSlotId;
  if (node.type === 'ListItem' && node.attributes?.isTask === 'true') {
    const taskId = node.attributes.taskIndex ?? index;
    return `task-${taskId}-${node.attributes.taskChecked}`;
  }
  return index;
}

const RENDERERS: RendererMap = {
  ...blockRenderers,
  ...inlineRenderers,
  ...listRenderers,
  ...tableRenderers,
};

export interface RenderNodeProps {
  node: ASTNode;
  style: MarkdownStyleInternal;
  styles: Styles;
  callbacks: RendererCallbacks;
  capabilities: RenderCapabilities;
  parentType?: NodeType;
  index?: number;
}

export function RenderNode({
  node,
  style,
  styles,
  callbacks,
  capabilities,
  parentType,
  index,
}: RenderNodeProps): ReactNode {
  const Renderer = RENDERERS[node.type];
  if (!Renderer) return null;

  // Only the outermost blocks get `dir`: a nested one would hide its text from
  // its parent's `dir="auto"` (e.g. `> > مرحبا` would put the outer border on
  // the left). A block with no letters inherits instead of turning LTR.
  const ownCapabilities =
    capabilities.blockDir && !hasStrongText(node)
      ? { ...capabilities, blockDir: undefined }
      : capabilities;
  const childCapabilities =
    ownCapabilities.blockDir && !TABLE_PARTS.has(node.type)
      ? { ...ownCapabilities, blockDir: undefined }
      : ownCapabilities;

  const renderChildren = (childNode: ASTNode): ReactNode =>
    childNode.children?.map((child, childIndex) => (
      <RenderNode
        key={nodeKey(child, childIndex)}
        node={child}
        style={style}
        styles={styles}
        callbacks={callbacks}
        capabilities={childCapabilities}
        parentType={childNode.type}
        index={childIndex}
      />
    )) ?? null;

  return (
    <Renderer
      node={node}
      style={style}
      styles={styles}
      parentType={parentType}
      index={index}
      callbacks={callbacks}
      capabilities={ownCapabilities}
      renderChildren={renderChildren}
    />
  );
}
