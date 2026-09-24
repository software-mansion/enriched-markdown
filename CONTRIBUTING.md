# Contributing

Contributions are always welcome, no matter how large or small!

We want this community to be friendly and respectful to each other. Please follow it in all your interactions with the project. Before contributing, please read the [code of conduct](./CODE_OF_CONDUCT.md).

## Development workflow

This project is a monorepo managed using [Yarn workspaces](https://yarnpkg.com/features/workspaces), with every workspace under `packages/*` or `apps/*`.

The libraries:

- [`packages/react-native-enriched-markdown/`](./packages/react-native-enriched-markdown/) — the React Native library published to npm: the JS API, its iOS and Android native code, and the web build.
- [`packages/core/`](./packages/core/) — the shared C++ core: the md4c parser and the Markdown AST. Every other package compiles these same sources, so there is exactly one parser in the repository.
- [`packages/enriched-markdown-ios/`](./packages/enriched-markdown-ios/) — the standalone iOS package: a SwiftPM package wrapping the core in a Swift API, plus an optional LaTeX target.
- [`packages/enriched-markdown-android/`](./packages/enriched-markdown-android/) — the standalone Android package: Gradle modules for the span-based `ui` renderer and its `compose` wrapper, over a `parser` module that is a JNI binding to the core.

The example apps, each driven by a script from the root directory:

- [`apps/react-native-example/`](./apps/react-native-example/) — `yarn react-native-example <start|ios|android>`. The main development app; Storybook and the Maestro E2E suite live here.
- [`apps/react-native-macos-example/`](./apps/react-native-macos-example/) — `yarn react-native-macos-example <start|macos>`.
- [`apps/react-native-web-example/`](./apps/react-native-web-example/) — `yarn react-native-web-example web`. The web build running in a browser (Expo).
- [`apps/ios-example/`](./apps/ios-example/) — `yarn ios-example`. A native Swift app using the iOS package directly.
- [`apps/android-example/`](./apps/android-example/) — `yarn android-example`. A native Android app using the Android package directly.

The documentation site lives in [`docs/`](./docs/). It is a standalone Docusaurus project with its own `yarn.lock`, not part of the workspace: run `yarn && yarn start` inside it, and make sure `yarn build` passes before merging documentation changes.

To get started with the project, make sure you have the correct version of [Node.js](https://nodejs.org/) installed. See the [`.nvmrc`](./.nvmrc) file for the version used in this project.

### Cloning the Repository

```sh
git clone https://github.com/software-mansion/enriched-markdown.git
cd enriched-markdown
```

## Initial Setup

```sh
# Install dependencies
yarn

# Build the library (required before running any app)
yarn prepare
```

> Since the project relies on Yarn workspaces, you cannot use [`npm`](https://github.com/npm/cli) for development without manually migrating.

The [react-native-example app](./apps/react-native-example/) demonstrates usage of the library. You need to run it to test any changes you make.

It is configured to use the local version of the library, so any changes you make to the library's source code will be reflected in the example app. Changes to the library's JavaScript code will be reflected in the example app without a rebuild, but native code changes will require a rebuild of the example app.

If you want to use Android Studio or Xcode to edit the native code, you can open the `apps/react-native-example/android` or `apps/react-native-example/ios` directories respectively in those editors. To edit the Objective-C or Swift files, open `apps/react-native-example/ios/EnrichedMarkdownExample.xcworkspace` in Xcode and find the source files at `Pods > Development Pods > react-native-enriched-markdown`.

To edit the Java or Kotlin files, open `apps/react-native-example/android` in Android studio and find the source files at `react-native-enriched-markdown` under `Android`.

You can use various commands from the root directory to work with the project.

To start the packager:

```sh
yarn react-native-example start
```

To run the example app on Android:

```sh
yarn react-native-example android
```

To run the example app on iOS:

```sh
yarn react-native-example ios
```

The library is Fabric-only, and the example app enables the New Architecture explicitly (`newArchEnabled=true` in `apps/react-native-example/android/gradle.properties`, `RCT_NEW_ARCH_ENABLED=1` in its `Podfile`), so there is nothing to switch on first.

Make sure your code passes TypeScript and ESLint. Run the following to verify:

```sh
yarn typecheck
yarn lint
```

To fix formatting errors, run the following:

```sh
yarn lint --fix
```

Remember to add Maestro E2E tests for your change when behavior is user-visible. To run the E2E tests with [Maestro](https://maestro.mobile.dev/), use:

```sh
yarn test:e2e:ios
yarn test:e2e:android
yarn test:e2e:mobile   # both platforms sequentially
yarn test:e2e:ios-native      # native iOS example app (CommonMark only)
yarn test:e2e:android-native  # native Android example app (CommonMark only)
```

The test script names follow the pattern `test:e2e[:<config>]:<platform>[:update-screenshots]`:

- **`<platform>`** — `ios`, `android`, or `mobile` (both sequentially).
- **`<config>`** — optional tag filter. Omitting it runs all tests. Named configs:
  - `smoke` — quick sanity check covering all basic elements.
  - `advanced` — extended tests for advanced functionality.
- **`update-screenshots`** — instead of asserting, refreshes the stored screenshot baselines. Not available for config-filtered runs.

Examples:

```sh
yarn test:e2e:smoke:ios          # smoke tests on iOS only
yarn test:e2e:smoke:mobile       # smoke tests on both platforms
yarn test:e2e:advanced:android   # advanced tests on Android only
```

If your change affects visual output, update the screenshot baselines:

```sh
yarn test:e2e:ios:update-screenshots
yarn test:e2e:android:update-screenshots
```

> Maestro must be installed and a simulator/emulator must be available. Pass `-- --rebuild` to force a fresh build of the example app.

### Storybook

Storybook is embedded in the react-native-example app (`apps/react-native-example/`) as a dedicated screen. To use it, run the example app normally and navigate to the **Storybook** screen from the home screen.

Stories live in `apps/react-native-example/.rnstorybook/stories/`.

### Commit message convention

We follow the [conventional commits specification](https://www.conventionalcommits.org/en) for our commit messages:

- `fix`: bug fixes, e.g. fix crash due to deprecated method.
- `feat`: new features, e.g. add new method to the module.
- `refactor`: code refactor, e.g. migrate from class components to hooks.
- `docs`: changes into documentation, e.g. add usage example for the module.
- `test`: adding or updating tests, e.g. add integration tests using detox.
- `chore`: tooling changes, e.g. change CI config.

Our pre-commit hooks verify that your commit message matches this format when committing.

### Linting and type checking

[ESLint](https://eslint.org/), [Prettier](https://prettier.io/), [TypeScript](https://www.typescriptlang.org/)

We use [TypeScript](https://www.typescriptlang.org/) for type checking and [ESLint](https://eslint.org/) with [Prettier](https://prettier.io/) for linting and formatting the code. User-facing behavior is covered by Maestro E2E tests; a smaller [Jest](https://jestjs.io/) suite (`yarn test`) backs them up for JS-level regressions.

Our pre-commit hooks verify that lint and typecheck pass when committing.

### Publishing to npm

We use [release-it](https://github.com/release-it/release-it) to make it easier to publish new versions. It handles common tasks like bumping version based on semver, creating tags and releases etc.

To publish new versions, run the following:

```sh
yarn release
```

### Scripts

The `package.json` file contains various scripts for common tasks:

- `yarn`: setup project by installing dependencies.
- `yarn prepare`: build the library (required before running any app).
- `yarn typecheck`: type-check files with TypeScript.
- `yarn lint`: lint files with ESLint.
- `yarn test`: run the Jest unit tests of the React Native package.
- `yarn build:wasm`: rebuild the md4c WebAssembly parser used by the web build.
- `yarn react-native-example start`: start the Metro server for the react-native-example app.
- `yarn react-native-example android`: run the react-native-example app on Android.
- `yarn react-native-example ios`: run the react-native-example app on iOS.
- `yarn test:e2e:ios`: run all E2E tests on iOS simulator.
- `yarn test:e2e:android`: run all E2E tests on Android emulator.
- `yarn test:e2e:mobile`: run all E2E tests on both platforms sequentially.
- `yarn test:e2e:smoke:ios`: run smoke tests on iOS simulator.
- `yarn test:e2e:smoke:android`: run smoke tests on Android emulator.
- `yarn test:e2e:smoke:mobile`: run smoke tests on both platforms sequentially.
- `yarn test:e2e:advanced:ios`: run advanced tests on iOS simulator.
- `yarn test:e2e:advanced:android`: run advanced tests on Android emulator.
- `yarn test:e2e:advanced:mobile`: run advanced tests on both platforms sequentially.
- `yarn test:e2e:ios:update-screenshots`: refresh iOS screenshot baselines.
- `yarn test:e2e:android:update-screenshots`: refresh Android screenshot baselines.
- `yarn test:e2e:mobile:update-screenshots`: refresh screenshot baselines for both platforms.
- `yarn test:e2e:ios-native`: run CommonMark E2E tests on the native iOS example app.
- `yarn test:e2e:ios-native:smoke`: smoke CommonMark tests on the native iOS example app.
- `yarn test:e2e:ios-native:update-screenshots`: refresh native iOS example screenshot baselines.
- `yarn test:e2e:android-native`: run CommonMark E2E tests on the native Android example app.
- `yarn test:e2e:android-native:smoke`: smoke CommonMark tests on the native Android example app.
- `yarn test:e2e:android-native:update-screenshots`: refresh native Android example screenshot baselines.

### Sending a pull request

> **Working on your first pull request?** You can learn how from this _free_ series: [How to Contribute to an Open Source Project on GitHub](https://app.egghead.io/playlists/how-to-contribute-to-an-open-source-project-on-github).

When you're sending a pull request:

- Prefer small pull requests focused on one change.
- Verify that lint and typecheck are passing.
- Review the documentation to make sure it looks good.
- Follow the pull request template when opening a pull request.
- For pull requests that change the API or implementation, discuss with maintainers first by opening an issue.
