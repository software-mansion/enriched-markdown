---
sidebar_label: Contributing
sidebar_position: 5
---

# Contributing

`react-native-enriched-markdown` is an **open source** library being developed at
[software-mansion/enriched-markdown](https://github.com/software-mansion/enriched-markdown), under the [MIT license](https://github.com/software-mansion/enriched-markdown/blob/main/LICENSE).

Contributions are always welcome, no matter how large or small - a bug report, a missing line in these docs, or a fix in the native layer. If something in the library surprised you, the fix might belongs upstream, and this page is the short version of how to land it.

We want this community to be friendly and respectful to each other, so before contributing please read the [code of conduct](https://github.com/software-mansion/enriched-markdown/blob/main/CODE_OF_CONDUCT.md) and follow it in all your interactions with the project.

:::tip
Not sure where to start? Open an [issue](https://github.com/software-mansion/enriched-markdown/issues) describing what you need. For changes to the public API or the native implementation, discuss the design with the maintainers there **before** writing the code - it saves a rewrite.
:::

## Ways to contribute

- **Report a bug.** Include the platform, the library version, and the Markdown that reproduces it. See [Compatibility](/misc/compatibility) to check your version pairing first.
- **Request a feature.** Tell us which element or prop is missing and what you are building - the native packages trail the React Native one, so demand decides what gets implemented next.
- **Improve the docs.** Every page has an *Edit this page* link at the bottom that takes you straight to the file on GitHub.
- **Send a pull request.** Bug fixes, new features, platform parity work, and examples are all fair game.

## Project layout

The project is a monorepo managed with [Yarn workspaces](https://yarnpkg.com/features/workspaces), holding the library packages for every platform, an example app per platform, and this documentation site.

### Packages

| Path | What it is |
|---|---|
| `packages/react-native-enriched-markdown/` | The React Native library published to npm - the JS API, its iOS and Android bridging code, and the web build. |
| `packages/core/` | The shared C++ core: the [md4c](https://github.com/mity/md4c) parser and the Markdown AST. Every other package compiles these same sources - there is exactly one parser in the repository. |
| `packages/enriched-markdown-ios/` | The standalone iOS package - a SwiftPM package wrapping the core in a Swift API, plus an optional LaTeX target. |
| `packages/enriched-markdown-android/` | The standalone Android package - Gradle modules for the span-based `ui` renderer and its `compose` wrapper, over a `parser` module that is a JNI binding to the core. |

The two native packages are standalone libraries for native iOS and Android apps. They render with their own platform text stack but parse through the same core as the React Native package, so a parser fix lands for every platform at once. They trail React Native in features, so parity work is always welcome.

### Example apps

Each app lives in `apps/` and is driven from the repository root:

| Path | Root command | What it covers |
|---|---|---|
| `apps/react-native-example/` | `yarn react-native-example <start\|ios\|android>` | The main development app - Storybook and the Maestro E2E suite live here. |
| `apps/react-native-macos-example/` | `yarn react-native-macos-example <start\|macos>` | The [react-native-macos](/react-native/guides/macos) build. |
| `apps/react-native-web-example/` | `yarn react-native-web-example web` | The [web build](/react-native/guides/web-support) running in a browser (Expo). |
| `apps/ios-example/` | `yarn ios-example` | A native Swift app using the iOS package directly. |
| `apps/android-example/` | `yarn android-example` | A native Android app using the Android package directly. |

### Documentation

| Path | What it is |
|---|---|
| `docs/` | This site - a standalone Docusaurus project; see [Working on the docs](#working-on-the-docs). |

## Setting up

Make sure you have the Node.js version from the repository's [`.nvmrc`](https://github.com/software-mansion/enriched-markdown/blob/main/.nvmrc), then:

```sh
git clone https://github.com/software-mansion/enriched-markdown.git
cd enriched-markdown

# Install dependencies
yarn

# Build the library - required before running any app
yarn prepare
```

:::caution
The project relies on Yarn workspaces, so you cannot use `npm` for development without manually migrating.
:::

## Running the examples

Every package has its own example app, and each one builds against the local sources - so your change shows up without publishing anything. Run `yarn prepare` in the repository root first; the React Native build and the iOS package's vendored LaTeX assets both come from it.

### React Native

[`apps/react-native-example/`](https://github.com/software-mansion/enriched-markdown/tree/main/apps/react-native-example) uses the local library, so it is where you test changes to `packages/react-native-enriched-markdown/`. JavaScript changes are picked up by Metro; native changes require rebuilding the app.

```sh
yarn react-native-example start     # start the packager
yarn react-native-example ios       # run on iOS
yarn react-native-example android   # run on Android
```

The library is Fabric-only, and the example app turns the New Architecture on explicitly (`newArchEnabled=true` on Android, `RCT_NEW_ARCH_ENABLED=1` in the Podfile), so there is nothing to switch on before you start.

To work on the package's native layer in a native IDE:

- **iOS** - open `apps/react-native-example/ios/EnrichedMarkdownExample.xcworkspace` in Xcode; the Objective-C and Swift sources are under *Pods > Development Pods > react-native-enriched-markdown*.
- **Android** - open `apps/react-native-example/android` in Android Studio; the Java and Kotlin sources are under *react-native-enriched-markdown* in the *Android* view.

The same package also powers two more apps: `yarn react-native-macos-example macos` for the [macOS build](/react-native/guides/macos) and `yarn react-native-web-example web` for the [web build](/react-native/guides/web-support).

#### Storybook

Storybook is embedded in the React Native example app as a dedicated screen - run the app and open **Storybook** from the home screen. Stories live in `apps/react-native-example/.rnstorybook/stories/`.

### iOS package

`apps/ios-example/` is a plain Swift app that references `packages/enriched-markdown-ios/` as a local Swift package, so edits to the package land in the app on the next build - nothing to link or re-resolve.

```sh
yarn ios-example   # build, boot a simulator, install, and launch
```

To work in Xcode, open `apps/ios-example/EnrichedMarkdownExample/EnrichedMarkdownExample.xcodeproj`. If you are only changing the package, open `packages/enriched-markdown-ios/Package.swift` instead.

Tests and lint run from the package itself, against a booted simulator (or set `IOS_SIMULATOR_UDID`):

```sh
yarn workspace @enriched-markdown/ios test:ios-native   # xcodebuild test
yarn workspace @enriched-markdown/ios lint:ios-native   # swiftlint --strict
```

:::note
The optional `EnrichedMarkdownLaTeX` target reaches the RaTeX engine's Swift sources and the KaTeX fonts through symlinks into the React Native package's `ios/vendor/`, which is gitignored and restored on demand. `yarn` / `yarn prepare` restore it; `node vendor/vendor-ratex.mjs` does it directly. CI runs that script before every iOS job - build, tests, and lint - so do the same before building the package with a fresh checkout. (The RaTeX binary itself is a `binaryTarget` SwiftPM downloads from its pinned release, not a vendored file.)
:::

### Android package

`apps/android-example/` is a plain Android app whose `settings.gradle` includes the package's `ui`, `compose`, and `parser` modules straight from `packages/enriched-markdown-android/`, so the app always builds the sources in your working tree.

```sh
yarn android-example   # install the debug build and launch it on a device or emulator
```

Open `apps/android-example/` in Android Studio to work on the app and the library modules side by side.

Tests and lint run from the package itself:

```sh
yarn workspace @enriched-markdown/android test:android-native   # ./gradlew testDebugUnitTest
yarn workspace @enriched-markdown/android lint:android-native   # ./gradlew ktlintCheck
```

## Checks before you push

[Lefthook](https://github.com/evilmartians/lefthook) covers part of this for you on every commit: `commitlint` on the message, ESLint and `yarn typecheck` on staged JS and TS, `clang-format` on staged C, C++ and Objective-C and ktlint formatting on staged Kotlin. The last two **rewrite and re-stage** your files rather than just complaining. Nothing else is automatic - the standalone packages' Swift and Kotlin checks and every test suite are yours to run, and CI runs them again.

Run the checks for whatever you touched.

### React Native and shared code

```sh
yarn lint             # ESLint + Prettier
yarn lint --fix       # fix formatting errors
yarn typecheck        # tsc
yarn test             # Jest unit tests
yarn lint-clang       # clang-format check on the package's iOS and Android native sources
yarn lint-clang:fix
yarn lint-kotlin      # ktlint on the package's Android sources
yarn lint-kotlin:fix
```

`yarn lint-clang` checks the React Native package's `ios/` and `android/` directories. The shared C++ in `packages/core/` is not covered by it, so keep that formatting tidy by hand.

### Swift (iOS package)

Both need Xcode and a booted simulator (or `IOS_SIMULATOR_UDID`), and the vendored RaTeX files restored - see [the note above](#ios-package).

```sh
yarn workspace @enriched-markdown/ios lint:ios-native   # swiftlint --strict
yarn workspace @enriched-markdown/ios test:ios-native   # xcodebuild test
```

### Kotlin (Android package)

```sh
yarn workspace @enriched-markdown/android lint:android-native   # ./gradlew ktlintCheck
yarn workspace @enriched-markdown/android test:android-native   # ./gradlew testDebugUnitTest
```

Note that the commit hook's ktlint pass only covers the React Native package, so run this one yourself when you touch `packages/enriched-markdown-android/`.

### End-to-end tests

User-visible behavior is covered by [Maestro](https://maestro.mobile.dev/) E2E tests - **add tests for your change when it is user-visible**. A simulator or emulator must be available; the runner boots one for you.

:::note
The runner requires the **Maestro CLI 2.5.0 or newer** and stops with an error on anything older.
:::

```sh
yarn test:e2e:ios
yarn test:e2e:android
yarn test:e2e:mobile             # both platforms sequentially
```

Script names follow the pattern `test:e2e[:<config>]:<platform>[:update-screenshots]`:

- **`<platform>`** - `ios`, `android`, or `mobile` (both sequentially).
- **`<config>`** - optional tag filter; omitting it runs all tests. Named configs are `smoke` (quick sanity check with basic examples) and `advanced` (extended tests with combinations of different elements, advanced configuration options, etc.).
- **`update-screenshots`** - instead of asserting, refreshes the stored screenshot baselines.

```sh
yarn test:e2e:smoke:ios          # smoke tests on iOS only
yarn test:e2e:advanced:android   # advanced tests on Android only
```

If your change affects visual output, refresh the baselines:

```sh
yarn test:e2e:ios:update-screenshots
yarn test:e2e:android:update-screenshots
```

:::tip
Pass `--rebuild` to force a fresh build of the example app.
:::

### Docs site

`yarn build` and `yarn check-examples` inside `docs/` - see [Working on the docs](#working-on-the-docs).

### What CI will run

Two sets of checks guard a pull request, and they are independent: the platform checks for the library code, and the docs checks for this site. A docs-only change runs no platform checks; a code-only change runs no docs checks.

#### Which platform checks fire

CI first works out which platforms your diff touches, and every check runs only for a platform that was touched. The matching is wider than it looks, because shared files count as **all three** platforms:

| Platform | Touched by changes to |
|---|---|
| React Native | `packages/react-native-enriched-markdown/**`, `apps/react-native-example/**` |
| Android | `packages/enriched-markdown-android/**`, `apps/android-example/**` |
| iOS | `packages/enriched-markdown-ios/**`, `apps/ios-example/**` |
| **all three** | `packages/core/**`, `package.json`, `yarn.lock`, `.nvmrc`, `.yarnrc.yml`, `.github/**` |

So a one-line change in the shared C++ core has to pass every platform's checks, while a change confined to one package only runs that package's.

#### What each check does

| Platform | Check | What it runs |
|---|---|---|
| React Native | `rn-lint` | `yarn lint`, `yarn typecheck`, `yarn test` |
| React Native | `rn-build-library` | `yarn prepare` |
| React Native | `rn-build-android` | Builds the React Native example app for Android. |
| React Native | `rn-build-ios` | Builds the React Native example app for iOS. |
| Android | `android-build` | Builds `apps/android-example/` against the package's Gradle modules. |
| Android | `android-unit-tests` | `./gradlew testDebugUnitTest` |
| Android | `android-kotlin-lint` | `./gradlew ktlintCheck` |
| iOS | `ios-build` | Builds `apps/ios-example/` against the local Swift package. |
| iOS | `ios-unit-tests` | `xcodebuild test` against a simulator. |
| iOS | `ios-swift-lint` | `swiftlint lint --strict` |

A final `ci-success` check is the one merging depends on: it fails if any check required for your platforms did not succeed, and passes immediately when your change touched none of them.

#### Docs

A pull request that touches `docs/**` gets two more checks, in parallel: one verifies that the interactive examples still mirror the pages that own them (`yarn check-examples`), the other builds the site (`yarn build`).

#### What CI does not run

Some checks exist only on your machine - if you skip them, nothing downstream will catch the problem:

- **The Maestro E2E tests.** Nothing runs them, on any platform. Screenshot baselines and flows are verified locally or not at all, so run the suites yourself when your change is user-visible.
- **`yarn lint-clang`.** clang-format runs only over staged files in the pre-commit hook. The shared C++ in `packages/core/` is covered by neither it nor CI.
- **`yarn lint-kotlin`.** The Kotlin lint check covers only `packages/enriched-markdown-android/`; the React Native package's Kotlin is left to the commit hook.
- **The macOS and web example apps.** Neither is built by any check.

## Working on the docs

This site is a standalone [Docusaurus](https://docusaurus.io/) project inside `docs/`, with its own `yarn.lock`:

```sh
cd docs
yarn
yarn start            # dev server
yarn build            # must pass - broken links and anchors fail the build
yarn check-examples   # verifies interactive examples match the pages that own them
```

Interactive examples run the library's **web build**, so run `yarn prepare` in the repository root first - otherwise the examples cannot resolve `react-native-enriched-markdown`.

## Commit messages

We follow the [conventional commits specification](https://www.conventionalcommits.org/en), and the pre-commit hooks verify the format:

| Prefix | Use for |
|---|---|
| `fix` | Bug fixes, e.g. fix crash due to deprecated method. |
| `feat` | New features, e.g. add new method to the module. |
| `refactor` | Code refactor, e.g. migrate from class components to hooks. |
| `docs` | Documentation changes, e.g. add usage example for the module. |
| `test` | Adding or updating tests. |
| `chore` | Tooling changes, e.g. change CI config. |

## Sending a pull request

Keep a pull request small and focused on a single change - it is far easier to review, and far easier to revert if something turns out wrong. If the change touches the public API or the native implementation, open an issue and agree on the design with the maintainers before you write the code.

Opening a pull request fills the description from our [pull request template](https://github.com/software-mansion/enriched-markdown/blob/main/.github/PULL_REQUEST_TEMPLATE.md), which asks for three things: **what** the change does and **why** it is needed, **how** to test it, and a checklist to confirm before requesting a review. Screenshots are welcome for anything visual - the template has commented-out markup for side-by-side iOS/Android and before/after tables.

The checklist is where most review rounds are saved. It asks you to confirm that the code compiles and runs on **both** iOS and Android, that you ran the example app to see the change, that the documentation is updated if the change is user-facing, and that the E2E tests pass and cover the new behavior. Those last two items matter more than they look: nothing in CI runs the E2E suites for you (see [What CI will run](#what-ci-will-run)), so an unticked box there is the only signal a reviewer gets.

For the full, always-current version of these instructions - including publishing and the complete script list - see [`CONTRIBUTING.md`](https://github.com/software-mansion/enriched-markdown/blob/main/CONTRIBUTING.md) in the repository.
