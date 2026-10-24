// t-rex-ui bundles the whole sidebar chain (DocSidebar -> DocSidebarItems ->
// DocSidebarItem -> Category) as one monolith whose Category has no manual
// collapse toggle (see ./DocSidebarItem). Overriding a single level is ignored
// because the parent references the bundled child directly, not the @theme
// alias. So we replace all three levels t-rex provides with the stock Docusaurus
// components, which support Pulsar-style press-to-expand/collapse groups.
export { default } from '@docusaurus/theme-classic/lib/theme/DocSidebar';
