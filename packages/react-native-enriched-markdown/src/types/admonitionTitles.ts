export type AdmonitionType =
  | 'note'
  | 'tip'
  | 'important'
  | 'warning'
  | 'caution';

/** Admonition header titles by type; an empty string shows the icon only. */
export type AdmonitionTitles = Partial<Record<AdmonitionType, string>>;
