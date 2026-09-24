# Native text link recognition

`EnrichedMarkdownText` accepts optional `linkRegex` and `inlineCodeLinkRegex` props on iOS and Android, in both CommonMark and GitHub flavors. Both default to disabled. See the [API reference](../../../docs/API_REFERENCE.md#linkregex-and-inlinecodelinkregex) for matching rules and an example.

Recognition uses the same regex normalization as `EnrichedMarkdownTextInput.linkRegex`. The renderer maps the input API's default or rejected-pattern fallback to disabled recognition. It never supplies a built-in detection pattern.

The native parser adds ordinary Link nodes before rendering, segmentation and measurement. Generated links retain their original text or Code child. Full-document and partial-selection Copy as Markdown omit the generated link syntax, while keeping source formatting. Measurement cache keys include both regex configurations.

## Focused native checks

With a JDK and Kotlin compiler installed, run the recognition helper tests without an Android SDK:

```sh
bash scripts/test-text-link-recognizer.sh
```

Set `JAVA_HOME` and `KOTLIN_HOME` if those tools are not on `PATH`. On Linux, `JAVA_HOME` plus a C/C++ compiler also enable the production MD4C/JNI parser and copy-extraction tests:

```sh
bash scripts/test-text-link-recognizer.sh --native
```

The partial-copy tests use small Android text/span stand-ins. They exercise the production extractor, but do not test Android drawing, fonts, accessibility or gestures.

The iOS parity and partial-copy cases are in `__tests__/native/ENRMTextLinkRecognizerTests.mm`. Add that file to an iOS host XCTest target linked against ReactNativeEnrichedMarkdown. The standalone JVM runner does not run these tests. Native example-app and Maestro checks remain necessary for device behavior.
