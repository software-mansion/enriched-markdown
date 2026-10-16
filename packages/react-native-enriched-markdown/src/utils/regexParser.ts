import type { LinkNativeRegex } from '../EnrichedMarkdownTextInputNativeComponent';
import { isDev } from './isDev';

const DISABLED_REGEX: LinkNativeRegex = {
  pattern: '',
  caseInsensitive: false,
  dotAll: false,
  isDisabled: true,
  isDefault: false,
};

const DEFAULT_REGEX: LinkNativeRegex = {
  pattern: '',
  caseInsensitive: false,
  dotAll: false,
  isDisabled: false,
  isDefault: true,
};

export const toNativeRegexConfig = (
  regex: RegExp | undefined | null
): LinkNativeRegex => {
  if (regex === null) {
    return DISABLED_REGEX;
  }

  if (regex === undefined) {
    return DEFAULT_REGEX;
  }

  const source = regex.source;

  const hasLookbehind = source.includes('(?<=') || source.includes('(?<!');

  if (hasLookbehind) {
    const lookbehindContent = source.match(/\(\?<[=!](.*?)\)/)?.[1] || '';
    if (/[*+{]/.test(lookbehindContent)) {
      if (isDev) {
        console.error(
          'Variable-width lookbehinds are not supported. Using default link regex.'
        );
      }

      return DEFAULT_REGEX;
    }
  }

  return {
    pattern: source,
    caseInsensitive: regex.ignoreCase,
    dotAll: regex.dotAll,
    isDisabled: false,
    isDefault: false,
  };
};
