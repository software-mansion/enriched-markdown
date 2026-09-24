#!/usr/bin/env node
// Runs the package's opt-in PerformanceBenchmarks on this checkout and, with
// --base <ref>, on that ref in a temporary worktree, then prints both with the
// head/base ratio. Absolute numbers depend on the machine; the ratio between
// two runs on the same machine, back to back, is what to read.
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
//   --markdown <file>    also append the table to <file> as Markdown (e.g. $GITHUB_STEP_SUMMARY)

import { execFileSync, spawnSync } from 'node:child_process';
import {
  appendFileSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
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

const options = parseArgs(process.argv.slice(2));
const udid = options.udid ?? process.env.IOS_SIMULATOR_UDID ?? 'booted';

mkdirSync(workDir, { recursive: true });

const head = runBenchmarks(packageDir, 'head');
let base = null;
if (options.base) {
  base = runBenchmarksAt(options.base);
}
report(head, base);

function runBenchmarksAt(ref) {
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
      `base-${commit.slice(0, 12)}`
    );
  } finally {
    git(['worktree', 'remove', '--force', worktree]);
  }
}

function runBenchmarks(dir, label) {
  const suite = options.only
    ? `EnrichedMarkdownTests/PerformanceBenchmarks/${options.only}`
    : 'EnrichedMarkdownTests/PerformanceBenchmarks';
  const derivedData = path.join(
    workDir,
    `derived-${label.startsWith('base') ? 'base' : 'head'}`
  );
  const logFile = path.join(workDir, `${label}.log`);
  console.log(`\n▶ ${label}: ${dir}`);
  console.log(`  log: ${logFile}`);

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
  if (result.status !== 0 || measurements.size === 0) {
    const tail = output
      .split('\n')
      .filter((line) => /error:|failed|\*\* TEST/.test(line))
      .slice(-15);
    console.error(
      `  xcodebuild exited with ${result.status} and reported ${measurements.size} measurements`
    );
    console.error(tail.map((line) => `  ${line}`).join('\n'));
    process.exit(2);
  }
  console.log(`  ${measurements.size} measurements`);
  return measurements;
}

// "Test Case '-[...PerformanceBenchmarks testX]' measured [Clock Monotonic Time, s] average: 0.024, ..."
function parseMeasurements(output) {
  const pattern =
    /PerformanceBenchmarks (\w+)\]' measured \[([^,\]]+), ([^\]]+)\] average: ([\d.]+), relative standard deviation: ([\d.]+)%/g;
  const measurements = new Map();
  for (const match of output.matchAll(pattern)) {
    const [, test, metric, unit, average, deviation] = match;
    const kind = metricKind(metric);
    if (!kind) continue;
    measurements.set(`${test}|${kind}`, {
      test,
      kind,
      unit,
      average: Number(average),
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

function report(head, base) {
  const rows = [];
  let slowest = 0;
  for (const [key, measurement] of head) {
    const other = base?.get(key);
    const ratio = other ? measurement.average / other.average : null;
    if (measurement.kind === 'time' && ratio)
      slowest = Math.max(slowest, ratio);
    const row = [
      `${measurement.test} (${measurement.kind})`,
      format(measurement),
    ];
    if (base)
      row.push(other ? format(other) : '', ratio ? `${ratio.toFixed(2)}×` : '');
    rows.push(row);
  }
  const header = base
    ? ['benchmark', 'head', 'base', 'head/base']
    : ['benchmark', 'head'];
  printTable([header, ...rows]);
  if (options.markdown) {
    const title = base
      ? `### iOS benchmarks: head vs base ${options.base}`
      : '### iOS benchmarks';
    const table = [header, header.map(() => '---'), ...rows].map(
      (row) => `| ${row.join(' | ')} |`
    );
    appendFileSync(options.markdown, `${title}\n\n${table.join('\n')}\n\n`);
  }

  if (base && options.failAbove && slowest > options.failAbove) {
    console.error(
      `\nslowest head/base time ratio ${slowest.toFixed(2)}× exceeds ${options.failAbove}×`
    );
    process.exit(1);
  }
}

function format({ kind, average, unit, deviation }) {
  const value =
    kind === 'time'
      ? `${(average * 1000).toFixed(1)} ms`
      : `${(unit === 'kB' ? average / 1024 : average).toFixed(0)} MB`;
  return `${value} ±${deviation.toFixed(0)}%`;
}

function printTable(rows) {
  const widths = rows[0].map((_, column) =>
    Math.max(...rows.map((row) => row[column].length))
  );
  console.log('');
  for (const row of rows) {
    console.log(
      row
        .map((cell, column) => cell.padEnd(widths[column]))
        .join('  ')
        .trimEnd()
    );
  }
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
