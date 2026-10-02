#!/usr/bin/env node
// Runs the display benchmark on this checkout and, with --base <ref>, on that
// ref in a worktree, then prints the median times and their head/base ratio.
// Read the ratio; absolute numbers depend on the device.
//
// Each document is measured head and base back to back, alternating which goes
// first, so device drift does not show up as a difference.
//
//   node display-benchmark/tools/compare.mjs                   # this checkout only
//   node display-benchmark/tools/compare.mjs --base main       # this checkout vs main
//   node display-benchmark/tools/compare.mjs --head <sha> --base main   # two commits
//   node display-benchmark/tools/compare.mjs --report <dir>    # report on a saved --output
//
// Options:
//   --base <ref>          git ref to compare against (built in a worktree under the temp dir)
//   --head <ref>          git ref to measure instead of this checkout (also built in a worktree)
//   --serial <serial>     adb serial of the device (default: $ANDROID_SERIAL, else the only device)
//   --documents <list>    comma-separated subset of the fixtures, e.g. complex_large
//   --markdown <file>     also append the report to <file> as Markdown (e.g. $GITHUB_STEP_SUMMARY)
//   --output <dir>        copy each side's results JSON and screenshots into <dir>/<side>
//   --report <dir>        measure nothing; report on results saved with --output (read as data)

import { execFileSync, spawnSync } from 'node:child_process';
import {
  appendFileSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const packageDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..'
);
const repoDir = path.resolve(packageDir, '..', '..');
const packageRelative = path.relative(repoDir, packageDir);
const moduleName = 'display-benchmark';
const outputRelative = path.join(
  moduleName,
  'build',
  'outputs',
  'connected_android_test_additional_output'
);
const workDir = path.join(tmpdir(), 'enriched-markdown-android-benchmark');

// Row order in the report; anything else goes last.
const documentOrder = [
  'simple_small',
  'simple_medium',
  'simple_large',
  'complex_small',
  'complex_medium',
  'complex_large',
];
const benchmarkOrder = ['full', 'render', 'layout', 'draw'];
const resultsSuffix = '-benchmarkData.json';

// Ratios inside this band are noise, not a change.
const noiseBand = { faster: 0.8, slower: 1.25 };

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    const options = parseArgs(process.argv.slice(2));
    if (options.report) {
      reportSaved(options);
    } else {
      main(options);
    }
  } catch (error) {
    console.error(`\n${error.message}`);
    process.exitCode = 2;
  }
}

function main(options) {
  const device = connectDevice(options.serial);
  mkdirSync(workDir, { recursive: true });
  // Ctrl+C also stops the child process; staying alive lets the finally below
  // remove the worktrees.
  process.on('SIGINT', () => {});

  const sides = [];
  try {
    sides.push(
      options.head
        ? addWorktree('head', options.head)
        : { label: 'head', dir: packageDir }
    );
    if (options.base) sides.push(addWorktree('base', options.base));

    // Build both sides first, so no build runs during the measurements.
    for (const side of sides) {
      gradle(side, 'assembleReleaseAndroidTest', device);
    }
    for (const side of sides) side.results = new Map();
    if (sides.length === 1) {
      merge(sides[0].results, measure(sides[0], device, options));
    } else {
      documentList(options).forEach((document, index) => {
        const order = index % 2 === 0 ? sides : [...sides].reverse();
        for (const side of order) {
          merge(side.results, measure(side, device, options, document));
        }
      });
    }

    const [head, base] = sides.map((side) => side.results);
    write(report(head, base), options);
  } finally {
    for (const side of sides) {
      if (side.worktree) removeWorktree(side.worktree);
    }
  }
}

// Reports on the results a run saved with --output, without a device.
function reportSaved(options) {
  const read = (label) => {
    const dir = path.join(options.report, label);
    if (!existsSync(dir)) return null;
    const results = new Map();
    for (const entry of readdirSync(dir).sort()) {
      if (!entry.endsWith(resultsSuffix)) continue;
      merge(
        results,
        parseResults(JSON.parse(readFileSync(path.join(dir, entry), 'utf8')))
      );
    }
    if (results.size === 0) {
      throw new Error(`${label}: no benchmark results under ${dir}`);
    }
    return results;
  };
  const head = read('head');
  if (!head) throw new Error(`no head results under ${options.report}`);
  write(report(head, read('base')), options);
}

function write({ text, markdown }, options) {
  console.log(`\n${text}`);
  if (options.markdown) {
    mkdirSync(path.dirname(options.markdown), { recursive: true });
    appendFileSync(options.markdown, `${markdown}\n`);
  }
}

