package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.styles.TaskListStyle

@Immutable
internal data class TaskListStylePatch(
  val checkedColor: Color? = null,
  val borderColor: Color? = null,
  val checkboxSize: Dp? = null,
  val checkboxCornerRadius: Dp? = null,
  val checkmarkColor: Color? = null,
  val checkedTextColor: Color? = null,
  val checkedStrikethrough: Boolean? = null,
) {
  fun apply(
    base: TaskListStyle,
    units: StyleUnits,
  ): TaskListStyle =
    base.copy(
      checkedColor = checkedColor?.let(units::color) ?: base.checkedColor,
      borderColor = borderColor?.let(units::color) ?: base.borderColor,
      checkboxSize = checkboxSize?.let(units::dp) ?: base.checkboxSize,
      checkboxBorderRadius = checkboxCornerRadius?.let(units::dp) ?: base.checkboxBorderRadius,
      checkmarkColor = checkmarkColor?.let(units::color) ?: base.checkmarkColor,
      checkedTextColor = checkedTextColor?.let(units::color) ?: base.checkedTextColor,
      checkedStrikethrough = checkedStrikethrough ?: base.checkedStrikethrough,
    )
}

@MarkdownStyleDsl
class TaskListStyleScope internal constructor() {
  var checkedColor: Color? = null
  var borderColor: Color? = null
  var checkboxSize: Dp? = null
  var checkboxCornerRadius: Dp? = null

  var checkmarkColor: Color? = null
  var checkedTextColor: Color? = null
  var checkedStrikethrough: Boolean? = null

  internal fun toPatch(): TaskListStylePatch =
    TaskListStylePatch(
      checkedColor = checkedColor,
      borderColor = borderColor,
      checkboxSize = checkboxSize,
      checkboxCornerRadius = checkboxCornerRadius,
      checkmarkColor = checkmarkColor,
      checkedTextColor = checkedTextColor,
      checkedStrikethrough = checkedStrikethrough,
    )

  internal companion object {
    fun merge(
      existing: TaskListStylePatch?,
      block: TaskListStyleScope.() -> Unit,
    ): TaskListStylePatch {
      val scope =
        TaskListStyleScope().apply {
          if (existing != null) {
            checkedColor = existing.checkedColor
            borderColor = existing.borderColor
            checkboxSize = existing.checkboxSize
            checkboxCornerRadius = existing.checkboxCornerRadius
            checkmarkColor = existing.checkmarkColor
            checkedTextColor = existing.checkedTextColor
            checkedStrikethrough = existing.checkedStrikethrough
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
