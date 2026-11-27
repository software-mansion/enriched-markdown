# Maintainer scripts

Repo-level tooling, mostly for releases. Not needed for regular contribution work — see [CONTRIBUTING.md](../CONTRIBUTING.md) for that.

## generate-changelog.mjs

Prints GitHub-release-style markdown for all commits since a tag, with PR links, author handles, and a New Contributors section. Commits are grouped by conventional-commit prefix: `feat` → New Features, `fix`/`perf` → Fixes & Improvements, `refactor` → Refactors, `test` → Tests, `docs`/`chore`/`build`/`ci` → Docs & Chores, and anything else → Other Changes.

```sh
./scripts/generate-changelog.mjs v0.7.0 | pbcopy          # everything since v0.7.0
./scripts/generate-changelog.mjs v0.6.0 v0.7.0            # explicit range
```

Author handles and the New Contributors section are resolved through an authenticated [GitHub CLI](https://cli.github.com/); without it the script falls back to plain commit author names.

## prepare-npm-publish.sh

`prepack`/`postpack` hooks for the library package: swaps the `cpp` symlink for a real copy of `packages/core/cpp` while packing. Run automatically by npm, not by hand.

## fetch-md4c.sh

Syncs `packages/core/cpp/enrmrkd` from our MD4C fork [software-mansion-labs/md4c](https://github.com/software-mansion-labs/md4c), whose parser carries an `ENRMRKD_`/`enrmrkd_` prefix so it cannot clash with another embedded MD4C copy. Run via `yarn workspace react-native-enriched-markdown sync-md4c`.

## test-core-parser.sh

Host-compiled checks for `packages/core/cpp`, run in CI by the `core-parser` job whenever that directory (or this script, or `fetch-md4c.sh`) changes. It builds the vendored parser and `MD4CParser` with the system toolchain and then:

- asserts the vendored parser exports nothing but `enrmrkd_*`, so it cannot collide with another embedded MD4C copy ([#846](https://github.com/software-mansion/enriched-markdown/issues/846));
- compares the serialized AST of `packages/core/cpp/tests/fixtures/*.md`, under five flag variants, against the golden dump in `packages/core/cpp/tests/golden/ast.txt`;
- links the parser beside upstream `mity/md4c` (pinned tag) in one binary and runs both.

```sh
./scripts/test-core-parser.sh            # verify
./scripts/test-core-parser.sh --update   # re-record the golden dump after an intended change
```

The last check downloads upstream MD4C, and a failed download fails the run - a required check that passes when the network is down guards nothing. Offline, and only outside CI, `ENRM_SKIP_COEXISTENCE_CHECK=1` skips that one step.

A `sync-md4c` that changes parsing shows up here as a golden diff to review, rather than reaching a release unnoticed.

The `core-parser` job also runs `yarn lint-clang:core-parser`, the only thing that checks `packages/core/cpp` formatting: the `clang-format` pre-commit hook is local and skippable.

## test-web-bundle.mjs

Loads the committed `packages/react-native-enriched-markdown/src/web/wasm/md4c.js` and compares the AST it produces for the same fixtures against the same golden dump, for the two flag variants the WASM entry point can reach.

```sh
node scripts/test-web-bundle.mjs
```

That bundle is a build artifact, and nothing rebuilds it on install, `prepare` or `prepack` - a change under `packages/core/cpp` reaches native at once and web only when someone runs `yarn build:wasm`. It had fallen a feature behind before this check existed, so web silently parsed documents differently from native. If it fails, rebuild the bundle and commit it.
