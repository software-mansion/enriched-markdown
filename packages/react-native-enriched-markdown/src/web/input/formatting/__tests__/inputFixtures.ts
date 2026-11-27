import fs from 'node:fs';
import path from 'node:path';

// The shared fixtures of the markdown import and export, one set for the C++
// tests (cpp/tests/fixtures/input) and for these suites, which run the same
// documents through the WASM build of the core.
const DIRECTORY = path.resolve(
  __dirname,
  '../../../../../../core/cpp/tests/fixtures/input'
);

function cases(file: string): unknown[] {
  const json = JSON.parse(fs.readFileSync(path.join(DIRECTORY, file), 'utf8'));
  return json.cases;
}

// Documents already in the serializer's form: the round trip reproduces each
// byte for byte.
export const canonical = (): string[] => cases('canonical.json') as string[];

// [markdown, expected]: one round trip normalizes the first into the second.
export const normalization = (): Array<[string, string]> =>
  cases('normalization.json') as Array<[string, string]>;

// [markdown, expected]: syntax the input has no model for loses its markers and
// keeps its content.
export const unsupported = (): Array<[string, string]> =>
  cases('unsupported.json') as Array<[string, string]>;

// Text typed by a user that carries no markup of its own.
export const plainText = (): string[] => cases('plain-text.json') as string[];

export interface ChainCase {
  kind: 'chain';
  description: string;
  markdown: string;
  trips: string[];
}

export interface ModelCase {
  kind: 'model';
  description: string;
  text: string;
  ranges: Array<[type: string, start: number, end: number, url?: string]>;
  blocks: Array<[type: string, start: number, end: number, level: number]>;
  markdown: string;
  parsedText: string;
  parsedLinks?: string[];
  parsedBlocks?: number;
}

// Behavior of the reference that looks wrong and is pinned on purpose.
export const knownLimitations = (): Array<ChainCase | ModelCase> =>
  cases('known-limitations.json') as Array<ChainCase | ModelCase>;
