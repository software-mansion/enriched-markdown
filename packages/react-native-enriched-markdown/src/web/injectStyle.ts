/// <reference lib="dom" />

/**
 * Idempotently injects a `<style>` rule into `document.head`.
 *
 * Safe on SSR (no-op when `document` is undefined) and HMR (de-duped by `id`).
 * Intended for module-level invocation: `N` mounted components produce a
 * single `<style>` tag in the DOM.
 */
export const injectStyleOnce = (
  id: string,
  css: string,
  doc: Document | undefined = typeof document === 'undefined'
    ? undefined
    : document
): void => {
  if (!doc) return;
  if (doc.getElementById(id) != null) return;
  const style = doc.createElement('style');
  style.id = id;
  style.textContent = css;
  doc.head.appendChild(style);
};
