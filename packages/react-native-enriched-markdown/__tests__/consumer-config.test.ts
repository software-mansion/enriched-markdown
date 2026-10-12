import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const POSTINSTALL = path.join(__dirname, '..', 'postinstall.mjs');
const DEP = { 'react-native-enriched-markdown': '^1.0.0' };

let root: string;

function write(file: string, content: unknown) {
  const target = path.join(root, file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(
    target,
    typeof content === 'string' ? content : JSON.stringify(content)
  );
}

/** Runs the real postinstall in lookup-only mode, as a package manager would. */
function resolve(initCwd: string | undefined): {
  workspaceDirs: string[];
  config: Record<string, boolean>;
} {
  const env = { ...process.env };
  delete env.INIT_CWD;
  if (initCwd) env.INIT_CWD = initCwd;
  const result = spawnSync(
    process.execPath,
    [POSTINSTALL, '--resolve-config'],
    { env, encoding: 'utf8' }
  );
  expect(result.status).toBe(0);
  return JSON.parse(result.stdout);
}

beforeEach(() => {
  root = fs.mkdtempSync(path.join(os.tmpdir(), 'enriched-consumer-'));
});

afterEach(() => {
  fs.rmSync(root, { recursive: true, force: true });
});

describe('postinstall consumer config', () => {
  it('downloads everything without INIT_CWD', () => {
    expect(resolve(undefined).config).toEqual({});
  });

  it('reads the block of the directory the install ran from', () => {
    write('package.json', {
      'dependencies': DEP,
      'enriched-markdown': { enableMath: false },
    });
    expect(resolve(root).config).toEqual({ enableMath: false });
  });

  it('lets a root block win over workspace members', () => {
    write('package.json', {
      'workspaces': ['apps/*'],
      'enriched-markdown': { enableCodeHighlight: false },
    });
    write('apps/mobile/package.json', {
      'dependencies': DEP,
      'enriched-markdown': { enableMath: false },
    });
    expect(resolve(root).config).toEqual({ enableCodeHighlight: false });
  });

  it('falls back to a pnpm workspace member that opts out', () => {
    write('package.json', { name: 'monorepo', private: true });
    write(
      'pnpm-workspace.yaml',
      'packages:\n  - apps/*\n  - "packages/*"\n\ncatalog:\n  react: 19.0.0\n'
    );
    write('apps/mobile/package.json', {
      'dependencies': DEP,
      'enriched-markdown': { enableMath: false },
    });
    write('packages/ui/package.json', { name: 'ui' });
    expect(resolve(root).config).toEqual({ enableMath: false });
  });

  it('keeps a download that any consuming app still needs', () => {
    write('package.json', { workspaces: { packages: ['apps/*'] } });
    write('apps/mobile/package.json', {
      'dependencies': DEP,
      'enriched-markdown': { enableMath: false, enableCodeHighlight: false },
    });
    write('apps/tablet/package.json', {
      'devDependencies': DEP,
      'enriched-markdown': { enableMath: false },
    });
    expect(resolve(root).config).toEqual({ enableMath: false });
  });

  it('ignores members that do not depend on the package', () => {
    write('package.json', { workspaces: ['apps/*'] });
    write('apps/web/package.json', {
      'enriched-markdown': { enableMath: false },
    });
    write('apps/mobile/package.json', { dependencies: DEP });
    expect(resolve(root).config).toEqual({});
  });

  it('downloads everything when no member depends on the package', () => {
    write('package.json', { workspaces: ['apps/*'] });
    write('apps/web/package.json', { name: 'web' });
    expect(resolve(root).config).toEqual({});
  });

  it('survives a malformed package.json', () => {
    write('package.json', '{ not json');
    expect(resolve(root).config).toEqual({});
  });

  it('subtracts negated workspace patterns', () => {
    write('package.json', {
      workspaces: ['apps/*', 'libs/**', '!apps/legacy', 'tools'],
    });
    for (const dir of [
      'apps/mobile',
      'apps/legacy',
      'libs/core',
      'libs/core/native',
      'tools',
      'node_modules/dep',
      'libs/.hidden',
    ]) {
      fs.mkdirSync(path.join(root, dir), { recursive: true });
    }
    const dirs = resolve(root).workspaceDirs.map((d) => path.relative(root, d));
    expect(dirs.sort()).toEqual([
      'apps/mobile',
      'libs',
      'libs/core',
      'libs/core/native',
      'tools',
    ]);
  });

  it('does not let an excluded package veto the opt-out', () => {
    write('package.json', { workspaces: ['apps/*', '!apps/legacy'] });
    write('apps/mobile/package.json', {
      'dependencies': DEP,
      'enriched-markdown': { enableMath: false },
    });
    write('apps/legacy/package.json', { dependencies: DEP });
    expect(resolve(root).config).toEqual({ enableMath: false });
  });

  it('reads pnpm patterns with comments, quotes and flow style', () => {
    write('apps/mobile/package.json', {
      'dependencies': DEP,
      'enriched-markdown': { enableMath: false },
    });
    write('package.json', { name: 'monorepo' });

    write(
      'pnpm-workspace.yaml',
      '# members\npackages:\n  # apps\n  - apps/*  # the mobile apps\n\n  - "!apps/legacy"\n'
    );
    expect(resolve(root).config).toEqual({ enableMath: false });

    write(
      'pnpm-workspace.yaml',
      'packages: [\'apps/*\', "!apps/legacy"] # flow\n'
    );
    expect(resolve(root).config).toEqual({ enableMath: false });
  });

  it('counts peer dependencies as consumers', () => {
    write('package.json', { workspaces: ['packages/*'] });
    write('packages/ui/package.json', {
      'peerDependencies': DEP,
      'enriched-markdown': { enableMath: false },
    });
    expect(resolve(root).config).toEqual({ enableMath: false });
  });

  it('merges every flag the consumers agree on and skips non-boolean keys', () => {
    write('package.json', { workspaces: ['apps/*'] });
    write('apps/mobile/package.json', {
      'dependencies': DEP,
      'enriched-markdown': {
        enableMath: false,
        enableVideo: false,
        codeHighlightLanguages: ['swift'],
      },
    });
    write('apps/tablet/package.json', {
      'dependencies': DEP,
      'enriched-markdown': { enableMath: false, enableVideo: false },
    });
    expect(resolve(root).config).toEqual({
      enableMath: false,
      enableVideo: false,
    });
  });
});
