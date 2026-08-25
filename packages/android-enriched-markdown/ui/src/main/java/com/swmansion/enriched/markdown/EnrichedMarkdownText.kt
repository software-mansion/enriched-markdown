package com.swmansion.enriched.markdown

import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.Layout
import android.util.AttributeSet
import android.util.Log
import android.view.MotionEvent
import com.swmansion.enriched.markdown.accessibility.AccessibleMarkdownTextView
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.parser.Parser
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.view.LinkLongPressMovementMethod
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import com.swmansion.enriched.markdown.utils.text.view.applySelectableState
import com.swmansion.enriched.markdown.utils.text.view.applySelectionColors
import com.swmansion.enriched.markdown.utils.text.view.createSelectionActionModeCallback
import com.swmansion.enriched.markdown.utils.text.view.setupAsMarkdownTextView

class EnrichedMarkdownText
  @JvmOverloads
  constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
  ) : AccessibleMarkdownTextView(context, attrs, defStyleAttr) {
    private val parser = Parser.shared
    private val renderer = Renderer()
    private var onLinkPressCallback: ((String) -> Unit)? = null
    private var onLinkLongPressCallback: ((String) -> Unit)? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var currentRenderId = 0L

    var markdownStyle: StyleConfig = StyleConfig.default(context)
      private set

    var currentMarkdown: String = ""
      private set

    var md4cFlags: Md4cFlags = Md4cFlags.DEFAULT
      private set

    private var pendingStyledText: CharSequence? = null
    private var imageRequestHeaders: Map<String, String> = emptyMap()
    private var selectionColor: Int? = null
    private var selectionHandleColor: Int? = null
    private var isSelectable = true
    private var selectionMenuConfig = SelectionMenuConfig()

    init {
      setupAsMarkdownTextView()
      customSelectionActionModeCallback =
        createSelectionActionModeCallback(
          this,
          getSelectionMenuConfig = { selectionMenuConfig },
        )
    }

    fun setMarkdownContent(markdown: String) {
      if (currentMarkdown == markdown) return
      currentMarkdown = markdown
      scheduleRender()
    }

    fun setMarkdown(content: String) = setMarkdownContent(content)

    fun setMarkdownStyle(style: StyleConfig) {
      if (markdownStyle == style) return
      markdownStyle = style
      updateJustificationMode(style)
      scheduleRenderIfNeeded()
    }

    /**
     * Sets HTTP headers attached to remote image requests, e.g. a `Referer`
     * required by CDN hotlink protection or an `Authorization` token.
     * Headers participate in image cache identity, so the same URL requested
     * with different headers is fetched and cached separately.
     */
    fun setImageRequestHeaders(headers: Map<String, String>) {
      if (imageRequestHeaders == headers) return
      imageRequestHeaders = headers
      scheduleRenderIfNeeded()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
      super.onConfigurationChanged(newConfig)
      updateJustificationMode(markdownStyle)
      scheduleRenderIfNeeded()
    }

    fun setMd4cFlags(flags: Md4cFlags) {
      if (md4cFlags == flags) return
      md4cFlags = flags
      scheduleRenderIfNeeded()
    }

    fun setOnLinkPressCallback(callback: ((String) -> Unit)?) {
      onLinkPressCallback = callback
    }

    fun setOnLinkLongPressCallback(callback: ((String) -> Unit)?) {
      onLinkLongPressCallback = callback
    }

    fun setIsSelectable(selectable: Boolean) {
      if (isSelectable == selectable) return
      isSelectable = selectable
      applySelectableState(selectable)
    }

    fun setSelectable(selectable: Boolean) = setIsSelectable(selectable)

    fun setOnLinkPressListener(listener: ((String) -> Unit)?) = setOnLinkPressCallback(listener)

    fun setOnLinkLongPressListener(listener: ((String) -> Unit)?) = setOnLinkLongPressCallback(listener)

    /**
     * Resets transient state when this view is recycled in a Compose [AndroidView] pool.
     */
    fun prepareForViewReuse() {
      ++currentRenderId
      setOnLinkPressCallback(null)
      setOnLinkLongPressCallback(null)
      setMarkdownContent("")
      text = ""
      pendingStyledText = null
    }

    fun setSelectionColor(color: Int?) {
      if (selectionColor == color) return
      selectionColor = color
      applySelectionColors(selectionColor, selectionHandleColor)
    }

    fun setSelectionHandleColor(color: Int?) {
      if (selectionHandleColor == color) return
      selectionHandleColor = color
      applySelectionColors(selectionColor, selectionHandleColor)
    }

    fun setSelectionMenuConfig(config: SelectionMenuConfig) {
      if (selectionMenuConfig == config) return
      selectionMenuConfig = config
    }

    fun emitOnLinkPress(url: String) {
      onLinkPressCallback?.invoke(url)
    }

    fun emitOnLinkLongPress(url: String) {
      onLinkLongPressCallback?.invoke(url)
    }

    private fun scheduleRenderIfNeeded() {
      if (currentMarkdown.isNotEmpty()) {
        scheduleRender()
      }
    }

    private fun updateJustificationMode(style: StyleConfig) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        justificationMode =
          if (style.needsJustify) {
            Layout.JUSTIFICATION_MODE_INTER_WORD
          } else {
            Layout.JUSTIFICATION_MODE_NONE
          }
      }
    }

    private fun scheduleRender() {
      val style = markdownStyle
      val markdown = currentMarkdown
      if (markdown.isEmpty()) return

      val renderId = ++currentRenderId

      MarkdownRenderDispatcher.submit(
        owner = this,
        priority = if (isAttachedToWindow) 1 else 0,
        isCancelled = { renderId != currentRenderId },
      ) {
        if (renderId != currentRenderId) return@submit

        try {
          val ast =
            parser.parseMarkdown(markdown, md4cFlags) ?: run {
              mainHandler.post { if (renderId == currentRenderId && isAttachedToWindow) text = "" }
              return@submit
            }

          if (renderId != currentRenderId) return@submit

          renderer.configure(style, context, imageRequestHeaders)
          val styledText =
            renderer.renderDocument(
              ast,
              onLinkPressCallback,
              onLinkLongPressCallback,
            )

          if (renderId != currentRenderId) return@submit

          mainHandler.post {
            if (renderId == currentRenderId) {
              if (isAttachedToWindow) {
                applyRenderedText(styledText)
              } else {
                pendingStyledText = styledText
              }
            }
          }
        } catch (e: Exception) {
          Log.e(TAG, "Render failed: ${e.message}", e)
          mainHandler.post { if (renderId == currentRenderId && isAttachedToWindow) text = "" }
        }
      }
    }

    private fun applyRenderedText(styledText: CharSequence) {
      text = styledText

      if (movementMethod !is LinkLongPressMovementMethod) {
        movementMethod = LinkLongPressMovementMethod.createInstance()
      }

      renderer.getCollectedImageSpans().forEach { span ->
        span.registerTextView(this)
      }

      accessibilityHelper.invalidateAccessibilityItems()
      applySelectionColors(selectionColor, selectionHandleColor)
    }

    override fun onAttachedToWindow() {
      super.onAttachedToWindow()
      pendingStyledText?.let {
        pendingStyledText = null
        applyRenderedText(it)
      }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean = super.onTouchEvent(event)

    companion object {
      private const val TAG = "EnrichedMarkdownText"
    }
  }
