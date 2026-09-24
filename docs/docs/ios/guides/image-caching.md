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

A bare name is resolved against your app bundle: first as a loose resource file (with `png`, `jpg`, `jpeg`, `gif`, or `heic` tried in that order when you omit the extension), then as an asset catalog image. If neither matches, the name is **normalized** - lowercased, with `-` replaced by `_` - and both lookups are tried again - so `![](my-logo.png)` also finds an asset named `my_logo`.

```markdown
![Our logo](logo.png)
![A diagram](diagram-v2.png)
```

Sources with no iOS equivalent - `content://`, `asset://`, `res://` - log a message and render nothing. So does a name that matches no resource.

:::note
Local sources need no network and no `Info.plist` entry. Only `http(s)` images touch the network, and only they take part in the download cache.
:::

## Sizing

Whether an image is drawn as a block or in the text flow depends on what else shares its paragraph - see [Images: block vs. inline](/ios/api-reference/element-structure#images-block-vs-inline). Sizing follows from that: `BlockImage().height` (default `200`) for a block image, `InlineImage().size` (default `20`) for an inline one, and `BlockImage().cornerRadius` for rounded corners. Width, aspect ratio, and content mode are not configurable yet - see the [roadmap](/misc/roadmap#ios).

## Decoding

Every image is **downsampled while decoding** so its longer side is at most the screen's pixel width, and it is never upscaled. A 4000 px photograph therefore costs a screen-width bitmap rather than a full-size one, and EXIF orientation is baked into the result.

The one exception is an asset catalog image, which has no file URL to decode from: it loads through `UIImage(named:)`, which already picks the right-sized variant for the device.

## The two caches

Nothing has to be configured, but knowing the shape of it explains why a second render is instant and why memory does not grow without bound.

| Cache | What it holds | Limits |
| --- | --- | --- |
| Decoded images | Ready-to-draw `UIImage`s, keyed by request | 50 images, 20 MB |
| HTTP responses | Raw bytes from `http(s)` downloads | 10 MB in memory, 100 MB on disk |

The decoded cache is what makes a re-render - a theme change, a Dynamic Type switch, a scroll that recycles the text view - flicker-free: the image is already there and hits synchronously. The HTTP cache is a `URLCache` on the package's own `URLSession`, consulted before the network (`returnCacheDataElseLoad`), with a 15-second request and 30-second resource timeout.

Concurrent requests for the same image are **deduplicated in flight**: ten paragraphs referencing one URL produce one download and ten callbacks.

Both caches live for the lifetime of the process, are shared by every `EnrichedMarkdownText` in the app, and have no public API to clear or resize. If an image has to be re-fetched after it changes on the server, change its URL - a cache-busting query parameter is the usual way - rather than looking for an invalidation call.

## Authenticated images

[`.markdownImageRequestHeaders`](/ios/api-reference/enriched-markdown-text#markdownimagerequestheaders) attaches headers to every remote image request in the subtree:

```swift
EnrichedMarkdownText(content)
  .markdownImageRequestHeaders(["Authorization": "Bearer \(token)"])
```

The headers take part in the **cache key**, as a hash of the sorted `key:value` pairs appended to the URL. Two consequences:

- The same URL fetched with different headers is cached and deduplicated separately, so one user's authorized image is never served to another's session.
- **Rotating a token invalidates the cache for every image it covers.** The new header set produces a new key, so the images are fetched again. Keep the header dictionary stable while it does not need to change - rebuilding an identical dictionary is fine, since the key is computed from the contents.

## See also

- [`.markdownImageRequestHeaders`](/ios/api-reference/enriched-markdown-text#markdownimagerequestheaders) - the modifier reference.
- [`BlockImage()` / `InlineImage()`](/ios/api-reference/style-properties#blockimage) - sizing and corner radius.
