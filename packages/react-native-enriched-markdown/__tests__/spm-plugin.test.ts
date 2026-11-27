import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const PKG = path.join(__dirname, '..');

type Plugin = (context: unknown) => {
  packageDependencies: { name: string; path: string }[];
  productDependencies: { name: string; package: string }[];
  watchPaths: string[];
};

let root: string;
let lib: string;
let app: string;
let warn: jest.SpyInstance;

function loadPlugin(): Plugin {
  return require(path.join(lib, 'spm-plugin.js'));
}

function context(overrides: Record<string, unknown> = {}) {
  return {
    projectRoot: app,
    outputDir: path.join(app, 'ios/build/generated/autolinking'),
    react: { packageRef: { path: path.join(app, 'ios/build/xcframeworks') } },
    ...overrides,
  };
}

function writeAppPackageJson(content: unknown) {
  fs.writeFileSync(path.join(app, 'package.json'), JSON.stringify(content));
}

function manifest() {
  return fs.readFileSync(path.join(lib, 'Package.swift'), 'utf8');
}

beforeEach(() => {
  root = fs.realpathSync(
    fs.mkdtempSync(path.join(os.tmpdir(), 'enriched-spm-'))
  );
  lib = path.join(root, 'node_modules/react-native-enriched-markdown');
  app = root;
  fs.mkdirSync(lib, { recursive: true });
  for (const file of ['spm-plugin.js', 'Package.swift']) {
    fs.copyFileSync(path.join(PKG, file), path.join(lib, file));
  }
  warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
});

afterEach(() => {
  warn.mockRestore();
  fs.rmSync(root, { recursive: true, force: true });
});

describe('SwiftPM autolinking plugin', () => {
  it('bakes the config and React Native paths and contributes the package', () => {
    writeAppPackageJson({
      'name': 'app',
      'enriched-markdown': {
        enableMath: false,
        codeHighlightLanguages: ['swift'],
      },
    });
    const result = loadPlugin()(context());

    expect(result).toEqual({
      packageDependencies: [{ name: 'ReactNativeEnrichedMarkdown', path: lib }],
      productDependencies: [
        {
          name: 'ReactNativeEnrichedMarkdown',
          package: 'ReactNativeEnrichedMarkdown',
        },
      ],
      watchPaths: [
        path.join(app, 'package.json'),
        path.join(lib, 'ios'),
        path.join(lib, 'cpp/highlight/vendor'),
        path.join(lib, 'cpp/highlight/vendor/grammars/.stamp'),
      ],
    });
    const text = manifest();
    expect(text).toContain(
      'let bakedConfigJSON: String? = #"{"codeHighlightLanguages":["swift"],"enableMath":false}"#'
    );
    expect(text).toContain(
      `let reactNativePackagePath = #"${path.join(app, 'ios/build/xcframeworks')}"#`
    );
    expect(text).toContain(
      `let generatedCodePackagePath = #"${path.join(app, 'ios/build/generated/ios')}"#`
    );
    const original = fs.readFileSync(path.join(PKG, 'Package.swift'), 'utf8');
    const outside = (s: string) =>
      s.replace(/\/\/ BEGIN enriched[\s\S]*\/\/ END enriched/, '');
    expect(outside(text)).toBe(outside(original));
  });

  it('bakes an empty config when package.json is missing or the block is not an object', () => {
    loadPlugin()(context());
    expect(manifest()).toContain('let bakedConfigJSON: String? = #"{}"#');

    writeAppPackageJson({
      'name': 'app',
      'enriched-markdown': ['not', 'an', 'object'],
    });
    loadPlugin()(context());
    expect(manifest()).toContain('let bakedConfigJSON: String? = #"{}"#');
  });

  it('widens the Swift raw string delimiter for values containing "# or \\#', () => {
    writeAppPackageJson({
      'enriched-markdown': { codeHighlightLanguages: ['#swift', '\\##('] },
    });
    loadPlugin()(context());
    expect(manifest()).toContain(
      'let bakedConfigJSON: String? = ###"{"codeHighlightLanguages":["#swift","\\\\##("]}"###'
    );
  });

  it('writes byte-identical content when nothing changed', () => {
    writeAppPackageJson({
      'enriched-markdown': { enableVideo: false, enableMath: true },
    });
    const plugin = loadPlugin();
    plugin(context());
    const first = manifest();
    const file = path.join(lib, 'Package.swift');
    const past = new Date(Math.floor(Date.now() / 1000) * 1000 - 60_000);
    fs.utimesSync(file, past, past);

    writeAppPackageJson({
      'enriched-markdown': { enableMath: true, enableVideo: false },
    });
    plugin(context());
    expect(manifest()).toBe(first);
    expect(fs.statSync(file).mtimeMs).toBe(past.getTime());
  });

  it('changes the manifest when vendored assets arrive', () => {
    const plugin = loadPlugin();
    plugin(context());
    const withoutAssets = manifest();

    fs.mkdirSync(path.join(lib, 'ios/vendor'), { recursive: true });
    fs.writeFileSync(path.join(lib, 'ios/vendor/.stamp'), 'ratex\n');
    plugin(context());
    const withRatex = manifest();
    expect(withRatex).not.toBe(withoutAssets);

    const grammars = path.join(lib, 'cpp/highlight/vendor/grammars');
    fs.mkdirSync(grammars, { recursive: true });
    fs.writeFileSync(path.join(grammars, '.stamp'), 'grammars\n');
    plugin(context());
    expect(manifest()).not.toBe(withRatex);
  });

  it('warns when assets of a feature that is not turned off are missing', () => {
    loadPlugin()(context());
    expect(warn.mock.calls.map(([message]) => message)).toEqual([
      expect.stringContaining('LaTeX math disabled'),
      expect.stringContaining('code highlighting disabled'),
    ]);

    warn.mockClear();
    writeAppPackageJson({
      'enriched-markdown': { enableMath: false, enableCodeHighlight: false },
    });
    loadPlugin()(context());
    expect(warn).not.toHaveBeenCalled();
  });

  it('fails without a local React Native package or the manifest markers', () => {
    expect(() => loadPlugin()(context({ react: { packageRef: {} } }))).toThrow(
      /only a local React Native package/
    );

    fs.writeFileSync(
      path.join(lib, 'Package.swift'),
      '// swift-tools-version: 6.0\n'
    );
    expect(() => loadPlugin()(context())).toThrow(
      /missing its baked-config markers/
    );
  });
});
