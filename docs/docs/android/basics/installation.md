---
sidebar_label: Installation
sidebar_position: 1
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Installation

`enriched-markdown-android` is a **standalone Android library** - a Jetpack Compose component that renders Markdown as native text. It is published directly to Maven Central, so you add it to an Android app the way you add any other Gradle dependency.

## Requirements

| | |
| --- | --- |
| **Min SDK** | `24` (Android 7.0) |
| **Compile SDK** | `36` or newer |
| **Java** | 11 or newer (the library's bytecode target) |
| **Kotlin** | 2.3 or newer, with the Compose compiler plugin (`org.jetbrains.kotlin.plugin.compose`). The library is built with Kotlin 2.4.0, and a Kotlin compiler can read metadata at most one minor version ahead of itself. |
| **UI toolkit** | Jetpack Compose |
| **AndroidX** | Required (`android.useAndroidX=true`) |

The library is compiled against SDK `36`. Keep your app's `compileSdk` at least that high: compiling against an older SDK than a dependency was built with is unsupported and can fail on classes and APIs your SDK doesn't have.

The `compose` artifact depends on Compose UI and Material 3 through the Compose BOM `2026.06.00`. Gradle resolves each Compose library to the newer of your version and that one, so adding the dependency can **upgrade** the Compose in your app. Material 3 is an internal dependency of the library, not part of its API: if your own code uses `MaterialTheme` or other Material 3 components, declare `androidx.compose.material3:material3` yourself.

## Add the dependency

The artifacts live on Maven Central, so make sure it is in your repositories - in `settings.gradle` for most modern projects:

```groovy
dependencyResolutionManagement {
  repositories {
    google()
    mavenCentral()
  }
}
```

Then add the dependency to your **module's** `build.gradle`:

<Tabs groupId="gradle-dsl">
  <TabItem value="kotlin" label="Kotlin DSL">

```kotlin
dependencies {
  implementation("com.swmansion.enriched.markdown:compose:0.3.0")
}
```

  </TabItem>
  <TabItem value="groovy" label="Groovy">

```groovy
dependencies {
  implementation 'com.swmansion.enriched.markdown:compose:0.3.0'
}
```

  </TabItem>
</Tabs>

Sync Gradle and you're done. There is no initialization call and no native setup step - the parser ships as a prebuilt `.so` inside the AAR and loads itself on first use.

### Internet permission

The library does not declare `android.permission.INTERNET`. If your Markdown references **remote** images, add it to your app's `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Local image sources and text-only documents work without it.

### Native libraries

The parser's `.so` is built for `armeabi-v7a`, `arm64-v8a`, `x86`, and `x86_64`, so it runs on every device and emulator ABI. It links the shared C++ runtime and fbjni, and ships `libc++_shared.so` and `libfbjni.so` alongside its own library. Other native dependencies often bundle the same two files, which makes the merge fail with a duplicate-file error. Tell Gradle to keep one copy:

```kotlin
android {
  packaging {
    jniLibs {
      pickFirsts += listOf("**/libc++_shared.so", "**/libfbjni.so")
    }
  }
}
```

:::caution
If the parser's native library fails to load - for example, because an ABI split or an `abiFilters` setting dropped it from the APK - the app does not crash. The failure is only logged (tag `MarkdownParser`) and every `EnrichedMarkdownText` renders empty. Check logcat before suspecting your Markdown.
:::

## The artifacts {#artifacts}

The package publishes five artifacts under the `com.swmansion.enriched.markdown` group, all with the same version:

| Artifact | What it is | Depend on it directly? |
| --- | --- | --- |
| `compose` | The Jetpack Compose API: `EnrichedMarkdownText`, `MarkdownTheme`, the `markdownStyle` DSL | **Yes** - this is the one you declare |
| `ui` | The view-based renderer underneath, which lays the document out in native views | No - comes transitively |
| `parser` | The native [md4c](https://github.com/mity/md4c) parser and its JNI bindings | No - comes transitively |
| `math` | Optional LaTeX math rendering, backed by the RaTeX engine (`io.github.erweixin:ratex-android`) | Only if you render math |
| `code-highlight` | Optional syntax highlighting for fenced code blocks, backed by tree-sitter | Only if you color code |

`compose` exposes `ui` as an `api` dependency, and `ui` does the same for `parser`, so declaring `compose` is enough to get all three. Split them out only if you are embedding the renderer in a View-based screen with no Compose at all, which is outside what these docs cover.

### Math is opt-in

`math` is kept out of `compose` because its engine is heavy, and because that engine ships native libraries for `arm64-v8a`, `armeabi-v7a`, and `x86_64` only - **not 32-bit `x86`**. An app that renders no math leaves it out and pays nothing for it. If you do need it, add it next to `compose`, at the same version:

```kotlin
dependencies {
  implementation("com.swmansion.enriched.markdown:compose:0.3.0")
  implementation("com.swmansion.enriched.markdown:math:0.3.0")
}
```

On an `x86` device or emulator, equations fall back to their raw source rather than crashing. Enabling the plugin and the parser flag that goes with it is covered in [LaTeX math](/android/guides/latex-math).

### Code highlighting is opt-in

`code-highlight` is kept out of `compose` for its size: it compiles tree-sitter and 14 grammars into a native library of about 8 MB per ABI installed (about 1.1 MB per ABI of download). It is built for all four ABIs the parser supports, `x86` included. An app that shows no code leaves it out; one that does adds it at the same version:

```kotlin
dependencies {
  implementation("com.swmansion.enriched.markdown:compose:0.3.0")
  implementation("com.swmansion.enriched.markdown:code-highlight:0.3.0")
}
```

Without it, or with it but not enabled, code blocks render in the plain `codeBlock` color. Enabling it and setting token colors is covered in [Code highlighting](/android/guides/code-highlighting).

## R8 and ProGuard

Nothing to configure. The parser is reached from C++ through hardcoded class-name lookups that R8 cannot trace, so the `parser` artifact ships the `-keep` rules it needs as **consumer** ProGuard rules. `math` and `code-highlight` ship their own as well: `math` keeps the RaTeX engine's classes, `code-highlight` keeps the class its native library binds to by name, and both stop R8 from failing on a Compose runtime annotation in a View-only app. Every set is applied to your app automatically when you enable minification.

## Next steps

You're set up. Next let's [put Markdown on the screen](/android/basics/your-first-screen).