// Documents to measure one by one: the requested ones, or every fixture.
function documentList(options) {
  if (!options.documents) return documentOrder;
  const documents = options.documents
    .split(',')
    .map((document) => document.trim())
    .filter(Boolean);
  if (documents.length === 0) throw new Error('--documents lists no document');
  return documents;
}

function merge(into, results) {
  for (const [key, measurement] of results) {
    if (into.has(key)) {
      throw new Error(
        `${measurement.benchmark}[${measurement.document}] measured twice`
      );
    }
    into.set(key, measurement);
  }
}

function connectDevice(requested) {
  let serial = requested ?? process.env.ANDROID_SERIAL;
  if (!serial) {
    const devices = adb(null, ['devices'])
      .split('\n')
      .slice(1)
      .map((line) => line.split('\t'))
      .filter(([, state]) => state?.trim() === 'device')
      .map(([id]) => id);
    if (devices.length !== 1) {
      throw new Error(
        `Expected one connected device, found ${devices.length}; pass --serial or set ANDROID_SERIAL`
      );
    }
    serial = devices[0];
  }
  const property = (name) => adb(serial, ['shell', 'getprop', name]).trim();
  const emulator =
    property('ro.kernel.qemu') === '1' || property('ro.boot.qemu') === '1';
  const device = {
    serial,
    abi: property('ro.product.cpu.abi'),
    model: property('ro.product.model'),
    sdk: property('ro.build.version.sdk'),
    emulator,
  };
  console.log(
    `device: ${device.model} (${serial}), API ${device.sdk}, ${device.abi}${emulator ? ', emulator' : ''}`
  );
  if (emulator) {
    console.warn(
      'Running on an emulator: the numbers only show the direction of a change; confirm it on a physical device.'
    );
  }
  return device;
}

function addWorktree(label, ref) {
  const commit = git(['rev-parse', '--verify', `${ref}^{commit}`]).trim();
  const worktree = path.join(workDir, `${label}-${commit.slice(0, 12)}`);
  // --force re-adds a worktree an interrupted run left registered.
  rmSync(worktree, { recursive: true, force: true });
  git(['worktree', 'add', '--force', '--detach', worktree, commit]);
  try {
    const dir = path.join(worktree, packageRelative);
    if (!existsSync(path.join(dir, moduleName))) {
      throw new Error(
        `${ref} (${commit.slice(0, 12)}) has no ${moduleName} module to run`
      );
    }
    // Reuse this checkout's SDK location, if any.
    const localProperties = path.join(packageDir, 'local.properties');
    if (existsSync(localProperties)) {
      copyFileSync(localProperties, path.join(dir, 'local.properties'));
    }
    return { label, commit, worktree, dir };
  } catch (error) {
    removeWorktree(worktree);
    throw error;
  }
}

// Warns instead of throwing, so a failed removal neither hides the run's error
// nor skips the other worktrees.
function removeWorktree(worktree) {
  try {
    git(['worktree', 'remove', '--force', worktree]);
  } catch (error) {
    console.warn(`Could not remove the worktree ${worktree}: ${error.message}`);
  }
}

// Runs the benchmark on one side, for `document` alone when given.
function measure(side, device, options, document) {
  const outputDir = path.join(side.dir, outputRelative);
  // Drop an earlier run's results.
  rmSync(outputDir, { recursive: true, force: true });

  const argumentsPrefix = '-Pandroid.testInstrumentationRunnerArguments.';
  const instrumentationArguments = [
    // Skip the profiling pass; it only produces traces.
    `${argumentsPrefix}androidx.benchmark.profiling.mode=none`,
  ];
  if (device.emulator) {
    instrumentationArguments.push(
      `${argumentsPrefix}androidx.benchmark.suppressErrors=EMULATOR`
    );
  }
  const documents = document ?? options.documents;
  if (documents) {
    instrumentationArguments.push(
      `${argumentsPrefix}mdbench.documents=${documents}`
    );
  }
  gradle(side, 'connectedReleaseAndroidTest', device, instrumentationArguments);

  const resultsFile = findFile(outputDir, (name) =>
    name.endsWith(resultsSuffix)
  );
  if (!resultsFile) {
    throw new Error(`${side.label}: no benchmark results under ${outputDir}`);
  }
  const results = parseResults(JSON.parse(readFileSync(resultsFile, 'utf8')));
  if (results.size === 0) {
    throw new Error(`${side.label}: ${resultsFile} has no measurements`);
  }
  if (options.output) {
    // One results file per document; screenshots are already named that way.
    const destination = path.join(options.output, side.label);
    mkdirSync(destination, { recursive: true });
    for (const entry of readdirSync(path.dirname(resultsFile))) {
      const source = path.join(path.dirname(resultsFile), entry);
      if (entry.endsWith(resultsSuffix)) {
        copyFileSync(
          source,
          path.join(destination, `${document ?? 'all'}${resultsSuffix}`)
        );
      } else if (entry.endsWith('.png')) {
        copyFileSync(source, path.join(destination, entry));
      }
    }
  }
  console.log(`  ${results.size} measurements`);
  return results;
}

