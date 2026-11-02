---
sidebar_label: Custom block renderers
sidebar_position: 8
---

import LivePreview from '@site/src/components/LivePreview';
import ImageFigureSrc from '!!raw-loader!@site/src/examples/react-native/guides/custom-block-renderers/ImageFigure';
import SignedImagesSrc from '!!raw-loader!@site/src/examples/react-native/guides/custom-block-renderers/SignedImages';

# Custom block renderers

[`renderers`](/react-native/api-reference/enriched-markdown-text#renderers) lets you draw three kinds of block with your own React components: standalone images, videos, and links on a line of their own. Use it for a lightbox-aware image, a video player you already ship, or a card for a PDF, a YouTube URL or a repository. Everything else in the document stays native text, with native selection, accessibility and streaming.

To change only _where_ an image loads from, not how it looks, use [`resolveImageSource`](/react-native/api-reference/enriched-markdown-text#resolveimagesource) instead. It keeps the native image and swaps the request.

On iOS and Android, both props need `flavor="github"`. Web has no `flavor` prop and supports both as is.

## Which blocks can be replaced

A renderer runs for a block when both of these hold:

- The block is one of:
  - a paragraph that is only an image: `![alt](url)`;
  - a paragraph that is only a link: `[label](url)`, `<url>` or a bare URL;
  - a `<video src="...">` block.
- It sits directly in the document, in a blockquote or in an admonition, and none of these is inside a list item.

One exception: a list item that holds only a video is [moved out of its list by the parser](/react-native/api-reference/element-structure#videos), so that video counts as a block of the list's container and can be replaced.

The block's `placement` tells you which container it is in: `root`, `blockquote` or `admonition`. Inside a quote or an admonition the block is narrower and indented, so you may want a smaller card there.

Images in lists, tables, headings, links and running text are never replaced. They stay native so the text around them keeps flowing. `resolveImageSource` still applies to them.

## Block ids

Each block has an `id`: an opaque string, the same on every platform. It stays the same while the block is unchanged, even as the document streams in or changes elsewhere, so React keeps your element mounted. Use it as a key for per-block state, such as a video's playback position.

An image block also has an `occurrenceId`. That is the id `resolveImageSource` sees for the same image, so you can match a block to its resolved source. Block ids and occurrence ids are never equal.

## Sizing your element

The host measures your element at the width the block would have had: the content width, or the inside of its blockquote. It then reserves exactly that height and places the element there. The element and the text around it appear in the same frame.

- **Give the element an intrinsic height.** A view with `flex: 1` and nothing inside is 0pt tall. Give images an `aspectRatio` or a fixed height, as you would inside a `ScrollView`.
- **The host sets the width.** Use `width: '100%'` or let the content fill it. A narrower fixed width is honoured, but the block still spans the full width.
- **Spacing matches the native block.** The space above and below comes from `markdownStyle.image`, `markdownStyle.video` or `markdownStyle.paragraph` (for links), as it would for the native block.

When your element changes height later, for example when an image loads, the blocks below move to make room.

<LivePreview src={ImageFigureSrc} />

## Keeping native rendering for some blocks

Return `undefined`, or nothing, to keep the native block. One `link` renderer usually decides by URL: a file card for `.pdf`, a player for YouTube, and no return for links that should stay plain.

A renderer runs again only when its block changes or when you pass a new renderer function. So if the decision depends on other state, such as a set of URLs that failed to load, wrap the renderer in `useCallback` with that state as a dependency. The [`renderers` reference](/react-native/api-reference/enriched-markdown-text#renderers) lists the rest of the contract: invalid return values, hooks, and presses.

## Streaming

With `streamingAnimation`, a block appears only once its syntax is complete. A half-streamed `![alt](https://…` or `[label](https://…` never shows as text, and your element is not created for a block that is still arriving. A bare URL on its own line can always grow, so it waits until the next line starts.

If a block still shows up a moment before the text after it, set [`streamingConfig={{ mediaMode: 'hidden' }}`](/react-native/api-reference/enriched-markdown-text#streamingconfig). The block then waits until a blank line or another block follows it, the same rule as `tableMode: 'hidden'`.

## Signed and authenticated images

Use [`resolveImageSource`](/react-native/api-reference/enriched-markdown-text#resolveimagesource) when the image is right but its request is not: a URL that needs a signature, or a token in a header. Return `{ uri, headers }`, or a promise of it, and the native image loads from there.

Each image is asked about once while it stays in the document. A streaming append only asks about new images, and about an image whose placement it changes (the paragraph continues past it), so a signed image never flickers back to its placeholder: it keeps its source until the new answer lands. Until the resolver answers, the image shows its placeholder and the Markdown URL is never requested. After a token refresh, remount the component with a `key` to ask again.

<LivePreview src={SignedImagesSrc} />

## Testing a renderer

The repository's example app has a Storybook story, `EnrichedMarkdownText / Props / Renderers`. It shows every placement a renderer can see next to the ones that stay native, with a button that streams the document and controls for `mediaMode` and `resolveImageSource`. Its `Link Cards` story does the same for links. Clone the repository and run the example app to try your renderer there.

In Jest, mock the `EnrichedMarkdownParser` native module and assert on the children the component mounts. The library's own [`renderers.test.tsx`](https://github.com/software-mansion/enriched-markdown/blob/main/packages/react-native-enriched-markdown/__tests__/renderers.test.tsx) shows the pattern.

## Web

Both props work on web with the same ids and placements. A renderer's element replaces the `<img>`, `<video>` or link paragraph in the DOM and keeps that block's spacing. `resolveImageSource` changes the `src`. Headers are dropped, because `<img>` requests cannot carry them.
