package swmansion.enriched.markdown.android.example

/**
 * One card on the What's New screen: a feature, the markdown that exercises
 * it, and the gesture the demo invites.
 */
data class WhatsNewFeature(
  val id: String,
  val title: String,
  /** One sentence on what the renderer does with it. */
  val blurb: String,
  /** The markdown the card renders, shown verbatim above the render. */
  val source: String,
  /** Interaction cue printed under the render, if the render answers touch. */
  val hint: String? = null,
  /** Milliseconds the guided tour rests on the card before moving on. */
  val dwellMillis: Long,
)

/**
 * The 0.2.0 additions to the Android renderer, GitHub Flavored Markdown first,
 * each short enough to read on one screen and most of them something to touch.
 */
val whatsNewFeatures: List<WhatsNewFeature> =
  listOf(
    WhatsNewFeature(
      id = "tables",
      title = "Tables",
      blurb =
        "Pipe tables become real grids: a header row, striped rows and per-column alignment. " +
          "A table wider than the screen keeps its columns and scrolls sideways instead of squeezing.",
      source =
        """
        | Planet | Moons | Day | Year | Diameter | Gravity | Mean temp | Rings |
        |:--|--:|--:|--:|--:|--:|--:|:--|
        | Mercury | 0 | 59 d | 88 d | 4,879 km | 3.7 m/s² | 167 °C | No |
        | Earth | 1 | 24 h | 365 d | 12,742 km | 9.8 m/s² | 15 °C | No |
        | Jupiter | 95 | 10 h | 12 y | 139,820 km | 24.8 m/s² | −110 °C | Yes |
        | Saturn | 146 | 11 h | 29 y | 116,460 km | 10.4 m/s² | −140 °C | Yes |
        """.trimIndent(),
      hint = "Drag the table sideways",
      dwellMillis = 6_000,
    ),
    WhatsNewFeature(
      id = "task-lists",
      title = "Task lists",
      blurb =
        "Checkboxes are drawn natively and answer a tap: the item toggles, the text can strike " +
          "through, and the app hears about every change.",
      source =
        """
        - [x] Parse GitHub task items
        - [x] Draw each checkbox natively
        - [ ] Tap one to toggle it
        - [ ] Hear about it in `onTaskListItemPress`
        """.trimIndent(),
      hint = "Tap a checkbox",
      dwellMillis = 4_500,
    ),
    WhatsNewFeature(
      id = "strikethrough",
      title = "Strikethrough & underline",
      blurb =
        "Double tildes strike a span through in the theme's color. Double underscores underline " +
          "once the parser flag is on.",
      source =
        """
        The oldest known tree has stood for
        ~~about 4,000~~ **about 4,850 years**.
        Its exact location is __kept secret__
        by the Forest Service.
        """.trimIndent(),
      dwellMillis = 3_500,
    ),
    WhatsNewFeature(
      id = "scripts",
      title = "Superscript & subscript",
      blurb =
        "Carets raise a span and single tildes lower it, each scaled and shifted relative to the " +
          "text around it.",
      source =
        """
        Water is H~2~O, Avogadro counted
        6.022 × 10^23^ particles per mole,
        and E = mc^2^ still holds.
        """.trimIndent(),
      dwellMillis = 3_500,
    ),
    WhatsNewFeature(
      id = "admonitions",
      title = "Admonitions",
      blurb =
        "GitHub's five admonition types, drawn as an icon and title over the quote's own geometry, " +
          "with a bar and fill of the same hue.",
      source =
        """
        > [!TIP]
        > A quote that opens with a type marker.

        > [!IMPORTANT]
        > Note, tip, important, warning and caution.

        > [!CAUTION]
        > Each type keeps its own icon, title and tint.
        """.trimIndent(),
      dwellMillis = 3_500,
    ),
  )
