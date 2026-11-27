// Builds the text of the pull request comment for an Argent Cloud run: the
// report the agent wrote, and a footer pointing at the run. `argent-cloud
// comment` posts it and puts the session's screenshots inline under it, so the
// images never pass through here.
//
// The report goes in as markdown, as the agent wrote it. The CLI's trailing
// `session-id=<ID>` line is dropped: the workflow needs it to fetch the
// screenshots, a reader of the comment does not.
//
// Usage:
//   node render-comment.mjs --report <f> --has-screenshots <true|false>
//                           --number <n> --run-url <url> --artifact <name>
//                           --out <f>

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

// GitHub rejects a comment body over 65536 characters, and the screenshots the
// CLI appends count against the same limit. The report is the only part this
// script writes that can grow without bound, so it is capped well short of it.
const REPORT_LIMIT = 50000;

function arg(name, { required = true } = {}) {
  const index = process.argv.indexOf(`--${name}`);
  const value = index === -1 ? undefined : process.argv[index + 1];
  if (required && (value === undefined || value.startsWith('--'))) {
    throw new Error(`--${name} is required`);
  }
  return value && value.startsWith('--') ? undefined : value;
}

const reportPath = arg('report');
const hasScreenshots = arg('has-screenshots') === 'true';
const number = arg('number');
const runUrl = arg('run-url');
const artifact = arg('artifact');
const outPath = arg('out');

// A session that died before writing anything still gets a comment, because
// "the agent produced nothing" is a result a maintainer needs to see.
let report = '';
try {
  report = readFileSync(reportPath, 'utf8')
    .split('\n')
    .filter((line) => !/^session-id=/.test(line.trim()))
    .join('\n')
    .trim();
} catch {
  report = '';
}
if (report.length > REPORT_LIMIT) {
  report = `${report.slice(0, REPORT_LIMIT)}\n[truncated - the full report is output.log in the ${artifact} artifact]`;
}

const lines = [`### Argent Cloud - #${number}`, ''];

if (!hasScreenshots) {
  lines.push(
    '> [!WARNING]',
    '> The agent archived no screenshots. Its report may still cite them by number;',
    '> those numbers refer to images that were not saved.',
    ''
  );
}

lines.push(
  report
    ? report
    : '_The agent produced no report. The step log in the run has whatever it managed to print._',
  '',
  `<sub><a href="${runUrl}">run log</a> · the screenshots archive and the agent's turn-by-turn commentary are in the <code>${artifact}</code> artifact (14 days)</sub>`
);

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, `${lines.join('\n')}\n`);
console.log(`Wrote ${outPath}: ${report.length} chars of report, screenshots ${hasScreenshots ? 'follow' : 'missing'}`);
