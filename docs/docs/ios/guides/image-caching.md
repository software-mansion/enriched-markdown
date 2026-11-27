---
sidebar_label: Images and caching
sidebar_position: 3
---

# Images and caching

Two things about images are easy to get wrong because nothing on screen tells you about them: **far more sources work than `![alt](https://…)` suggests**, and the caches that make re-rendering cheap are invisible and process-wide. This page covers both.

## Where an image can come from

`![alt](source)` accepts five kinds of source:

| Source | Example | Notes |
| --- | --- | --- |
| `http(s)://` | `![](https://example.com/pic.png)` | Downloaded, cached, and deduplicated in flight |
| `file://` | `![](file:///var/…/pic.png)` | Percent-encoded paths work |
| Absolute path | `![](/var/…/pic.png)` | Anything starting with `/` |
| `data:` | `![](data:image/png;base64,…)` | Base64 payloads |
| Bundle resource name | `![](logo.png)` | Looked up in `Bundle.main` |

A bare name is resolved against `Bundle.main`, trying the name as written and then its **normalized** form - lowercased, with `-` replaced by `_`. The lookups run in this order, and the first hit wins:

1. A loose resource file under the name as written. When you omit the extension, `png`, `jpg`, `jpeg`, `gif`, and `heic` are tried in that order.
2. A loose resource file under the normalized name.
3. An asset catalog image under the name as written.
4. An asset catalog image under the normalized name.

So `![](My-Logo.png)` finds a bundled file `my_logo.png`, and `![](my-logo)` finds an asset catalog image named `my_logo`. Because loose files are tried first under both spellings, `![](my-logo)` picks a loose `my_logo.png` over an asset named `my-logo`.

```markdown
![Our logo](logo.png)
![A diagram](diagram-v2.png)
```

Sources with no iOS equivalent - `content://`, `asset://`, `res://` - log a message and render nothing. So does a name that matches no resource.

:::note
Local sources need no network and no `Info.plist` entry. Only `http(s)` images touch the network, and only they take part in the HTTP response cache. The in-memory caches and the in-flight deduplication below apply to every source.
:::

## Sizing

Whether an image is drawn as a block or in the text flow depends on what else shares its paragraph - see [Images: block vs. inline](/ios/api-reference/element-structure#images-block-vs-inline). An inline image is a square of `InlineImage().size` points (default `20`). A block image always spans the **available width** - there is no width setting - and its height comes from exactly one of three [`BlockImage()`](/ios/api-reference/style-properties#blockimage) sizing modifiers:

| Sizing | Box height | Default content mode |
| --- | --- | --- |
| `.height(_:)` | Fixed, in points. The default theme sets `200` | `.fitWidth` |
| `.maxHeight(_:)` | The image's own proportions at the available width, capped at this height. Until the image loads, the box stands at the cap | `.fill` |
| `.aspectRatio(_:)` | The available width divided by the ratio, e.g. `16 / 9` | `.fill` |

The three are mutually exclusive: the last one applied wins. `.contentMode(_:)` overrides how the bitmap fills the box - `.fit`, `.fill`, `.stretch`, `.scaleDown`, `.original`, or `.fitWidth` - and `.aspectRatio(_:contentMode:)` sets the ratio and the mode at once. `.cornerRadius(_:)` (default `8`) rounds it.

```swift
import EnrichedMarkdown
import SwiftUI

struct ArticleView: View {
  let content: String

  var body: some View {
    EnrichedMarkdownText(content)
      .markdownTheme {
        BlockImage()
          .aspectRatio(16 / 9, contentMode: .fill)
          .cornerRadius(12)
      }
  }
}
```

## Decoding

Every image is **downsampled while decoding** so its longer side is at most the screen's pixel width, and it is never upscaled. A 4000 px photograph therefore costs a screen-width bitmap rather than a full-size one, and EXIF orientation is baked into the result.

The one exception is an asset catalog image, which has no file URL to decode from: it loads through `UIImage(named:)`, which already picks the right-sized variant for the device.

## The three caches

Nothing has to be configured, but knowing the shape of it explains why a second render is instant and why memory does not grow without bound.

| Cache | What it holds | Limits |
| --- | --- | --- |
| Decoded images | Ready-to-draw `UIImage`s from **every** source, keyed by source and headers | 50 images, 20 MB |
| Processed images | Bitmaps already scaled into their box, keyed by source, headers, corner radius, content mode, and box size | 100 images, 30 MB |
| HTTP responses | Raw bytes from `http(s)` downloads | 10 MB in memory, 100 MB on disk |

The decoded cache is what makes a re-render - a theme change, a Dynamic Type switch, a scroll that recycles the text view - flicker-free: the image is already there and hits synchronously, whether it came from the network, a file, a `data:` URI, or the bundle. The processed cache saves the scaling step on top of that when the same image is laid out in the same box again; a changed width, corner radius, or content mode scales it afresh from the decoded copy. The HTTP cache is a `URLCache` on the package's own `URLSession`, consulted before the network (`returnCacheDataElseLoad`), with a 15-second request and 30-second resource timeout.

Concurrent requests for the same image are **deduplicated in flight**, whatever the source: ten paragraphs referencing one URL produce one download - or one file read and decode - and ten callbacks.

All three caches live for the lifetime of the process, are shared by every `EnrichedMarkdownText` in the app, and have no public API to clear or resize. If an image has to be re-fetched after it changes on the server, change its URL - a cache-busting query parameter is the usual way - rather than looking for an invalidation call.

## Authenticated images

[`.markdownImageRequestHeaders`](/ios/api-reference/enriched-markdown-text#markdownimagerequestheaders) attaches headers to every remote image request in the subtree:

```swift
import EnrichedMarkdown
import SwiftUI

struct PrivateDocView: View {
  let content: String
  let token: String

  var body: some View {
    EnrichedMarkdownText(content)
      .markdownImageRequestHeaders(["Authorization": "Bearer \(token)"])
  }
}
```

Rendering without a view takes the same dictionary as the `imageRequestHeaders:` parameter of [`MarkdownRenderer.render`](/ios/api-reference/markdown-theme#markdownrenderer).

The headers take part in the **cache key**, as a hash of the sorted `key:value` pairs appended to the URL. Three consequences:

- The same URL fetched with different headers is cached and deduplicated separately, so one user's authorized image is never served to another's session. Header names are compared case-insensitively.
- **Header-bearing responses are not persisted on disk.** `URLCache` keys responses by URL alone and cannot tell two header sets apart, so requests with custom headers bypass it. They are served from the memory caches while the process lives and fetched again after a relaunch. Requests without headers keep the disk cache.
- **Rotating a token invalidates the cache for every image it covers.** The new header set produces a new key, so the images are fetched again. Keep the header dictionary stable while it does not need to change - rebuilding an identical dictionary is fine, since the key is computed from the contents.

## See also

- [`.markdownImageRequestHeaders`](/ios/api-reference/enriched-markdown-text#markdownimagerequestheaders) - the modifier reference.
- [`BlockImage()`](/ios/api-reference/style-properties#blockimage) and [`InlineImage()`](/ios/api-reference/style-properties#inlineimage) - every sizing, content mode, corner radius, and margin modifier.
- [Images: block vs. inline](/ios/api-reference/element-structure#images-block-vs-inline) - which of the two an image becomes.
