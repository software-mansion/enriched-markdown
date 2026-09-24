package com.swmansion.enriched.markdown.benchmark

import android.graphics.Color
import android.os.Bundle
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity

/** Hosts the document under test in [container], which fills the window: the first screen. */
class DisplayActivity : AppCompatActivity() {
  lateinit var container: FrameLayout
    private set

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    container = FrameLayout(this).apply { setBackgroundColor(Color.WHITE) }
    setContentView(container)
  }
}
