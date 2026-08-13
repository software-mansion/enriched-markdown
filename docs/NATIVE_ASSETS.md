# Native assets (install-time download)

Two pieces of the library's native layer are large prebuilt/vendored assets: the
tree-sitter runtime and grammar sources used for [code-block highlighting](./CODE_HIGHLIGHT.md)
(~170 MB of C source across every supported grammar) and the RaTeX static XCFramework used for
[iOS LaTeX math](./LATEX_MATH.md) (~47 MB). Shipping them inside the npm tarball would make every
install download ~230 MB even for apps that use neither feature.

Instead they are **downloaded once at install time** by a `postinstall` script, keeping the
published package small (~1 MB packed / ~7.5 MB unpacked). The download is verified by sha256 and is
idempotent — a `.stamp` fingerprint in each vendor directory makes repeated installs a no-op.

## What gets downloaded, and from where

| Asset | Source | Used by |
|---|---|---|
| tree-sitter runtime | GitHub release tarball (`github.com/tree-sitter/tree-sitter`) | code highlighting (iOS + Android) |
| grammar sources (`parser.c`/`scanner.c`/`highlights.scm`) | npm registry (`registry.npmjs.org`) | code highlighting (iOS + Android) |
| RaTeX XCFramework + fonts | GitHub release (`github.com/erweixin/RaTeX`) | LaTeX math (iOS only) |

The pins live in `grammar-versions.json` and `ratex-version.json` inside the installed package. The
pre-built highlight registry for the default language set **is** shipped in the tarball, so the only
thing fetched for a default build is the grammar C source it compiles.

Files land under `node_modules/react-native-enriched-markdown/` in
`cpp/highlight/vendor/` (grammars + runtime) and `ios/vendor/` (RaTeX). Because this runs during
`npm install` / `yarn add`, the assets are in place before `pod install` or the Android build reads
them.

## Requirements

- **Network access at install time** to `registry.npmjs.org` and `github.com`.
- `tar` (present on macOS, Linux, and Windows 10+). RaTeX also needs `unzip`; it is absent on stock
  Windows, but RaTeX is iOS-only so this only affects Windows dev machines and is non-fatal.

The postinstall step **never fails the install**: if a download does not complete it prints a warning
and exits successfully. The missing assets only surface later, as a clear error when the native build
runs (the iOS podspec, for example, raises an actionable message if `ios/vendor/RaTeX.xcframework` is
absent while math is enabled).

## Re-running or recovering

If installs happened offline, behind a firewall, or with scripts disabled, restore the assets by
re-running the script from your project root:

```sh
node node_modules/react-native-enriched-markdown/postinstall.mjs
```

Then re-run `pod install` (iOS) or rebuild (Android).

## Package-manager notes

- **npm / Yarn Classic / Yarn Berry (node-modules linker)**: works out of the box.
- **pnpm**: recent pnpm blocks dependency lifecycle scripts by default. Allow this package to run its
  `postinstall` so the assets download — for example:

  ```yaml
  # pnpm-workspace.yaml (or package.json "pnpm" field)
  onlyBuiltDependencies:
    - react-native-enriched-markdown
  ```

  Without this the native build fails until you run the recovery command above.
- **Yarn PnP** is not supported for this package — PnP stores dependencies as read-only archives, so
  the postinstall cannot write the vendored assets into the package. Use the `node-modules` linker
  (`nodeLinker: node-modules`), which is the norm for React Native projects anyway.
- **`--ignore-scripts`**: the assets will not download. Run the recovery command above afterward.

## Disabling the features

If you don't use a feature you can turn it off so its assets are never compiled/linked (a failed or
skipped download then never matters):

- Code highlighting: see [Choosing languages / reducing binary size](./CODE_HIGHLIGHT.md#choosing-languages--reducing-binary-size).
- LaTeX math: see [Disabling LaTeX Math](./LATEX_MATH.md#disabling-latex-math-reducing-bundle-size).
