# Image Caching

Images in Markdown content are loaded, cached, and reused automatically — no configuration required.

## Supported Image Sources

Markdown image URLs are strings, so bundled assets must be resolved to a URI before being interpolated into the markdown:

```tsx
import { Image } from 'react-native';

const logoUri = Image.resolveAssetSource(require('./assets/logo.png')).uri;
const markdown = `![Logo](${logoUri})`;
```

This works in every environment: in dev the URI is a Metro dev-server URL, while in a release build it resolves to a drawable resource name on Android and a bundle `file://` URL on iOS — all of which are supported. URIs from `expo-asset` (`asset.uri` / `asset.localUri`) work the same way.

| Source | Android | iOS / macOS |
|---|---|---|
| `http://`, `https://` | Yes | Yes |
| `file://` (including percent-encoded paths) | Yes | Yes |
| Bare asset name (release builds, expo-asset `localUri`) | Yes (drawable/raw resource) | Yes (bundle resource) |
| `file:///android_res/…`, `file:///android_asset/…` | Yes | No |
| `asset://`, `res://`, `content://` | Yes | No |
| `data:` (base64) | Yes | Yes |

Local sources skip the HTTP layers below (disk cache, request headers, deduplication) but still use both memory cache tiers.

## Cache Layers

The library uses a three-tier caching strategy on both platforms:

| Layer | Android | iOS | Size |
|---|---|---|---|
| **Originals (memory)** | `LruCache` | `NSCache` | 20 MB |
| **Processed variants (memory)** | `LruCache` | `NSCache` | 30 MB |
| **Disk** | OkHttp `Cache` | `NSURLCache` | 100 MB |

- **Original cache** stores decoded images keyed by URL. On Android, large images are downsampled to screen width during decode to reduce peak memory.
- **Processed cache** stores scaled and clipped variants keyed by URL + dimensions + border radius, so repeated layouts with the same geometry skip all image processing.
- **Animated GIFs** keep their encoded bytes plus one decoded poster frame, and further frames are decoded lazily while playing. They live in their own 20 MB memory tier on both platforms (cost = bytes + poster), separate from still originals, so an eviction never leaves a poster without its animation and a few large GIFs don't flush every still image. Only the poster is written to the processed cache; animation frames are held per attachment while playing (up to 8 MB on iOS) and released when playback pauses.
- **Disk cache** persists raw HTTP responses across app launches, respecting standard HTTP cache headers.

## Request Headers

When `imageRequestHeaders` is set, the headers become part of the cache identity for both memory tiers and for request deduplication: the same URL requested with different headers is fetched and cached separately, and changing the prop re-fetches the images.

One caveat: the disk cache is managed by the HTTP stack (OkHttp / `NSURLCache`) and keys responses by URL alone. A response fetched with one set of headers can be served from disk for a request with different headers, subject to standard HTTP caching semantics (`Cache-Control`, `Vary`).

## Request Deduplication

When multiple components request the same image URL simultaneously (e.g. during a re-render), only one network request is made. All pending callbacks are coalesced and dispatched together once the download completes.

## Instance Reuse

`ImageSpan` (Android) and `ENRMImageAttachment` (iOS) instances are reused across re-renders for the same URL, avoiding redundant object allocation and image reloading.
