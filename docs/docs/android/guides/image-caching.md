---
sidebar_label: Images and caching
sidebar_position: 1
---

# Images and caching

Images in Markdown are loaded, decoded, and cached automatically - there is no image library to configure and no loader to inject. This guide covers where an image can come from and what happens to it on the way to the screen.

For how the same syntax produces a block or an inline image, see [Element structure](/android/api-reference/element-structure#images-block-vs-inline); for their appearance, the [`image`](/android/api-reference/style-properties#image) and [`inlineImage`](/android/api-reference/style-properties#inlineimage) style blocks.

## Where images can come from

The URL in `![alt](url)` is resolved by scheme, and rather more than `https://` works:

| Source | Example |
| --- | --- |
| Remote | `https://example.com/hero.png` |
| Bundled asset | `file:///android_asset/hero.png`, or `asset://hero.png` |
| Resource by name | `file:///android_res/drawable/hero.png`, `res://hero`, or a bare `hero` |
| Absolute file path | `file:///data/user/0/…/hero.png`, or a path starting with `/` |
| Content provider | `content://media/external/images/media/42` |
| Inline data | `data:image/png;base64,iVBORw0…` |

A bare name with no scheme is treated as a **resource name**, normalized the way Android normalizes them - lowercased, with `-` replaced by `_` - and looked up in `drawable` first, then `raw`. A numeric resource id works too. `file:///android_res/…` strips the density qualifier and extension before its lookup, so `drawable-xhdpi/hero.png` resolves to the `drawable/hero` resource.

Two details to note: a `data:` URI must be **base64-encoded**, since that is the only form decoded - a plain-text `data:image/svg+xml,<svg…>` is not read. And an unrecognized scheme, a missing resource, or an unreadable file is skipped and logged rather than crashing the render.

Remote images are the only kind that touch the network; everything else is decoded straight from the device.

:::note
Remote images need the `INTERNET` permission in your manifest. Documents that only reference local sources do not.
:::

## Everything is downsampled

However large the source, an image is never decoded at more than roughly the **screen width**. The dimensions are read first, and an image wider than the display is decoded subsampled by a power of two - so a 4000px photograph on a 1080px-wide phone decodes at a quarter scale, costing a sixteenth of the memory a full decode would. An image already at or below screen width is decoded as-is.

This is automatic and not configurable. It applies to every source, local and remote alike - `content://` images, `data:` URIs, and bundled assets all go through the same decode path.

## Cache layers

Three caches sit between a URL and a painted image, and a hit in an earlier one short-circuits the rest.

### Processed bitmap cache (memory, 30 MB)

The last stop before painting. Holds bitmaps already scaled and corner-rounded for a specific slot, keyed by the request **plus** the width, height, and border radius it was drawn at. The same image at two different sizes is two entries, because they are two different bitmaps.

### Original bitmap cache (memory, 20 MB)

Holds the decoded source bitmap, keyed by the request. A processed-cache miss - a different size, say, or a changed corner radius - reprocesses from here without decoding again.

Both memory caches are LRU and measured in bytes of bitmap, so they hold fewer large images than small ones. They are process-wide and shared by every `EnrichedMarkdownText` in your app.

### HTTP cache (disk, 100 MB)

Remote responses are cached on disk by OkHttp, under `enrm_image_cache` in your app's cache directory, honoring the usual HTTP caching headers. This one survives process death: an image fetched yesterday is still there on a cold start, and only needs decoding rather than downloading.

Requests time out after 15 seconds to connect and 15 to read.

## Request headers

[`imageRequestHeaders`](/android/api-reference/enriched-markdown-text#imagerequestheaders) attaches headers to every remote image request in a document - a bearer token for a private CDN, a `Referer` for a host that requires one:

```kotlin
EnrichedMarkdownText(
  markdown = content,
  imageRequestHeaders = mapOf("Authorization" to "Bearer $token"),
)
```

Headers participate in the **cache key**. The same URL fetched with different headers is cached and deduplicated separately, so one user's authorized image is never served to another. The key appends a SHA-256 digest of the sorted header pairs rather than the values themselves, so nothing sensitive is held in a cache key.

## Concurrent requests are deduplicated

If the same image appears five times in a document - or in five documents on screen at once - it is downloaded **once**. Requests arriving while a download is in flight attach to it and are all handed the result when it lands. Deduplication is keyed the same way as the cache, so requests differing only in headers are correctly treated as different.
