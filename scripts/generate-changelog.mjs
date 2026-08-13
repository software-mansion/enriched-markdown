#!/usr/bin/env node
// Prints GitHub-release-style markdown for all commits since a tag.
// Usage: ./scripts/generate-changelog.mjs <from-tag> [to-ref] | pbcopy
import { execFileSync } from 'node:child_process';

const REPO = 'software-mansion/react-native-enriched-markdown';
const [OWNER, NAME] = REPO.split('/');

const SECTIONS = [
  { title: 'New Features', types: ['feat'] },
  { title: 'Fixes & Improvements', types: ['fix', 'perf'] },
  { title: 'Refactors', types: ['refactor'] },
  { title: 'Tests', types: ['test'] },
  { title: 'Docs & Chores', types: ['docs', 'chore', 'build', 'ci'] },
  { title: 'Other Changes', types: [] },
];

function git(...args) {
  return execFileSync('git', args, { encoding: 'utf8' }).trim();
}

function ghGraphql(query) {
  try {
    const out = execFileSync('gh', ['api', 'graphql', '-f', `query=${query}`], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return JSON.parse(out);
  } catch (e) {
    // gh exits non-zero on partial GraphQL errors but still prints the data
    if (e.stdout) {
      try {
        return JSON.parse(e.stdout);
      } catch {}
    }
    throw e;
  }
}

const [from, to = 'HEAD'] = process.argv.slice(2);
if (!from) {
  console.error('usage: ./scripts/generate-changelog.mjs <from-tag> [to-ref]');
  process.exit(1);
}
for (const ref of [from, to]) {
  try {
    git('rev-parse', '--verify', '--quiet', `${ref}^{commit}`);
  } catch {
    console.error(`error: '${ref}' is not a known git ref`);
    process.exit(1);
  }
}

const SEP = '\x1f';
const log = git('log', '--reverse', `--format=%H${SEP}%an${SEP}%ae${SEP}%s`, `${from}..${to}`);
const commits = (log ? log.split('\n') : [])
  .map((line) => {
    const [hash, name, email, subject] = line.split(SEP);
    const pr = subject.match(/\(#(\d+)\)\s*$/)?.[1];
    const title = subject.replace(/\s*\(#\d+\)\s*$/, '');
    const type = title
      .match(/^\s*([a-zA-Z]+)\s*(?:\([^)]*\))?\s*!?\s*:/)?.[1]
      ?.toLowerCase();
    return { hash, name, email, title, pr, type };
  })
  .filter((c) => !/dependabot|github-actions|\[bot\]/i.test(`${c.name} ${c.email}`));

if (!commits.length) {
  console.error(`no commits in ${from}..${to}`);
  process.exit(1);
}

const prNumbers = [...new Set(commits.filter((c) => c.pr).map((c) => c.pr))];
const loginByPr = new Map();
try {
  for (let i = 0; i < prNumbers.length; i += 50) {
    const chunk = prNumbers.slice(i, i + 50);
    const fields = chunk
      .map((n) => `pr${n}: pullRequest(number: ${n}) { author { login } }`)
      .join(' ');
    const data = ghGraphql(
      `query { repository(owner: "${OWNER}", name: "${NAME}") { ${fields} } }`
    );
    for (const n of chunk) {
      const login = data.data?.repository?.[`pr${n}`]?.author?.login;
      if (login) loginByPr.set(n, login);
    }
  }
} catch {
  console.error('warning: gh author lookup failed, falling back to commit author names');
}

function authorRef(c) {
  const login =
    (c.pr && loginByPr.get(c.pr)) ||
    c.email.match(/^(?:\d+\+)?([^@]+)@users\.noreply\.github\.com$/)?.[1];
  return login ? `[@${login}](https://github.com/${login})` : c.name;
}

function itemLine(c) {
  const where = c.pr
    ? `[#${c.pr}](https://github.com/${REPO}/pull/${c.pr})`
    : `[\`${c.hash.slice(0, 7)}\`](https://github.com/${REPO}/commit/${c.hash})`;
  return `* ${c.title} by ${authorRef(c)} in ${where}`;
}

const typeToTitle = new Map(
  SECTIONS.flatMap((s) => s.types.map((t) => [t, s.title]))
);
const byTitle = new Map(SECTIONS.map((s) => [s.title, []]));
for (const c of commits) {
  byTitle.get(typeToTitle.get(c.type) ?? 'Other Changes').push(c);
}

const out = ["# What's Changed"];
for (const s of SECTIONS) {
  const items = byTitle.get(s.title);
  if (!items.length) continue;
  out.push('', `## ${s.title}`, '', ...items.map(itemLine));
}

// first in-range PR per login, then keep only logins with no merged PR before the tag
const firstPrByLogin = new Map();
for (const c of commits) {
  const login = c.pr && loginByPr.get(c.pr);
  if (login && !firstPrByLogin.has(login)) firstPrByLogin.set(login, c.pr);
}
let newContributors = [];
if (firstPrByLogin.size) {
  try {
    const cutoff = git('log', '-1', '--format=%cI', from);
    const logins = [...firstPrByLogin.keys()];
    for (let i = 0; i < logins.length; i += 25) {
      const chunk = logins.slice(i, i + 25);
      const fields = chunk
        .map(
          (l, j) =>
            `u${j}: search(query: "repo:${REPO} is:pr is:merged author:${l} merged:<${cutoff}", type: ISSUE, first: 1) { issueCount }`
        )
        .join(' ');
      const data = ghGraphql(`query { ${fields} }`);
      newContributors.push(
        ...chunk.filter((l, j) => data.data?.[`u${j}`]?.issueCount === 0)
      );
    }
  } catch {
    console.error('warning: new-contributor lookup failed, skipping that section');
  }
}
if (newContributors.length) {
  out.push(
    '',
    '## New Contributors',
    '',
    ...newContributors.map((l) => {
      const pr = firstPrByLogin.get(l);
      return `* [@${l}](https://github.com/${l}) made their first contribution in [#${pr}](https://github.com/${REPO}/pull/${pr})`;
    })
  );
}

out.push(
  '',
  `**Full Changelog**: https://github.com/${REPO}/compare/${from}...${to === 'HEAD' ? 'main' : to}`
);
console.log(out.join('\n'));
