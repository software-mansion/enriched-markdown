package com.swmansion.enriched.markdown.styles

/**
 * The request an image occurrence makes instead of its Markdown URL
 * (`resolveImageSource`). An empty [uri] keeps the placeholder and requests
 * nothing. [headers] are lowercased and win over the document's request headers.
 */
data class ImageSourceOverride(
  val uri: String,
  val headers: Map<String, String>,
)
