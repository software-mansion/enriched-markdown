package com.swmansion.enriched.markdown

import android.content.Context
import android.os.Build
import android.text.Layout
import android.util.AttributeSet
import android.view.MotionEvent
import com.swmansion.enriched.markdown.accessibility.AccessibleMarkdownTextView
import com.swmansion.enriched.markdown.segments.BlockSegmentView
import com.swmansion.enriched.markdown.utils.text.interaction.CheckboxTouchHelper
import com.swmansion.enriched.markdown.utils.text.interaction.TaskListHitTestResult
import com.swmansion.enriched.markdown.utils.text.view.LinkLongPressMovementMethod
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import com.swmansion.enriched.markdown.utils.text.view.applySelectableState
import com.swmansion.enriched.markdown.utils.text.view.createSelectionActionModeCallback
import com.swmansion.enriched.markdown.utils.text.view.setupAsMarkdownTextView

class EnrichedMarkdownInternalText
  @JvmOverloads
  constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
  ) : AccessibleMarkdownTextView(context, attrs, defStyleAttr),
    BlockSegmentView {
    var lastElementMarginBottom: Float = 0f
    override val segmentMarginBottom: Int get() = lastElementMarginBottom.toInt()

    var selectionMenuConfig: SelectionMenuConfig = SelectionMenuConfig()

    var onLinkPressCallback: ((String) -> Unit)? = null
    var onLinkLongPressCallback: ((String) -> Unit)? = null

    private val checkboxTouchHelper = CheckboxTouchHelper(this)

    var onTaskListItemTapCallback: ((TaskListHitTestResult) -> Unit)?
      get() = checkboxTouchHelper.onCheckboxTap
      set(value) {
        checkboxTouchHelper.onCheckboxTap = value
      }

    var enableTaskListItemToggle: Boolean
      get() = checkboxTouchHelper.isEnabled
      set(value) {
        checkboxTouchHelper.isEnabled = value
      }

    init {
      setupAsMarkdownTextView()
      customSelectionActionModeCallback =
        createSelectionActionModeCallback(
          this,
          getSelectionMenuConfig = { selectionMenuConfig },
        )
    }

    fun applyStyledText(styledText: CharSequence) {
      text = styledText

      if (movementMethod !is LinkLongPressMovementMethod) {
        movementMethod = LinkLongPressMovementMethod.createInstance()
      }

      accessibilityHelper.invalidateAccessibilityItems()
    }

    fun setIsSelectable(selectable: Boolean) {
      applySelectableState(selectable)
    }

    fun setJustificationMode(needsJustify: Boolean) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        justificationMode =
          if (needsJustify) {
            Layout.JUSTIFICATION_MODE_INTER_WORD
          } else {
            Layout.JUSTIFICATION_MODE_NONE
          }
      }
    }

    fun emitOnLinkPress(url: String) {
      onLinkPressCallback?.invoke(url)
    }

    fun emitOnLinkLongPress(url: String) {
      onLinkLongPressCallback?.invoke(url)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
      if (checkboxTouchHelper.onTouchEvent(event)) return true
      return super.onTouchEvent(event)
    }
  }
