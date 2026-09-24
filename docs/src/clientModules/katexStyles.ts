// The library's web build renders LaTeX math through KaTeX (`renderToString`).
// Loading KaTeX's stylesheet globally makes its output render with the correct
// fonts/metrics; the font files are only fetched by the browser on pages that
// actually contain math, so this is cheap on pages without it.
import 'katex/dist/katex.min.css';
