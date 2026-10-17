---
sidebar_label: Custom block renderers
sidebar_position: 8
---

import LivePreview from '@site/src/components/LivePreview';
import ImageFigureSrc from '!!raw-loader!@site/src/examples/react-native/guides/custom-block-renderers/ImageFigure';
import SignedImagesSrc from '!!raw-loader!@site/src/examples/react-native/guides/custom-block-renderers/SignedImages';

# Custom block renderers

`EnrichedMarkdownText` renders everything natively, but three kinds of block are often app-specific: standalone images, videos, and links that stand on their own line (a PDF, a YouTube URL, a repository, anything that deserves a card). [`renderers`](/react-native/api-reference/enriched-markdown-text#renderers) lets you draw those with your own React components (a lightbox-aware image, a video player you already ship, a skeleton while a signed URL loads) while every other part of the document stays native text with native selection, accessibility and streaming.

If you only need to change _where_ an image is loaded from, not how it looks, use [`resolveImageSource`](/react-native/api-reference/enriched-markdown-text#resolveimagesource) instead; it keeps the native image and swaps the request.

Both props need `flavor="github"` and, on iOS and Android, the New Architecture; on web they just work.

## Which blocks can be replaced

A renderer runs for a block when all of these hold:

- it is a paragraph whose only content is an image (`![alt](url)` on its own), a paragraph whose only content is a link (`[label](url)`, `<url>` or a bare URL on its own), or a `<video src="...">` block;
- it sits directly in the document, in a blockquote or in an admonition, and none of those is inside a list item.

Images in lists, tables, headings, links and running text are never replaced (a list is laid out as one run of text natively, so neither is anything nested in one). They stay native so the text around them keeps flowing; for them, `resolveImageSource` is still available.

Each block comes with a stable `id`: its kind, a hash of the URL exactly as written, and its index among _blocks_ of the same kind and URL. Streaming appends, edits elsewhere in the document and inline images being added or removed do not change it, so your elements are not remounted.

## How the layout works

Your element is rendered as a React child of the native host. The host's shadow node measures it with React Native's layout engine at the width the block would have had (the content width, or the inner width of its blockquote), then reserves exactly that height in the native layout and positions the element there. Nothing is drawn twice and nothing waits for a round trip to JS: the slot and the Markdown land in the same commit.

Two consequences:

- The element must have an **intrinsic height**. A view with `flex: 1` and nothing inside is 0pt tall. Give images an `aspectRatio` or a fixed height, as you would inside a `ScrollView`.
- The element's **width is set by the host**. Use `width: '100%'` or let the content fill; a fixed width narrower than the block is honoured but the slot still spans the block's width.

When your element changes height later (an image loads, text wraps), React Native lays it out again and the host shifts the following blocks. The reserved gap uses the same margins as the native image or video would (`markdownStyle.image.marginTop/marginBottom`, `markdownStyle.video.marginTop/marginBottom`).

<LivePreview src={ImageFigureSrc} />

## Keeping native rendering for some blocks

Return `null` or `undefined` from a renderer to keep the native image, video or link for that block. One `link` renderer usually fans out by URL: a file card for `.pdf`, a player for YouTube, a preview for everything else, and `null` for links that should stay plain. The decision can depend on anything in the block (`url`, `altText`, `title`, `placement`). Renderers run again when the block list or the renderer function changes, so a decision that depends on other state (say, a set of URLs that failed natively) should be in the renderer's dependencies: pass a new function and the block is placed on the next commit.

A renderer that throws, or returns a string or number, keeps the native block and warns in development; wrap text in `<Text>`.

## Streaming

With `streamingAnimation`, incomplete trailing tables, math and code fences are hidden until they close, and so is a trailing image or video whose syntax is still open: a half-streamed `![alt](https://…` never flashes as text, and a partial `<video` tag is never parsed as a video with a bogus URL. The same filter (one implementation in the C++ core) runs for the native host and for the block collector, so no slot is mounted for a block that is not rendered yet; once the line closes, the block is placed and your element appears.

If a block still appears a chunk before the text that follows it, set [`streamingConfig={{ mediaMode: 'hidden' }}`](/react-native/api-reference/enriched-markdown-text#streamingconfig): the block is then withheld until a blank line or another block follows it, the same rule as `tableMode: 'hidden'`. Both modes need `flavor="github"`.

## Swapping the request, not the view

`resolveImageSource` is called once per image occurrence id for the lifetime of the component, including images inside lists, tables, blockquotes and links. A streaming append or an edit elsewhere only asks about the images that are new; earlier results stay applied, so a signed image never flickers back to its placeholder mid-stream. The function is read like an event handler (a new function does not resolve again); remount with a `key` to start over. Return a `{ uri, headers }` object (synchronously or as a promise) to fetch from there, or `null`/`undefined` to load the Markdown URL. Per-image headers merge over [`imageRequestHeaders`](/react-native/api-reference/enriched-markdown-text#imagerequestheaders), header names are case-insensitive, and the effective URI and headers identify the decoded cache entry, so two images with different tokens never share bytes.

While a promise is pending, and when it rejects or resolves to an empty `uri`, the image keeps its placeholder and the original URL is **not** requested. Events (`onImagePress`), copy actions and `renderers` keep reporting the Markdown URL.

<LivePreview src={SignedImagesSrc} />

## Testing a renderer

The example app's Storybook has a `Renderers` story (`EnrichedMarkdownText / Props / Renderers`) that renders every placement a renderer can see next to every one that stays native, with a button that streams the document so you can watch blocks arrive, and controls for `streamingConfig.mediaMode` and `resolveImageSource`. Its `Link Cards` story does the same for standalone links. Drop your renderer into it to check placement, height and streaming before wiring it into an app.

In Jest, mock the parser module and assert on the slot children the component mounts; `__tests__/renderers.test.tsx` in the package shows the pattern, including a renderer that throws and an image source that settles after the document changed.

## Web

Both props work on web with the same ids and placements. `renderers` elements replace the `<img>`/`<video>` in the DOM, and `resolveImageSource` changes the `src`; headers are dropped because `<img>` requests cannot carry them.
