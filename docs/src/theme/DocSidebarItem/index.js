// t-rex-ui replaces the sidebar's DocSidebarItem with a Category that has no
// manual collapse toggle — it only auto-collapses on navigation, so the caret
// renders but clicking it does nothing (on the browser its href resolves to
// "#" with no onClick handler). We want Pulsar-style groups that expand/collapse
// when pressed, so we re-export the stock Docusaurus dispatcher instead. It uses
// @theme/DocSidebarItem/Category, which t-rex-ui does NOT override, so that
// resolves to the classic component that ships the real toggle + collapse button.
export { default } from '@docusaurus/theme-classic/lib/theme/DocSidebarItem';
