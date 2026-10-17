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

  const renderChildren = (childNode: ASTNode): ReactNode =>
    childNode.children?.map((child, childIndex) => (
      <RenderNode
        key={nodeKey(child, childIndex)}
        node={child}
        style={style}
        styles={styles}
        callbacks={callbacks}
        capabilities={capabilities}
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
      capabilities={capabilities}
      renderChildren={renderChildren}
    />
  );
}
