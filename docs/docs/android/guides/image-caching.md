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

Two details to note: a `data:` URI must be **base64-encoded**, since that is the only form decoded - a plain-text `data:image/svg+xml,<svg…>` is not read. And an image that cannot be loaded never crashes the render; it is skipped. An unrecognized scheme, a missing resource, a file that cannot be opened, or a failed download is logged, but not every failure is: bytes that are not a decodable image - an HTML error page returned for a broken URL, say, or a `data:` URI without `base64,` - are dropped without a log line.

Remote images are the only kind that touch the network; everything else is decoded straight from the device. Local images are decoded **while the document renders**, before it is shown, so a large local image delays the whole document rather than popping in afterwards. The render runs off the main thread, so this costs time to first paint, not frames.

:::note
Remote images need the `INTERNET` permission in your manifest. Documents that only reference local sources do not.
:::

## When an image does not load

There is no placeholder and no fallback to the alt text. Until a remote image arrives - and permanently, if it never does - its slot stays **empty**, at the size the [`image`](/android/api-reference/style-properties#image) or [`inlineImage`](/android/api-reference/style-properties#inlineimage) style gives it. The alt text is still exposed to accessibility services, but nothing is drawn in its place.

## Everything is downsampled

Large images are never decoded at full size. The dimensions are read first, and an image wider than the display is decoded subsampled by the **largest power of two** that fits in the ratio of its width to the screen width, rounding down. That keeps the decoded bitmap under about **twice the screen width**: a 4000px photograph on a 1080px-wide phone (a ratio of 3.7) decodes at half scale - 2000px wide, a quarter of the memory a full decode would cost - while a 2000px image on the same phone is decoded as-is. An image already at or below screen width is always decoded as-is.

This is automatic and not configurable. It applies to every source, local and remote alike - `content://` images, `data:` URIs, and bundled assets all go through the same decode path.

## Cache layers

Three caches sit between a URL and a painted image. Loading always starts from the **original** bitmap - from memory, from the HTTP cache, or from the source - and the processed cache only comes into play once that bitmap is in hand.

### Original bitmap cache (memory, 20 MB)

Holds the decoded, downsampled source bitmap, keyed by the request. A hit here skips the download and the decode entirely. It is the cache that saves the most work.

### Processed bitmap cache (memory, 30 MB)

The last stop before painting. Holds bitmaps already scaled and corner-rounded for a specific slot, keyed by the request **plus** the width, height, and border radius it was drawn at. It is consulted after the original is available, so a hit saves the scaling and clipping work, not the load. The same image at two different sizes is two entries, because they are two different bitmaps; a miss - a different size, say, or a changed corner radius - reprocesses from the original. A processed bitmap is stored after the image is first drawn.

Both memory caches are LRU and measured in bytes of bitmap, so they hold fewer large images than small ones. They are process-wide and shared by every `EnrichedMarkdownText` in your app.

### HTTP cache (disk, 100 MB) {#http-cache}

Remote responses are cached on disk by OkHttp, under `enrm_image_cache` in your app's cache directory, honoring the usual HTTP caching headers. This one survives process death: an image fetched yesterday is still there on a cold start, and only needs decoding rather than downloading.

The disk cache applies only to requests **without** custom headers. A request made with [`imageRequestHeaders`](#request-headers) bypasses it entirely, so such images are held in memory only and are downloaded again after the process dies.

Requests time out after 15 seconds to connect and 15 to read.

### Clearing the caches

There is no API to clear or resize these caches. The memory caches are released with the process; the disk cache is an ordinary OkHttp cache in your app's cache directory, so it goes when the system or the user clears that.

## Request headers {#request-headers}

[`imageRequestHeaders`](/android/api-reference/enriched-markdown-text#imagerequestheaders) attaches headers to every remote image request in a document - a bearer token for a private CDN, a `Referer` for a host that requires one:

```kotlin
import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

@Composable
fun PrivateDocument(content: String, token: String) {
  EnrichedMarkdownText(
    markdown = content,
    imageRequestHeaders = mapOf("Authorization" to "Bearer $token"),
  )
}
```

Headers participate in the **cache key** of the in-memory caches. The same URL fetched with different headers is cached and deduplicated separately, so one user's authorized image is never served to another. Header names are compared case-insensitively - `Authorization` and `authorization` are the same header. The key appends a SHA-256 digest of the sorted header pairs rather than the values themselves, so nothing sensitive is held in a cache key.

Requests with headers never use the [disk cache](#http-cache): a cache keyed by URL alone could hand one user's response to another. An image loaded with headers lives in memory only, and is downloaded again after a cold start.

## Concurrent requests are deduplicated

If the same image appears five times in a document - or in five documents on screen at once - it is downloaded **once**. Requests arriving while a download is in flight attach to it and are all handed the result when it lands. Deduplication is keyed the same way as the cache, so requests differing only in headers are correctly treated as different.
