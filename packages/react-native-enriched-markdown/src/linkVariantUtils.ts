import type { LinkVariantStyle } from './types/MarkdownStyle';

type LinkVariantEntry = [pattern: string, style: LinkVariantStyle];

// Lookbehind assertions (?<=...) and (?<!...) are not supported by
// NSRegularExpression on iOS. Warn early so the issue surfaces in JS tests
// before it silently misfires on device.
const UNSAFE_LOOKBEHIND_RE = /\(\?<[=!]/;

function warnAboutUnsafePattern(pattern: string): void {
  if (UNSAFE_LOOKBEHIND_RE.test(pattern)) {
    console.warn(
      `[MarkdownStyle] linkVariants pattern "${pattern}" contains a lookbehind assertion (?<= or ?<!). ` +
        'Lookbehinds are not supported by NSRegularExpression on iOS and will never match. ' +
        'Use a lookahead or restructure the pattern to avoid them.'
    );
  }
}

export function normalizeLinkVariantEntries(
  linkVariants?: Record<string, LinkVariantStyle>
): LinkVariantEntry[] {
  return Object.entries(linkVariants ?? {})
    .sort(([a], [b]) => b.length - a.length)
    .filter(([pattern]) => {
      try {
        RegExp(pattern);
      } catch {
        if (__DEV__) {
          console.warn(
            `[MarkdownStyle] linkVariants pattern "${pattern}" is not a valid regex and will be ignored.`
          );
        }
        return false;
      }

      if (__DEV__) {
        warnAboutUnsafePattern(pattern);
      }
      return true;
    });
}

/** Native pill geometry is finite and nonnegative before crossing codegen. */
export function normalizeLinkPillStyle(style: LinkVariantStyle) {
  const hasConfig = typeof style.pill === 'object' && style.pill !== null;
  const config =
    typeof style.pill === 'object' && style.pill !== null ? style.pill : {};
  const dimension = (value: number | undefined, fallback: number) =>
    value === undefined || !Number.isFinite(value)
      ? fallback
      : Math.max(0, value);
  return {
    pill: style.pill === true || hasConfig,
    borderColor: config.borderColor ?? 'transparent',
    label: config.label ?? '',
    iconUri: config.iconUri ?? '',
    borderRadius: dimension(config.borderRadius, 8),
    paddingHorizontal: dimension(config.paddingHorizontal, 6),
    paddingVertical: dimension(config.paddingVertical, 2),
    borderWidth: dimension(config.borderWidth, 0),
    maxWidth: dimension(config.maxWidth, 0),
  };
}
