# Material 3 theme

The markdown below takes its colors from the Material `ColorScheme`, except the note, tip, important and warning alerts, which keep GitHub's alert colors, and code blocks, which keep the default dark style. Flip the switch above to move between the light and dark schemes.

## Inline formatting

Text can be **bold**, *italic*, ~~struck through~~, ==highlighted==, or a [link](https://swmansion.com). Inline `code` sits on a container color, and a spoiler hides ||the ending|| until it is tapped.

### Heading 3

#### Heading 4

##### Heading 5

###### Heading 6

## Blockquotes

> A plain blockquote uses the variant text color on a low container.

> [!NOTE]
> Notes, tips, important and warning keep GitHub's alert colors, picked for the scheme's brightness.

> [!TIP]
> Material 3 has no tokens for these.

> [!IMPORTANT]
> The palette switches with the scheme.

> [!WARNING]
> Check contrast in both modes.

> [!CAUTION]
> Caution uses the scheme's `error` color.

## Lists

- Bullets use the variant text color
- Nested items
  - follow the same colors
1. Numbered markers too
2. Second item

- [x] Checked boxes use `primary`
- [ ] Unchecked ones use `outline`

## Code

```kotlin
MaterialTheme(colorScheme = scheme) {
  MarkdownTheme(style = rememberMaterialMarkdownStyle()) {
    EnrichedMarkdownText(markdown)
  }
}
```

Kotlin has no grammar yet, so the block above stays plain. Java is highlighted:

```java
// Counts the words in a line of text.
public final class WordCounter {
  private static final String SEPARATOR = "\\s+";

  @Override
  public String toString() {
    return "WordCounter";
  }

  public static int count(String line) {
    if (line == null || line.isBlank()) {
      return 0;
    }
    return line.trim().split(SEPARATOR).length;
  }
}
```

---

## Table

| Element | Token |
| --- | --- |
| Paragraph | onSurface |
| Link | primary |
| Divider | outlineVariant |
