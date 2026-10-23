---
sidebar_label: Markdown streaming
sidebar_position: 2.7
---

# Markdown streaming

Streaming ships as a **separate product**, `EnrichedMarkdownStreaming`, so apps that only show finished documents do not link it. It is for Markdown that is still arriving, such as an answer from a language model. While a view streams, half-written syntax never shows up raw, unfinished blocks wait until they are ready, and new text fades in.

Linking the product changes nothing on its own: a view streams only while you apply `.markdownStreaming`.

## Turning it on

Add the `EnrichedMarkdownStreaming` product alongside `EnrichedMarkdown` (see [The products](/ios/basics/installation#products)). Then pass the whole string on every update, and keep the view marked as streaming until the answer is complete:

```swift
import EnrichedMarkdown
import EnrichedMarkdownStreaming
import SwiftUI

struct AnswerView: View {
  @State private var markdown: String = ""
  @State private var isStreaming: Bool = true

  var body: some View {
    EnrichedMarkdownText(markdown)
      .markdownStreaming(isStreaming)
      .task {
        for await token in model.tokens() {
          markdown += token
        }
        isStreaming = false
      }
  }
}
```

### `.markdownStreaming` {#markdownstreaming}

Marks the Markdown as still arriving. Pass `false` once the answer is complete.

<PropInfo type="Bool" default="true" />

```swift
extension View {
  func markdownStreaming(
    _ isStreaming: Bool = true,
    tables: MarkdownStreamingOptions.TableMode = .progressive,
    codeBlocks: MarkdownStreamingOptions.CodeBlockMode = .progressive,
    transition: any MarkdownStreamingTransition = .opacity
  ) -> some View
}
```

It sets the `markdownStreaming` environment value: a `MarkdownStreamingOptions` while streaming, `nil` otherwise.

#### `tables`

What a table shows while it is still arriving.

<PropInfo type="MarkdownStreamingOptions.TableMode" default=".progressive" />

| Mode | While the table arrives |
| --- | --- |
| `.progressive` | It appears once its header and delimiter rows are in, then grows row by row. A half-written row waits. |
| `.hidden` | It stays hidden until a blank line follows it. |

#### `codeBlocks`

What a fenced code block shows while it is still arriving.

<PropInfo type="MarkdownStreamingOptions.CodeBlockMode" default=".progressive" />

| Mode | While the code block arrives |
| --- | --- |
| `.progressive` | The code appears line by line. The block's copy actions and syntax highlighting wait for the closing fence. |
| `.hidden` | The block stays hidden until its closing fence arrives. |

#### `transition`

How new text appears.

<PropInfo type="any MarkdownStreamingTransition" default=".opacity" />

| Transition | New text |
| --- | --- |
| `.opacity` | Fades in over 0.2 seconds |
| `.opacity(duration:)` | Fades in over your duration, in seconds |
| `.identity` | Appears at once |

To animate it your own way, see [Custom transitions](#custom-transitions).

## While the answer arrives

- **Finished text stays put.** Each update re-renders only the unfinished end of the answer. The text above it keeps its layout and selection, and tables and code blocks keep their scroll position. Updates stay fast however long the answer gets.
- **Unfinished syntax never shows raw.** `**bold`, `` `code`` and `[text](ur` render as if they were already closed. A lone `**` at the very end waits for the next token. The rules follow [remend](https://www.npmjs.com/package/remend).
- **Unfinished blocks wait**, as set by [`tables`](#tables) and [`codeBlocks`](#codeblocks). With [LaTeX math](/ios/guides/latex-math) on, a formula stays hidden until its closing `$` or `$$` arrives. A `$` next to a digit or a space is a price, not math.
- **New text animates in**, as set by [`transition`](#transition). Selection and VoiceOver are not affected. With Reduce Motion on, new text appears at once.

Each update should extend the previous string. A string that does not, such as a regenerated answer, starts over. A document that ends with a link reference definition (`[label]: url`), or one parsed with [`preserveBlankLines`](/ios/api-reference/enriched-markdown-text#preserveblanklines), re-renders in full on every update.

## When the answer is complete

Set `isStreaming` to `false`. The view then renders the Markdown exactly as written, without repairs or hidden blocks. Only the parts that differ are updated, so the text does not flash.

## Custom transitions {#custom-transitions}

To animate new text your own way, conform to `MarkdownStreamingTransition` and pass the value as `transition`:

```swift
public protocol MarkdownStreamingTransition: Equatable, Sendable {
  @MainActor
  func animate(_ view: UIView, completion: @escaping () -> Void)
}
```

`view` shows the new text. Set its starting state, animate it, and call `completion` when done:

```swift
struct RiseTransition: MarkdownStreamingTransition {
  func animate(_ view: UIView, completion: @escaping () -> Void) {
    view.alpha = 0
    view.transform = CGAffineTransform(translationX: 0, y: 6)
    UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
      view.alpha = 1
      view.transform = .identity
    } completion: { _ in
      completion()
    }
  }
}

EnrichedMarkdownText(markdown)
  .markdownStreaming(isStreaming, transition: RiseTransition())
```

Behavior worth knowing:

- **`animate` runs once per line.** New text that wraps onto two lines gets two calls. Each new table row gets its own call, and so does each new math block. The table or code block around the new content never animates.
- **`view` shows the new content.** For text and table rows it is a `UIImageView` snapshot, drawn exactly where the text sits. For a math block it is the block's own view.
- **Always call `completion`.** The real text under the snapshot stays hidden until every call for that update has completed.
- **Keep it cheap.** When the next update re-wraps a line, its snapshot is replaced and animated again.
- **Keep parameters in stored properties.** Transitions are compared with `Equatable`, so let Swift generate `==` from them.
- **Reduce Motion skips every transition**, the built-in ones included.

`.opacity` and `.identity` build the two built-in types, `OpacityStreamingTransition(duration:)` and `IdentityStreamingTransition()`.

## See also

- [Markdown streaming](/rich-text-formatting/markdown-streaming) - the feature at large.
- [LaTeX math](/ios/guides/latex-math) and [Syntax highlighting](/ios/guides/syntax-highlighting) - the other optional products, set up the same way.
