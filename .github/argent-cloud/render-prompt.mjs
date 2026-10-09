#!/usr/bin/env node
//
// Renders .github/argent-cloud/prompt.md into the prompt handed to the Argent
// Cloud agent, substituting the pull request's number, title and body.
//
// The title and body are written by whoever opened the pull request, so they are
// treated as hostile throughout. Three properties matter, and each one is a real
// hole if it is dropped:
//
//   1. They arrive as a JSON file, never as a command-line argument and never as
//      a GitHub Actions expression inside a `run:` block. An expression is pasted
//      into the script's text before bash parses it, so a body is a shell
//      injection; a job output needs a heredoc delimiter the author could forge.
//   2. Substitution is literal and single-pass, so a value is never re-scanned
//      and never interpreted.
//   3. Each value is fenced with a backtick run longer than any inside it, so the
//      agent always sees where the untrusted text ends.
//
// Usage:
//   node render-prompt.mjs --template <f> --pr-context <f> --out <f>
//                          [--operator <f>] [--build-type release|debug]

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const TITLE_LIMIT = 300;
const BODY_LIMIT = 4000;
const FOCUS_LIMIT = 1000;

/** Reads `--flag value` pairs, rejecting anything unrecognised. */
function parseArgs(argv) {
  const known = ['template', 'pr-context', 'operator', 'build-type', 'out'];
  const args = {};
  for (let i = 0; i < argv.length; i += 2) {
    const flag = argv[i].replace(/^--/, '');
    if (!argv[i].startsWith('--') || !known.includes(flag)) {
      fail(`unknown argument ${argv[i]}; expected one of --${known.join(', --')}`);
    }
    if (argv[i + 1] === undefined) {
      fail(`--${flag} needs a value`);
    }
    args[flag] = argv[i + 1];
  }
  for (const required of ['template', 'pr-context', 'out']) {
    if (!args[required]) {
      fail(`--${required} is required`);
    }
  }
  return args;
}

function fail(message) {
  console.error(`::error::render-prompt: ${message}`);
  process.exit(1);
}

/**
 * Strips characters that reach the model but show nothing on screen, so an
 * instruction cannot be smuggled past a human reviewing the same text: C0/C1
 * controls, zero-width and bidi overrides, variation selectors, and the Unicode
 * tag block that encodes hidden ASCII.
 */
function scrub(value) {
  return String(value ?? '')
    .replace(/\r\n?/g, '\n')
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/g, '')
    .replace(/[\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF]/g, '')
    .replace(/[\uFE00-\uFE0F]/g, '')
    .replace(/[\u{E0000}-\u{E007F}]/gu, '');
}

function truncate(value, limit) {
  return value.length > limit ? `${value.slice(0, limit)}\n[truncated]` : value;
}

/**
 * Wraps text in a fence one backtick longer than the longest run it contains,
 * so closing the fence early is impossible rather than merely discouraged.
 */
function fence(text, info = 'text') {
  const runs = [...text.matchAll(/`+/g)].map((match) => match[0].length);
  const bar = '`'.repeat(Math.max(3, Math.max(0, ...runs) + 1));
  return `${bar}${info}\n${text}\n${bar}`;
}

/** Keeps or drops `<!-- IF_X -->...<!-- /IF_X -->` regions. */
function applyRegion(template, name, keep) {
  const region = new RegExp(`[ \\t]*<!--[ \\t]*${name}[ \\t]*-->\\n?([\\s\\S]*?)[ \\t]*<!--[ \\t]*/${name}[ \\t]*-->\\n?`, 'g');
  return template.replace(region, keep ? '$1' : '');
}

/**
 * Replaces every `{{TOKEN}}` in one left-to-right pass. A value is copied to the
 * output and never looked at again, so a body containing the literal text
 * `{{PR_TITLE_BLOCK}}` cannot claim a placeholder of its own, and a `$&` in a
 * title stays literal the way String.replace would not.
 */
function substitute(template, values) {
  const token = /\{\{([A-Z_]+)\}\}/g;
  let out = '';
  let last = 0;
  const seen = new Set();
  for (const match of template.matchAll(token)) {
    const key = match[1];
    if (!(key in values)) {
      fail(`the template uses {{${key}}}, which this script does not provide`);
    }
    seen.add(key);
    out += template.slice(last, match.index) + values[key];
    last = match.index + match[0].length;
  }
  return { rendered: out + template.slice(last), seen };
}

const args = parseArgs(process.argv.slice(2));
const buildType = args['build-type'] ?? 'release';
if (buildType !== 'release' && buildType !== 'debug') {
  fail(`--build-type must be release or debug, not ${buildType}`);
}

let pr;
try {
  pr = JSON.parse(readFileSync(args['pr-context'], 'utf8'));
} catch (error) {
  fail(`could not read ${args['pr-context']}: ${error.message}`);
}

let operator = {};
if (args.operator) {
  try {
    operator = JSON.parse(readFileSync(args.operator, 'utf8'));
  } catch {
    operator = {};
  }
}

const title = truncate(scrub(pr.title).trim(), TITLE_LIMIT) || '(no title)';
const body = truncate(scrub(pr.body).trim(), BODY_LIMIT) || '(no description)';
const focus = truncate(scrub(operator.focus).trim(), FOCUS_LIMIT);

const number = String(pr.number ?? '').replace(/[^0-9]/g, '') || 'unknown';
const head = String(pr.headRefOid ?? '').replace(/[^0-9a-f]/g, '') || 'unknown';
const url = /^https:\/\/github\.com\/[A-Za-z0-9._\/-]+$/.test(String(pr.url ?? ''))
  ? pr.url
  : 'unknown';

let template;
try {
  template = readFileSync(args.template, 'utf8');
} catch (error) {
  fail(`could not read ${args.template}: ${error.message}`);
}

template = applyRegion(template, 'IF_DEBUG_BUILD', buildType === 'debug');
template = applyRegion(template, 'IF_FOCUS', focus !== '');

const values = {
  PR_NUMBER: number,
  PR_URL: url,
  PR_HEAD: head,
  PR_TITLE_BLOCK: fence(title),
  PR_BODY_BLOCK: fence(body, 'markdown'),
  FOCUS_BLOCK: fence(focus),
};

const { rendered, seen } = substitute(template, values);

// A template edit that drops a placeholder would quietly ship a prompt with a
// hole in it, so an unused token is an error rather than a warning. FOCUS_BLOCK
// is exempt: its whole region is dropped when no focus was given.
for (const key of Object.keys(values)) {
  if (!seen.has(key) && !(key === 'FOCUS_BLOCK' && focus === '')) {
    fail(`the template never uses {{${key}}}; the prompt would be missing it`);
  }
}

mkdirSync(dirname(args.out), { recursive: true });
writeFileSync(args.out, rendered);

console.log(
  `Rendered ${args.out} for #${number} (${buildType} build, ` +
    `${title.length} char title, ${body.length} char body` +
    `${focus ? ', with a focus note' : ''}).`
);
