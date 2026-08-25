import type { MarkdownStyle } from 'react-native-enriched-markdown';

// Shared markdownStyle for the interactive docs examples.
//
// The values are tuned to read well in Docusaurus' light and dark modes. They
// exist purely to make the rendered markdown match the docs' visual language.
//
// It lives in its own file so the example sources stay focused on the API
// being demonstrated.
export const markdownStyle: MarkdownStyle = {
  h1: { fontSize: 28, marginBottom: 8 },
  h2: { fontSize: 22, marginBottom: 8 },
  paragraph: { fontSize: 16 },
  link: { color: '#57b495' },
  code: { color: '#782aeb', backgroundColor: '#e8dafc' },
  codeblock: { color: '#232736', backgroundColor: '#e2e5ff', borderRadius: 8 },
  blockquote: { borderColor: '#919fcf', borderWidth: 4, gapWidth: 12 },
};
