import type { HeadingLevel } from './types/MarkdownTextInputInstance';

// `StyleState.heading.level` is typed `1..6`, but every platform reports some
// sentinel for "no heading": the web model uses `0`, and a native view can
// hand over whatever its own state struct happens to hold. The type claims
// that cannot happen, so a consumer indexing a `HEADING_SIZES[level]` table
// or switching exhaustively over `1..6` has no branch for it. Both wrappers
// normalize through here rather than casting, so the two agree.
const VALID_HEADING_LEVELS = new Set<number>([1, 2, 3, 4, 5, 6]);

export function toHeadingLevel(level: number): HeadingLevel {
  return (VALID_HEADING_LEVELS.has(level) ? level : 1) as HeadingLevel;
}
