---
sidebar_label: Installation
sidebar_position: 1
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Installation

`enriched-markdown-android` is a **standalone Android library** - a Jetpack Compose component that renders Markdown as native text. It is published directly to Maven Central. You can add it to an Android app the way you add any other Gradle dependency, and you do not need React Native installed to use it.

## Requirements

| | |
| --- | --- |
| **Min SDK** | `24` (Android 7.0) |
| **Compile SDK** | `36` or newer |
| **Java** | 11 |
| **Kotlin** | 2.x, with the Compose compiler plugin (`org.jetbrains.kotlin.plugin.compose`) |
| **UI toolkit** | Jetpack Compose, with Material 3 |
| **AndroidX** | Required (`android.useAndroidX=true`) |

Your app's `compileSdk` has to be at least as high as the library's, which is why `36` is a floor rather than a suggestion - the Android Gradle Plugin fails the build if a dependency was compiled against a newer SDK than the consumer.

For the versions supported across all platforms, see [Compatibility](/misc/compatibility).

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
  implementation("com.swmansion.enriched.markdown:compose:0.1.0")
}
```

  </TabItem>
  <TabItem value="groovy" label="Groovy">

```groovy
dependencies {
  implementation 'com.swmansion.enriched.markdown:compose:0.1.0'
}
```

  </TabItem>
</Tabs>

Sync Gradle and you're done. There is no manifest entry, no initialization call, and no native setup step - the parser ships as a prebuilt `.so` inside the AAR and loads itself on first use.

:::tip
The library needs the Internet permission only if your Markdown references **remote** images. Local sources and text-only documents work without it.
:::

## What the artifact pulls in

The package publishes three artifacts under the `com.swmansion.enriched.markdown` group:

| Artifact | What it is | Depend on it directly? |
| --- | --- | --- |
| `compose` | The Jetpack Compose API: `EnrichedMarkdownText`, `MarkdownTheme`, the `markdownStyle` DSL | **Yes** - this is the one you declare |
| `ui` | The view-based renderer underneath, a `TextView` subclass driven by spans | No - comes transitively |
| `parser` | The native [md4c](https://github.com/mity/md4c) parser and its JNI bindings | No - comes transitively |

`compose` exposes both of the others as `api` dependencies, so declaring it is enough to get all three. Split them out only if you are embedding the renderer in a View-based screen with no Compose at all, which is outside what these docs cover.

## R8 and ProGuard

Nothing to configure. The parser is reached from C++ through hardcoded class-name lookups that R8 cannot trace, so the `parser` artifact ships the `-keep` rules it needs as **consumer** ProGuard rules. They are applied to your app automatically when you enable minification.

## Next steps

You're set up. Next let's [put Markdown on the screen](/android/basics/your-first-screen).
