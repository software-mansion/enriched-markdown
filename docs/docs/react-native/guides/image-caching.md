---
sidebar_label: Image caching
sidebar_position: 2
---

# Image caching

Images in Markdown content are loaded, cached, and reused automatically - no configuration required. This page describes the **native** image pipeline on iOS, macOS and Android. On web the renderer emits a plain `<img src>`, so the library adds no caching of its own there and [`imageRequestHeaders`](/react-native/api-reference/enriched-markdown-text#imagerequestheaders) is not supported.

## Supported image sources

Markdown image URLs are strings, so bundled assets must be resolved to a URI before being interpolated into the markdown:

```tsx
import { Image } from 'react-native';

const logoUri = Image.resolveAssetSource(require('./assets/logo.png')).uri;
const markdown = `![Logo](${logoUri})`;
```

This works in every environment: in dev the URI is a Metro dev-server URL, while in a release build it resolves to a drawable resource name on Android and a bundle `file://` URL on iOS - all of which are supported. URIs from `expo-asset` (`asset.uri` / `asset.localUri`) work the same way.

| Source | Android | iOS / macOS |
|---|---|---|
| `http://`, `https://` | Yes | Yes |
| `file://` (including percent-encoded paths) | Yes | Yes |
| Bare asset name (release builds, expo-asset `localUri`) | Yes (drawable/raw resource) | Yes (bundle resource) |
| `file:///android_res/...`, `file:///android_asset/...` | Yes | No |
| `asset://`, `res://`, `content://` | Yes | No |
| Bare absolute filesystem path (`/path/to/img.png`) | Yes | Yes |
| `data:` (base64) | Yes | Yes |

Local sources skip the HTTP layers below (disk cache, request headers, deduplication) but still use both memory cache tiers.

:::note
`data:` URIs are the exception on iOS and macOS: only `file://` and scheme-less strings count as local there, so a data URI goes **through** the HTTP layers (via `URLSession`) rather than around them. It works either way. On Android only the base64 form is decoded - `data:image/svg+xml,<svg...>` yields nothing.
:::

## Cache layers

The library uses a three-tier caching strategy on both platforms:

| Layer | Android | iOS / macOS | Size |
|---|---|---|---|
| **Originals (memory)** | `LruCache` | `NSCache` | 20 MB |
| **Processed variants (memory)** | `LruCache` | `NSCache` | 30 MB |
| **Disk** | OkHttp `Cache` | `NSURLCache` | 100 MB |

- **Original cache** stores decoded images keyed by URL. On Android, large images are downsampled to screen width during decode to reduce peak memory.
- **Processed cache** stores scaled and clipped variants keyed by URL + dimensions + border radius + resize mode, so repeated layouts with the same geometry skip all image processing.
- **Disk cache** persists raw HTTP responses across app launches. On Android this is a stock OkHttp `Cache`, which honors `Cache-Control` normally. **On iOS and macOS it does not**: the session runs with `NSURLRequestReturnCacheDataElseLoad`, so a cached response is served regardless of its age or `max-age`, and the network is only hit when nothing is cached. A stale image stays stale until it is evicted.

Two limits are not byte budgets and can evict earlier than the sizes above suggest: on iOS and macOS the originals cache holds at most 50 entries and the processed cache at most 100, and its `NSURLCache` also has a 10 MB in-memory capacity alongside the 100 MB on disk.

All of these are **process-global singletons** shared by every `EnrichedMarkdownText` in the app, and there is no public API to inspect, clear, or invalidate them.

## Request headers

When [`imageRequestHeaders`](/react-native/api-reference/enriched-markdown-text#imagerequestheaders) is set, the headers become part of the cache identity for both memory tiers and for request deduplication: the same URL requested with different headers is fetched and cached separately, and changing the prop re-fetches the images.

:::caution
The disk cache is managed by the HTTP stack (OkHttp / `NSURLCache`) and keys responses **by URL alone**, with no `Vary` handling added by this library. A response fetched with one set of headers can therefore be served from disk for a request with different headers. If per-header isolation matters - a signed CDN URL, a per-user `Authorization` - make the difference part of the URL.
:::

## Request deduplication

When multiple components request the same image URL simultaneously (e.g. during a re-render), only one network request is made. All pending callbacks are coalesced and dispatched together once the download completes.

## Instance reuse

A fresh `ImageSpan` (Android) or `ENRMImageAttachment` (iOS) is created per render **on purpose**, never pooled or shared per URL. The same URL can be drawn at different widths - inside a table and outside it - and a shared attachment would thrash its single last-processed width into a redraw loop. The two memory tiers are what make a fresh instance cheap: no re-fetch and no re-scale.
