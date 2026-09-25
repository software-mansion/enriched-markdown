#!/usr/bin/env node
// Runs the package's opt-in PerformanceBenchmarks on this checkout and, with
// --base <ref>, on that ref in a temporary worktree, then prints both with the
// head/base ratio. Absolute numbers depend on the machine; the ratio between
// two runs on the same machine, back to back, is what to read. Each number is
// the median of XCTest's iterations, so one stalled iteration on a busy
// machine does not move it.
//
//   node scripts/benchmark.mjs                       # this checkout only
//   node scripts/benchmark.mjs --base main           # this checkout vs main
//   node scripts/benchmark.mjs --base HEAD~1 --fail-above 2   # exit 1 when 2x slower
//
// Options:
//   --base <ref>         git ref to compare against (built in a worktree under the temp dir)
//   --udid <simulator>   simulator UDID (default: $IOS_SIMULATOR_UDID, else "booted")
//   --only <test>        one PerformanceBenchmarks test method, e.g. testRenderLongList
//   --fail-above <ratio> exit 1 when any time ratio head/base exceeds it (default: report only)
//   --markdown <file>    also append the report to <file> as Markdown (e.g. $GITHUB_STEP_SUMMARY)

import { execFileSync, spawnSync } from 'node:child_process';
import {
  appendFileSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const packageDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..'
);
const repoDir = path.resolve(packageDir, '..', '..');
const packageRelative = path.relative(repoDir, packageDir);
const benchmarkFile = 'Tests/EnrichedMarkdownTests/PerformanceBenchmarks.swift';
const workDir = path.join(tmpdir(), 'enriched-markdown-ios-benchmark');
// Build products live outside the temp dir, which macOS prunes piecemeal.
const cacheDir = path.join(
  homedir(),
  'Library',
  'Caches',
  'enriched-markdown-ios-benchmark'
);

// Ratios inside this band are machine noise, not a change.
const noiseBand = { faster: 0.8, slower: 1.25 };

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  main(parseArgs(process.argv.slice(2)));
}

function main(options) {
  const udid = options.udid ?? process.env.IOS_SIMULATOR_UDID ?? 'booted';
  mkdirSync(workDir, { recursive: true });
  mkdirSync(cacheDir, { recursive: true });

  const head = runBenchmarks(packageDir, 'head', options, udid);
  const base = options.base
    ? runBenchmarksAt(options.base, options, udid)
    : null;
  const { text, markdown, worst } = report(head, base, options);
  console.log(`\n${text}`);
  if (options.markdown) {
    appendFileSync(options.markdown, `${markdown}\n\n`);
  }
  if (worst?.verdict === 'fail') {
    console.error(
      `\nslowest head/base time ratio ${formatRatio(worst.ratio)} exceeds ${options.failAbove}×`
    );
    process.exit(1);
  }
}

function runBenchmarksAt(ref, options, udid) {
  const commit = git(['rev-parse', '--verify', `${ref}^{commit}`]).trim();
  const worktree = path.join(workDir, `worktree-${commit.slice(0, 12)}`);
  rmSync(worktree, { recursive: true, force: true });
  git(['worktree', 'add', '--detach', worktree, commit]);
  try {
    // The LaTeX target's vendored sources are symlinks materialized by
    // `yarn install`; a fresh worktree needs them restored.
    const vendorScript = path.join(worktree, 'vendor', 'vendor-ratex.mjs');
    if (existsSync(vendorScript)) {
      execFileSync(process.execPath, [vendorScript], {
        cwd: worktree,
        stdio: 'inherit',
      });
    }
    // A base that predates the benchmarks runs the current ones.
    const baseBenchmark = path.join(worktree, packageRelative, benchmarkFile);
    if (!existsSync(baseBenchmark)) {
      copyFileSync(path.join(packageDir, benchmarkFile), baseBenchmark);
    }
    return runBenchmarks(
      path.join(worktree, packageRelative),
      `base-${commit.slice(0, 12)}`,
      options,
      udid
    );
  } finally {
    git(['worktree', 'remove', '--force', worktree]);
  }
}

