#!/usr/bin/env node
// Replayable device check for the block renderers, run by the
// .argent/flows/qa-renderers-streaming.yaml flow after the Renderers screen
// finished streaming. It reads the accessibility tree through argent and fails
// when a text frame intersects a replaced block, when no replaced block is on
// screen, or when partial media syntax is visible.
//
// The flow runner does not hand scripts its device, so the script checks every
// booted simulator and emulator and skips any whose screen is not the Renderers
// screen. Pass a udid or serial as the first argument to check one device.
import { execFileSync } from 'node:child_process';

function argent(args) {
  return JSON.parse(
    execFileSync('argent', ['run', ...args, '--json'], { encoding: 'utf8' })
  );
}

function bootedDevices() {
  const list = argent(['list-devices']);
  const devices = Array.isArray(list) ? list : (list.devices ?? []);
  return devices
    .filter(
      (d) =>
        /^(booted|device|running)$/i.test(String(d.state ?? '')) &&
        d.kind !== 'device'
    )
    .map((d) => d.udid ?? d.serial ?? d.id)
    .filter(Boolean);
}

function checkTree(description) {
  const rows = [];
  for (const line of description.split('\n')) {
    const m = line.match(/\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)\s*$/);
    if (!m) continue;
    const [x, y, w, h] = m.slice(1).map(Number);
    rows.push({ line: line.trim(), x, y, w, h });
  }
  const slots = rows.filter((r) => /id="renderer-(image|video)-/.test(r.line));
  const texts = rows.filter(
    (r) =>
      !/id="renderer-/.test(r.line) &&
      /(StaticText|AXGroup "|View ")/.test(r.line) &&
      r.w > 0.3
  );
  const problems = [];
  if (slots.length === 0) problems.push('no replaced block is on screen');
  for (const slot of slots) {
    for (const text of texts) {
      // A text frame fully inside the slot is the React child's own content
      // (a caption, a badge); only a partial intersection is a layout fault.
      const inside =
        text.y >= slot.y - 0.002 &&
        text.y + text.h <= slot.y + slot.h + 0.002 &&
        text.x >= slot.x - 0.002 &&
        text.x + text.w <= slot.x + slot.w + 0.002;
      const top = Math.max(slot.y, text.y);
      const bottom = Math.min(slot.y + slot.h, text.y + text.h);
      if (!inside && bottom - top > 0.012) {
        const id = slot.line.match(/id="([^"]+)"/)[1];
        problems.push(`text overlaps ${id}: ${text.line.slice(0, 80)}`);
      }
    }
  }
  for (const r of rows) {
    if (
      /!\[|\]\(https?:\/\/|<video/.test(r.line) &&
      !/just code/.test(r.line)
    ) {
      problems.push(`partial media syntax on screen: ${r.line.slice(0, 80)}`);
    }
  }
  return problems;
}

const udids = process.argv[2] ? [process.argv[2]] : bootedDevices();
if (udids.length === 0) {
  console.error('check-block-slots: no booted device');
  process.exit(2);
}

let checked = 0;
const failures = [];
for (const udid of udids) {
  const description = argent(['describe', '--udid', udid]).description ?? '';
  if (!/id="renderers-screen"/.test(description)) continue;
  checked++;
  const problems = checkTree(description);
  if (problems.length > 0)
    failures.push(`${udid}:\n  ${problems.join('\n  ')}`);
}
if (checked === 0) {
  console.error(
    'check-block-slots: no booted device shows the Renderers screen'
  );
  process.exit(2);
}
if (failures.length > 0) {
  console.error(failures.join('\n'));
  process.exit(1);
}
console.log(
  `block slots ok on ${checked} device(s): no overlap, no partial syntax`
);