function gradle(side, task, device, extraArguments = []) {
  console.log(`\n▶ ${side.label} ${task}: ${side.dir}`);
  const result = spawnSync(
    './gradlew',
    [
      `:${moduleName}:${task}`,
      '--no-daemon',
      '--console=plain',
      // Builds the native parser for the device's ABI alone.
      `-Pandroid.injected.build.abi=${device.abi}`,
      ...extraArguments,
    ],
    {
      cwd: side.dir,
      env: { ...process.env, ANDROID_SERIAL: device.serial },
      stdio: 'inherit',
    }
  );
  if (result.status !== 0) {
    const outcome = result.signal
      ? `was stopped by ${result.signal}`
      : `exited with ${result.status}`;
    throw new Error(`${side.label}: ${task} ${outcome}`);
  }
}

// Entries are named like "full[complex_large]", maybe prefixed by suppressed
// errors ("EMULATOR_..."). Anything else throws rather than silently missing
// from the report; only matching names and finite numbers are kept.
export function parseResults(json) {
  const results = new Map();
  for (const entry of json?.benchmarks ?? []) {
    const name = String(entry?.name);
    const match = /^(?:[A-Z][A-Z0-9-]*_)*(\w+)\[(\w+)\]$/.exec(name);
    const time = entry?.metrics?.timeNs;
    if (!match || !isFinitePositive(time?.median)) {
      throw new Error(`unrecognized benchmark result ${JSON.stringify(name)}`);
    }
    const [, benchmark, document] = match;
    const key = `${document}|${benchmark}`;
    if (results.has(key)) {
      throw new Error(`${benchmark}[${document}] measured twice`);
    }
    results.set(key, {
      document,
      benchmark,
      time: time.median,
      deviation: finiteOrUndefined(time.coefficientOfVariation),
      allocations: finiteOrUndefined(entry.metrics.allocationCount?.median),
    });
  }
  return results;
}

function isFinitePositive(value) {
  return typeof value === 'number' && Number.isFinite(value) && value > 0;
}

function finiteOrUndefined(value) {
  return typeof value === 'number' && Number.isFinite(value)
    ? value
    : undefined;
}

// Text and Markdown reports; a row measured on one side only has no ratio.
export function report(head, base) {
  const keys = new Set([...head.keys(), ...(base?.keys() ?? [])]);
  const rows = [...keys]
    .map((key) => ({ head: head.get(key), base: base?.get(key) }))
    .map(({ head: after, base: before }) => {
      const { document, benchmark } = after ?? before;
      const ratio = after && before ? after.time / before.time : null;
      return {
        document,
        benchmark,
        base: before ? formatTime(before) : '',
        head: after ? formatTime(after) : '',
        ratio,
        verdict: ratio ? verdictFor(ratio) : null,
        allocations: formatAllocations(before, after),
      };
    })
    .sort(byReportOrder);

  const header = base
    ? ['document', 'benchmark', 'base', 'head', 'head/base', 'allocations']
    : ['document', 'benchmark', 'head', 'allocations'];
  const cells = (row, ratioCell, document) =>
    base
      ? [
          document,
          row.benchmark,
          row.base,
          row.head,
          ratioCell(row),
          row.allocations,
        ]
      : [document, row.benchmark, row.head, row.allocations];
  // The Markdown table names each document once, on its first row.
  const firstOfDocument = (row, index) =>
    index === 0 || rows[index - 1].document !== row.document;

  const text = [
    base ? summarize(rows) : null,
    table([
      header,
      ...rows.map((row) =>
        cells(
          row,
          (each) => (each.ratio ? formatRatio(each.ratio) : ''),
          row.document
        )
      ),
    ]),
  ]
    .filter(Boolean)
    .join('\n\n');

  const legend = [
    `${marker('faster')} faster than ${noiseBand.faster}×`,
    `${marker('same')} within noise`,
    `${marker('slower')} slower than ${noiseBand.slower}×`,
    `${marker('missing')} measured on one side only`,
  ].join(' · ');
  const markdown = [
    base ? summarize(rows) : null,
    [
      header,
      header.map(() => '---'),
      ...rows.map((row, index) =>
        cells(
          row,
          markRatio,
          firstOfDocument(row, index) ? `\`${row.document}\`` : ''
        )
      ),
    ]
      .map((row) => `| ${row.join(' | ')} |`)
      .join('\n'),
    base
      ? `${legend}. Times are medians with their coefficient of variation; allocations are per iteration.`
      : null,
  ]
    .filter(Boolean)
    .join('\n\n');

  return { text, markdown };
}