function runBenchmarks(dir, label, options, udid) {
  const suite = options.only
    ? `EnrichedMarkdownTests/PerformanceBenchmarks/${options.only}`
    : 'EnrichedMarkdownTests/PerformanceBenchmarks';
  const derivedData = path.join(
    cacheDir,
    `derived-${label.startsWith('base') ? 'base' : 'head'}`
  );
  const logFile = path.join(workDir, `${label}.log`);
  console.log(`\n▶ ${label}: ${dir}`);
  console.log(`  log: ${logFile}`);

  // A stale derived-data folder can break the build; one clean retry covers it.
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const result = spawnSync(
      'xcodebuild',
      [
        'test',
        '-scheme',
        'EnrichedMarkdown-Package',
        '-destination',
        `platform=iOS Simulator,id=${udid}`,
        `-only-testing:${suite}`,
        '-derivedDataPath',
        derivedData,
      ],
      {
        cwd: dir,
        env: { ...process.env, TEST_RUNNER_ENRICHED_MARKDOWN_BENCHMARKS: '1' },
        encoding: 'utf8',
        maxBuffer: 256 * 1024 * 1024,
      }
    );
    const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
    writeFileSync(logFile, output);

    const measurements = parseMeasurements(output);
    if (result.status === 0 && measurements.size > 0) {
      console.log(`  ${measurements.size} measurements`);
      return measurements;
    }
    const tail = output
      .split('\n')
      .filter((line) => /error:|failed|\*\* TEST/.test(line))
      .slice(-15);
    console.error(
      `  xcodebuild exited with ${result.status} and reported ${measurements.size} measurements`
    );
    console.error(tail.map((line) => `  ${line}`).join('\n'));
    if (attempt === 0) {
      console.error(`  retrying with a clean ${derivedData}`);
      rmSync(derivedData, { recursive: true, force: true });
    }
  }
  process.exit(2);
}

// "Test Case '-[...PerformanceBenchmarks testX]' measured [Clock Monotonic Time, s]
//  average: 0.024, relative standard deviation: 9.184%, values: [0.021, 0.022, ...], ..."
export function parseMeasurements(output) {
  const pattern =
    /PerformanceBenchmarks (\w+)\]' measured \[([^,\]]+), ([^\]]+)\] average: ([\d.]+), relative standard deviation: ([\d.]+)%(?:, values: \[([^\]]*)\])?/g;
  const measurements = new Map();
  for (const match of output.matchAll(pattern)) {
    const [, test, metric, unit, average, deviation, values] = match;
    const kind = metricKind(metric);
    if (!kind) continue;
    const samples = (values ?? '')
      .split(',')
      .map((value) => Number(value))
      .filter((value) => Number.isFinite(value));
    measurements.set(`${test}|${kind}`, {
      test,
      kind,
      unit,
      value: samples.length > 0 ? median(samples) : Number(average),
      deviation: Number(deviation),
    });
  }
  return measurements;
}

function metricKind(metric) {
  if (metric === 'Time' || metric === 'Clock Monotonic Time') return 'time';
  if (metric === 'Memory Peak Physical') return 'peak memory';
  return null; // "Memory Physical" is the per-iteration delta, which is noise here.
}

function median(samples) {
  const sorted = [...samples].sort((left, right) => left - right);
  const middle = sorted.length >> 1;
  return sorted.length % 2 === 1
    ? sorted[middle]
    : (sorted[middle - 1] + sorted[middle]) / 2;
}

