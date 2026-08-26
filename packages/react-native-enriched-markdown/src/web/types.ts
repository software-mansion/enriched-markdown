import type { ComponentType, ReactNode } from 'react';
import type { MarkdownStyleInternal } from '../types/MarkdownStyleInternal';
import type { Styles } from './styles';
import type {
  LinkPressEvent,
  LinkLongPressEvent,
  TaskListItemPressEvent,
} from '../types/events';
import type { KaTeXInstance } from './katex';

export type NodeType =
  | 'Document'
  | 'Paragraph'
  | 'Text'
  | 'Link'
  | 'Heading'
  | 'LineBreak'
  | 'SoftBreak'
  | 'Strong'
  | 'Emphasis'
  | 'Strikethrough'
  | 'Underline'
  | 'Superscript'
  | 'Subscript'
  | 'Highlight'
  | 'Code'
  | 'Image'
  | 'Blockquote'
  | 'UnorderedList'
  | 'OrderedList'
  | 'ListItem'
  | 'CodeBlock'
  | 'ThematicBreak'
  | 'Table'
  | 'TableHead'
  | 'TableBody'
  | 'TableRow'
  | 'TableHeaderCell'
  | 'TableCell'
  | 'LatexMathInline'
  | 'LatexMathDisplay';

export interface NodeAttributes {
  level?: string;
  url?: string;
  title?: string;
  language?: string;
  fenceChar?: string;
  isTask?: string;
  taskChecked?: string;
  /** Stamped by indexTaskItems() — not present in the raw WASM output. */
  taskIndex?: number;
  /** Stamped by markInlineImages() — not present in the raw WASM output. */
  isInline?: boolean;
  colCount?: string;
  headRowCount?: string;
  bodyRowCount?: string;
  align?: 'left' | 'center' | 'right' | 'default';
}

export interface ASTNode {
  type: NodeType;
  /** Present on Text, Code, LatexMathInline, LatexMathDisplay nodes. */
  content?: string;
  /** Present on nodes that carry structural metadata (Heading, Link, etc.). */
  attributes?: NodeAttributes;
  /** Child nodes; absent on leaf nodes (Text, LineBreak, SoftBreak, ThematicBreak). */
  children?: ASTNode[];
}

export interface RendererCallbacks {
  onLinkPress?: (event: LinkPressEvent) => void;
  onLinkLongPress?: (event: LinkLongPressEvent) => void;
  onTaskListItemPress?: (event: TaskListItemPressEvent) => void;
}

export interface RenderCapabilities {
  katex: KaTeXInstance | null;
  /** When false, task list checkboxes render read-only and ignore clicks. */
  enableTaskListItemToggle: boolean;
}

export interface RendererProps {
  node: ASTNode;
  style: MarkdownStyleInternal;
  styles: Styles;
  parentType?: NodeType;
  /** Position among the parent node's children. */
  index?: number;
  callbacks: RendererCallbacks;
  capabilities: RenderCapabilities;
  renderChildren: (node: ASTNode) => ReactNode;
}

export type RendererMap = Partial<
  Record<NodeType, ComponentType<RendererProps>>
>;
