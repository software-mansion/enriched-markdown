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
and exits successfully. What the native build does when an asset is missing depends on whether you
**explicitly enabled** the feature in your app `package.json`:

- **On by default** (no `enriched-markdown` entry for it): the build treats the feature as disabled —
  code highlighting compiles a no-op stub, iOS math is skipped with a CocoaPods warning — so the build
  stays green.
- **Explicitly enabled** (`"enableMath": true` / `"enableCodeHighlight": true`): the build **fails with
  an actionable error** telling you to re-run postinstall, because you asked for a feature whose assets
  are not present.

To fix a missing download, re-run the recovery command below.

## Re-running or recovering

If a download didn't complete (offline, behind a firewall, or with scripts disabled), reinstall the
package to re-fetch the assets:

```sh
npm rebuild react-native-enriched-markdown
```

If your package manager blocks or skips that (pnpm, Yarn PnP, `--ignore-scripts`), run the vendor script
directly from your project root as a fallback:

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

## Skipping the download (opt out)

If you don't use a feature, opt out in **your app's `package.json`** so the postinstall never
downloads its assets. Add an `enriched-markdown` block (both fields default to `true`):

```json
{
  "enriched-markdown": {
    "enableCodeHighlight": false,
    "enableMath": false
  }
}
```

`enableCodeHighlight: false` skips the tree-sitter runtime + grammar download (iOS and Android);
`enableMath: false` skips the RaTeX download (iOS; Android math uses a Maven dependency and is
unaffected). The native build reads the same `enriched-markdown` block directly (iOS podspec /
Android `build.gradle`), so a `package.json` opt-out **also disables the feature at build time** — no
Podfile or `gradle.properties` edit needed. Disabling takes effect on the next `pod install` / native
rebuild; re-enabling also needs a reinstall so the assets download again.

> [!IMPORTANT]
> **Applying a change on iOS.** The podspec reads `package.json` at `pod install` time, not at build
> time, so a plain rebuild (`run-ios` / Xcode build) reuses the previously resolved pod — you must run
> `pod install` after editing the `enriched-markdown` block. And when you **change a feature that was
> already compiled in** (disabling it, or narrowing `codeHighlightLanguages`), also do a **clean build**
> (`Product > Clean Build Folder`, or delete the app's DerivedData): Xcode's incremental build does not
> reliably rebuild the pod's static library when only its source list changes, so it can otherwise link a
> stale copy that still contains the old code. Android reconfigures on every build and needs neither step.

**Which `package.json`?** The *download* opt-out is read from wherever the install runs (via `INIT_CWD`)
— in a monorepo that is the workspace root, and there is one shared `node_modules`, so the download
opt-out is global. The *build* flag is read from the **app's** `package.json` (the one beside `ios/` /
`android/`), so each app in a monorepo enables or disables features independently. Neither has any
effect inside this repo's own monorepo development.

## Disabling the features at build time

You can also disable a feature purely at build time (assets stay downloaded but are never
compiled/linked):

- Code highlighting: see [Choosing languages / reducing binary size](./CODE_HIGHLIGHT.md#choosing-languages--reducing-binary-size).
- LaTeX math: see [Disabling LaTeX Math](./LATEX_MATH.md#disabling-latex-math-reducing-bundle-size).