// The plain-text and Markdown reports; `worst` is the time row with the
// highest ratio, when there is a base to compare against.
export function report(head, base, options) {
  const rows = [];
  let worst = null;
  for (const [key, measurement] of head) {
    const other = base?.get(key);
    const ratio = other ? measurement.value / other.value : null;
    const verdict = ratio ? verdictFor(ratio, options) : null;
    if (
      measurement.kind === 'time' &&
      ratio &&
      (!worst || ratio > worst.ratio)
    ) {
      worst = { test: measurement.test, ratio, verdict };
    }
    rows.push({
      name: `${measurement.test} (${measurement.kind})`,
      base: other ? format(other) : '',
      head: format(measurement),
      ratio,
      verdict,
    });
  }

  const header = base
    ? ['benchmark', 'base', 'head', 'head/base']
    : ['benchmark', 'head'];
  const cells = (row, ratioCell) =>
    base
      ? [row.name, row.base, row.head, ratioCell(row)]
      : [row.name, row.head];

  const text = [
    base ? paint(summarize(worst, options), worst?.verdict) : null,
    table([
      header,
      ...rows.map((row) =>
        cells(row, (each) =>
          each.ratio ? paint(formatRatio(each.ratio), each.verdict) : ''
        )
      ),
    ]),
  ]
    .filter(Boolean)
    .join('\n\n');

  const baseName = /^[0-9a-f]{12,}$/.test(options.base ?? '')
    ? options.base.slice(0, 12)
    : options.base;
  const legend = [
    `${marker('faster')} faster than ${noiseBand.faster}×`,
    `${marker('same')} within noise`,
    `${marker('slower')} slower than ${noiseBand.slower}×`,
    options.failAbove
      ? `${marker('fail')} over the ${options.failAbove}× failure threshold`
      : null,
  ]
    .filter(Boolean)
    .join(' · ');
  const markdown = [
    base
      ? `### iOS benchmarks: head vs base ${baseName}`
      : '### iOS benchmarks',
    base ? `${marker(worst?.verdict)} ${summarize(worst, options)}` : null,
    [
      header,
      header.map(() => '---'),
      ...rows.map((row) => cells(row, markRatio)),
    ]
      .map((row) => `| ${row.join(' | ')} |`)
      .join('\n'),
    base ? legend : null,
  ]
    .filter(Boolean)
    .join('\n\n');

  return { text, markdown, worst };
}

function verdictFor(ratio, options) {
  if (options.failAbove && ratio > options.failAbove) return 'fail';
  if (ratio >= noiseBand.slower) return 'slower';
  if (ratio <= noiseBand.faster) return 'faster';
  return 'same';
}

function summarize(worst, options) {
  if (!worst) return 'No time measurements to compare.';
  const ratio = formatRatio(worst.ratio);
  switch (worst.verdict) {
    case 'fail':
      return `${worst.test} is ${ratio} slower than the base, over the ${options.failAbove}× failure threshold.`;
    case 'slower':
      return `${worst.test} is ${ratio} slower than the base.`;
    default:
      return `No benchmark slower than the base beyond noise (slowest ratio ${ratio}).`;
  }
}

function marker(verdict) {
  return { fail: '🔴', slower: '🟠', faster: '🟢', same: '⚪' }[verdict] ?? '';
}

function markRatio(row) {
  return row.ratio ? `${marker(row.verdict)} ${formatRatio(row.ratio)}` : '';
}

function formatRatio(ratio) {
  return `${ratio.toFixed(2)}×`;
}

// ANSI color on a TTY (NO_COLOR respected), plain text elsewhere.
function paint(text, verdict) {
  const code = { fail: 31, slower: 33, faster: 32 }[verdict];
  if (!code || !process.stdout.isTTY || process.env.NO_COLOR) return text;
  return `\u001b[${code}m${text}\u001b[0m`;
}

function format({ kind, value, unit, deviation }) {
  const formatted =
    kind === 'time'
      ? `${(value * 1000).toFixed(1)} ms`
      : `${(unit === 'kB' ? value / 1024 : value).toFixed(0)} MB`;
  return `${formatted} ±${deviation.toFixed(0)}%`;
}

function table(rows) {
  const width = (cell) => cell.replace(/\u001b\[\d+m/g, '').length;
  const widths = rows[0].map((_, column) =>
    Math.max(...rows.map((row) => width(row[column])))
  );
  return rows
    .map((row) =>
      row
        .map((cell, column) => cell + ' '.repeat(widths[column] - width(cell)))
        .join('  ')
        .trimEnd()
    )
    .join('\n');
}

function parseArgs(argv) {
  const parsed = {};
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    const value = argv[index + 1];
    switch (flag) {
      case '--base':
        parsed.base = value;
        index += 1;
        break;
      case '--udid':
        parsed.udid = value;
        index += 1;
        break;
      case '--only':
        parsed.only = value;
        index += 1;
        break;
      case '--fail-above':
        parsed.failAbove = Number(value);
        index += 1;
        break;
      case '--markdown':
        parsed.markdown = value;
        index += 1;
        break;
      default:
        console.error(`unknown option ${flag}`);
        process.exit(2);
    }
  }
  return parsed;
}

function git(args) {
  return execFileSync('git', args, { cwd: repoDir, encoding: 'utf8' });
}
