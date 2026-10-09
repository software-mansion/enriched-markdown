# Material 3 theme

Every color on this screen comes from the Material `ColorScheme`. Flip the switch above to move between the light and dark schemes.

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

---

## Table

| Element | Token |
| --- | --- |
| Paragraph | onSurface |
| Link | primary |
| Code block | surfaceContainer |
| Divider | outlineVariant |
