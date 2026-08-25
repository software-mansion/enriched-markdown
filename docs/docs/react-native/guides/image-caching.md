---
sidebar_label: Image caching
sidebar_position: 2
---

# Image caching

:::caution
THIS PAGE IS WORK IN PROGRESS
:::

Images in Markdown content are loaded, cached, and reused automatically — no configuration required.

## Cache layers

The library uses a three-tier caching strategy on both platforms:

| Layer | Android | iOS | Size |
|---|---|---|---|
| **Originals (memory)** | `LruCache` | `NSCache` | 20 MB |
| **Processed variants (memory)** | `LruCache` | `NSCache` | 30 MB |
| **Disk** | OkHttp `Cache` | `NSURLCache` | 100 MB |

- **Original cache** stores decoded images keyed by URL. On Android, large images are downsampled to screen width during decode to reduce peak memory.
- **Processed cache** stores scaled and clipped variants keyed by URL + dimensions + border radius, so repeated layouts with the same geometry skip all image processing.
- **Disk cache** persists raw HTTP responses across app launches, respecting standard HTTP cache headers.

## Request deduplication

When multiple components request the same image URL simultaneously (e.g. during a re-render), only one network request is made. All pending callbacks are coalesced and dispatched together once the download completes.

## Instance reuse

`ImageSpan` (Android) and `ENRMImageAttachment` (iOS) instances are reused across re-renders for the same URL, avoiding redundant object allocation and image reloading.
