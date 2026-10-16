import type { ComponentType } from 'react';

export interface CodeBlockRendererProps {
  /** Code content, including its original trailing whitespace. */
  code: string;
  /** Fence language, or an empty string for an unlabelled block. */
  language: string;
}

/** Custom web components. Overrides own their styling and interactions. */
export interface MarkdownRenderers {
  codeBlock?: ComponentType<CodeBlockRendererProps>;
}
