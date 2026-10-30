/** Patterns for `linkRecognition`. An omitted key is off. */
export interface LinkRecognition {
  /** Matched inside plain-text runs. */
  text?: RegExp;
  /** Must match an inline-code span's whole content. */
  inlineCode?: RegExp;
}
