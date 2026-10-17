// Builds the pull request comment for an Argent Cloud run: the screenshots the
// agent took, inline, above the report it wrote.
//
// The report is a model's prose, shaped by the pull request's own title, body
// and diff, so it is the same class of input render-prompt.mjs handles and it
// gets the same treatment: fenced with a backtick run longer than any inside
// it, never interpolated into markup. Rendering it as markdown instead would
// let a pull request author draw a convincing "approved by a maintainer" block,
// or an <img> that reports a reader's address to a third party, inside a comment
// that looks like it came from CI.
//
// The screenshot filenames are untrusted for the same reason - the agent chooses
// them inside the session - so the caption is stripped to a known alphabet and
// the number comes from the filename only after it parses as a small integer.
//
// Usage:
//   node render-comment.mjs --report <f> --screenshots <dir> --base-url <url>
//                           --number <n> --run-url <url> --artifact <name>
//                           [--session <id>] --out <f>

import { readFileSync, writeFileSync, readdirSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';

// GitHub rejects a comment body over 65536 characters. The report is the only
// part that can grow without bound, so it absorbs the whole allowance minus
// generous room for the table and the headings.
const REPORT_LIMIT = 50000;
const CAPTION_LIMIT = 60;
// The workflow numbers an unnumbered screenshot from 900 up, so it keeps its
// place in the order without claiming a number the report cites.
const PLACEHOLDER_ORDER = 900;

function arg(name, { required = true } = {}) {
  const index = process.argv.indexOf(`--${name}`);
  const value = index === -1 ? undefined : process.argv[index + 1];
  if (required && (value === undefined || value.startsWith('--'))) {
    throw new Error(`--${name} is required`);
  }
  return value && value.startsWith('--') ? undefined : value;
}

/**
 * Wraps text in a fence one backtick longer than the longest run it contains,
 * so closing the fence early is impossible rather than merely discouraged.
 * Same rule as render-prompt.mjs, for the same reason.
 */
function fence(text, info = 'text') {
  const runs = [...text.matchAll(/`+/g)].map((match) => match[0].length);
  const bar = '`'.repeat(Math.max(3, Math.max(0, ...runs) + 1));
  return `${bar}${info}\n${text}\n${bar}`;
}

/**
 * `04-playground-lineheight.jpg` -> { order: 4, caption: 'playground lineheight' }.
 * PNG as well as JPEG, because the prepare step falls back to the original file
 * when it cannot find an image converter, and a big screenshot beats none.
 * A name that does not match the shape the workflow writes still renders; it
 * just sorts last and captions itself, because a missing screenshot is worse
 * than an ugly one.
 */
function describe(file, index) {
  const match = /^(\d{1,3})-(.*)\.(?:jpg|png)$/.exec(file);
  const order = match ? Number(match[1]) : 1000 + index;
  const rest = match ? match[2] : file.replace(/\.(?:jpg|png)$/, '');
  const caption = rest
    .replace(/[^A-Za-z0-9._-]+/g, ' ')
    .replace(/[-_]+/g, ' ')
    .trim()
    .slice(0, CAPTION_LIMIT);
  return { file, order, caption };
}

const reportPath = arg('report');
const screenshotDir = arg('screenshots');
const baseUrl = arg('base-url');
const number = arg('number');
const runUrl = arg('run-url');
const artifact = arg('artifact');
const session = arg('session', { required: false }) || 'unknown';
const outPath = arg('out');

// A session that died before writing anything still gets a comment, because
// "the agent produced nothing" is a result a maintainer needs to see.
let report = '';
try {
  report = readFileSync(reportPath, 'utf8').trim();
} catch {
  report = '';
}
if (report.length > REPORT_LIMIT) {
  report = `${report.slice(0, REPORT_LIMIT)}\n[truncated - the full report is output.log in the ${artifact} artifact]`;
}

let shots = [];
try {
  shots = readdirSync(screenshotDir)
    .filter((file) => /\.(jpg|png)$/.test(file))
    .map(describe)
    .sort((a, b) => a.order - b.order);
} catch {
  shots = [];
}

const lines = [`### Argent Cloud - #${number}`, ''];

if (shots.length > 0) {
  // An HTML table rather than a markdown one: the cells hold <img> and a <sub>
  // caption, and a two-column grid keeps six phone screenshots from filling a
  // page each. Every image links to its own full-size copy.
  lines.push('<table>');
  for (let i = 0; i < shots.length; i += 2) {
    const cells = shots.slice(i, i + 2).map(({ file, order, caption }) => {
      const url = `${baseUrl}/${encodeURIComponent(file)}`;
      // An unnumbered screenshot gets its caption and no number: the numbers
      // exist to match the ones the report cites, and inventing one the report
      // never mentions is worse than leaving it off.
      const label = order < PLACEHOLDER_ORDER ? `<b>${order}</b> ${caption}` : caption;
      return `<td width="50%"><a href="${url}"><img src="${url}" width="100%" alt="${caption || 'screenshot'}"></a><br><sub>${label}</sub></td>`;
    });
    lines.push(`<tr>${cells.join('')}</tr>`);
  }
  lines.push('</table>', '');
} else {
  lines.push(
    '> [!WARNING]',
    '> The agent archived no screenshots. Its report may still cite them by number;',
    '> those numbers refer to images that were not saved.',
    ''
  );
}

lines.push(
  report
    ? fence(report)
    : '_The agent produced no report. The step log in the run has whatever it managed to print._',
  '',
  `<sub>Session <code>${session}</code> · <a href="${runUrl}">run log</a> · full-resolution PNGs and the agent's turn-by-turn commentary are in the <code>${artifact}</code> artifact (14 days)</sub>`
);

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, `${lines.join('\n')}\n`);
console.log(`Wrote ${outPath}: ${shots.length} screenshot(s), ${report.length} chars of report`);