function byReportOrder(left, right) {
  const rank = (order, value) => {
    const index = order.indexOf(value);
    return index === -1 ? order.length : index;
  };
  return (
    rank(documentOrder, left.document) - rank(documentOrder, right.document) ||
    rank(benchmarkOrder, left.benchmark) - rank(benchmarkOrder, right.benchmark)
  );
}

function verdictFor(ratio) {
  if (ratio >= noiseBand.slower) return 'slower';
  if (ratio <= noiseBand.faster) return 'faster';
  return 'same';
}

function summarize(rows) {
  const count = (verdict) =>
    rows.filter((row) => row.verdict === verdict).length;
  const slower = count('slower');
  const faster = count('faster');
  const missing = count(null);
  if (slower === 0 && faster === 0 && missing === 0) {
    return `${marker('same')} No benchmark differs from the base beyond noise.`;
  }
  return [
    slower ? `${marker('slower')} ${slower} slower` : null,
    faster ? `${marker('faster')} ${faster} faster` : null,
    `${marker('same')} ${count('same')} within noise`,
    missing
      ? `${marker('missing')} ${missing} measured on one side only`
      : null,
  ]
    .filter(Boolean)
    .join(' · ');
}

function marker(verdict) {
  return (
    { slower: '🟠', faster: '🟢', same: '⚪', missing: '⚠️' }[verdict] ?? ''
  );
}

function markRatio(row) {
  return row.ratio
    ? `${marker(row.verdict)} ${formatRatio(row.ratio)}`
    : marker('missing');
}

function formatRatio(ratio) {
  return `${ratio.toFixed(2)}×`;
}

function formatTime({ time, deviation }) {
  const formatted =
    time >= 1e6
      ? `${(time / 1e6).toFixed(2)} ms`
      : time >= 1e3
        ? `${(time / 1e3).toFixed(1)} µs`
        : `${time.toFixed(0)} ns`;
  return deviation === undefined
    ? formatted
    : `${formatted} ±${(deviation * 100).toFixed(0)}%`;
}

// Allocation counts vary about 1% between runs, so larger changes are shown.
function formatAllocations(base, head) {
  const count = (measurement) =>
    measurement?.allocations === undefined
      ? null
      : Math.round(measurement.allocations);
  const before = count(base);
  const after = count(head);
  if (after === null) return '';
  if (
    before === null ||
    Math.abs(after - before) <= Math.max(1, before * 0.02)
  ) {
    return `${after}`;
  }
  return `${before} → ${after}`;
}

function table(rows) {
  const widths = rows[0].map((_, column) =>
    Math.max(...rows.map((row) => row[column].length))
  );
  return rows
    .map((row) =>
      row
        .map((cell, column) => cell.padEnd(widths[column]))
        .join('  ')
        .trimEnd()
    )
    .join('\n');
}

function findFile(dir, predicate) {
  if (!existsSync(dir)) return null;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const entryPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const found = findFile(entryPath, predicate);
      if (found) return found;
    } else if (predicate(entry.name)) {
      return entryPath;
    }
  }
  return null;
}

function parseArgs(argv) {
  const parsed = {};
  const flags = {
    '--base': 'base',
    '--head': 'head',
    '--serial': 'serial',
    '--documents': 'documents',
    '--markdown': 'markdown',
    '--output': 'output',
    '--report': 'report',
  };
  for (let index = 0; index < argv.length; index += 2) {
    const key = flags[argv[index]];
    if (!key) throw new Error(`unknown option ${argv[index]}`);
    if (argv[index + 1] === undefined)
      throw new Error(`${argv[index]} needs a value`);
    parsed[key] = argv[index + 1];
  }
  return parsed;
}

function git(args) {
  return execFileSync('git', args, { cwd: repoDir, encoding: 'utf8' });
}

function adb(serial, args) {
  return execFileSync('adb', serial ? ['-s', serial, ...args] : args, {
    encoding: 'utf8',
  });
}
