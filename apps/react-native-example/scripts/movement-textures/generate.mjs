// Bakes the instrument textures for the Movement screen.
// Usage: node scripts/movement-textures/generate.mjs
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, '../../src/screens/movement/assets');
const chrome =
  process.env.CHROME ??
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const dom = execFileSync(
  chrome,
  [
    '--headless=new',
    '--disable-gpu',
    '--allow-file-access-from-files',
    '--virtual-time-budget=600000',
    '--dump-dom',
    pathToFileURL(join(here, 'bake.html')).href,
  ],
  { maxBuffer: 512 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'] }
).toString();

const match = dom.match(/<pre id="out">([^<]*)<\/pre>/);
if (!match) throw new Error('bake.html produced no output');
const layers = JSON.parse(match[1].replace(/&quot;/g, '"').replace(/&amp;/g, '&'));
if (layers.error) throw new Error(layers.error);

mkdirSync(out, { recursive: true });
let total = 0;
for (const [name, url] of Object.entries(layers)) {
  const bytes = Buffer.from(url.split(',')[1], 'base64');
  writeFileSync(join(out, `${name}.webp`), bytes);
  total += bytes.length;
  console.log(`${name}.webp ${(bytes.length / 1024).toFixed(0)} KB`);
}
console.log(`total ${(total / 1024 / 1024).toFixed(2)} MB`);
