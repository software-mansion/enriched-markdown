/**
 * Headings can carry a platform badge (`### `dir` <WebBadge />`). Docusaurus
 * serializes heading JSX into the table-of-contents `value` as a raw HTML
 * string (`<code>dir</code><WebBadge></WebBadge>`), which the TOC renders with
 * `dangerouslySetInnerHTML` - so an unknown `<WebBadge>` tag ends up in the DOM
 * rendering nothing.
 *
 * `withPlatformDots` rewrites those tags into a small colored dot pinned to the
 * right of the TOC entry, so platform-specific props are recognizable from the
 * table of contents. Styles live in `src/css/overrides.css`
 * (`.platform-toc-dot`); the colors mirror `./styles.module.css`.
 */

type TOCItem = {
  value: string;
  id: string;
  level: number;
};

const PLATFORMS: Record<string, { modifier: string; label: string }> = {
  androidbadge: {
    modifier: 'platform-toc-dot--android',
    label: 'Android only',
  },
  iosbadge: { modifier: 'platform-toc-dot--ios', label: 'iOS only' },
  webbadge: { modifier: 'platform-toc-dot--web', label: 'Web only' },
};

const BADGE_TAG = /<(AndroidBadge|IosBadge|WebBadge)\b[^>]*>([\s\S]*?)<\/\1>/gi;

function escapeHtml(value: string) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function toDot(name: string, children: string) {
  const platform = PLATFORMS[name.toLowerCase()];
  if (!platform) {
    return null;
  }
  // `<IosBadge>iOS 16+</IosBadge>` overrides the default badge label.
  const label =
    escapeHtml(children.replace(/<[^>]*>/g, '').trim()) || platform.label;
  return `<span class="platform-toc-dot ${platform.modifier}" role="img" aria-label="${label}" title="${label}"></span>`;
}

export function withPlatformDots<T extends TOCItem>(toc: T[] | undefined) {
  if (!toc) {
    return toc;
  }
  return toc.map(item => {
    const dots: string[] = [];
    const value = item.value.replace(BADGE_TAG, (match, name, children) => {
      const dot = toDot(name, children);
      if (!dot) {
        return match;
      }
      dots.push(dot);
      return '';
    });

    if (dots.length === 0) {
      return item;
    }
    return {
      ...item,
      value: `${value.trim()}<span class="platform-toc-dots">${dots.join('')}</span>`,
    };
  });
}
