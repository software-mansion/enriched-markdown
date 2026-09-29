export type HeadingLevel = 1 | 2 | 3 | 4 | 5 | 6;

export interface StyleState {
  bold: { isActive: boolean };
  italic: { isActive: boolean };
  underline: { isActive: boolean };
  strikethrough: { isActive: boolean };
  spoiler: { isActive: boolean };
  link: { isActive: boolean };
  heading: { isActive: boolean; level: HeadingLevel };
  unorderedList: { isActive: boolean; depth: number };
  orderedList: { isActive: boolean; depth: number };
}

export interface CaretRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export type MeasureCallback = (
  x: number,
  y: number,
  width: number,
  height: number,
  pageX: number,
  pageY: number
) => void;

export type MeasureInWindowCallback = (
  x: number,
  y: number,
  width: number,
  height: number
) => void;

export type MeasureLayoutCallback = (
  left: number,
  top: number,
  width: number,
  height: number
) => void;

export interface MarkdownTextInputInstance<Node = unknown> {
  focus: () => void;
  blur: () => void;
  measure: (callback: MeasureCallback) => void;
  measureInWindow: (callback: MeasureInWindowCallback) => void;
  measureLayout: (
    relativeTo: number | Node,
    onSuccess: MeasureLayoutCallback,
    onFail?: () => void
  ) => void;
  setValue: (markdown: string) => void;
  setSelection: (start: number, end: number) => void;
  toggleBold: () => void;
  toggleItalic: () => void;
  toggleUnderline: () => void;
  toggleStrikethrough: () => void;
  toggleSpoiler: () => void;
  toggleHeading: (level: HeadingLevel) => void;
  toggleUnorderedList: () => void;
  toggleOrderedList: () => void;
  indentList: () => void;
  outdentList: () => void;
  setLink: (url: string) => void;
  insertLink: (text: string, url: string) => void;
  insertText: (text: string) => void;
  insertMention: (displayText: string, url: string) => void;
  startMention: (indicator: string) => void;
  removeLink: () => void;
  copyToClipboard: () => void;
  getMarkdown: () => Promise<string>;
  getCaretRect: () => Promise<CaretRect>;
}
