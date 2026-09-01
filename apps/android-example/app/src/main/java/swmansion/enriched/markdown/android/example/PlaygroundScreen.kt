package swmansion.enriched.markdown.android.example

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.parser.Md4cFlags
import java.io.File

private fun assetImageUri(
  context: Context,
  assetName: String,
): String {
  val dest = File(context.cacheDir, assetName)
  if (!dest.exists()) {
    context.assets.open(assetName).use { input ->
      dest.outputStream().use { output -> input.copyTo(output) }
    }
  }
  return "file://${dest.absolutePath}"
}

@Composable
fun PlaygroundScreen(modifier: Modifier = Modifier) {
  val context = androidx.compose.ui.platform.LocalContext.current
  var markdown by remember { mutableStateOf("") }
  var underlineEnabled by remember { mutableStateOf(true) }
  var setMarkdownModalVisible by remember { mutableStateOf(false) }
  var rawInput by remember { mutableStateOf("") }
  var blockImageUri by remember { mutableStateOf<String?>(null) }
  var inlineImageUri by remember { mutableStateOf<String?>(null) }

  LaunchedEffect(Unit) {
    blockImageUri = assetImageUri(context, "logo.png")
    inlineImageUri = assetImageUri(context, "logo_icon.png")
  }

  Column(
    modifier =
      modifier
        .fillMaxSize()
        .semantics { testTagsAsResourceId = true }
        .background(Color(0xFFF9FAFB))
        .verticalScroll(rememberScrollState())
        .padding(16.dp)
        .testTag("playground-screen"),
    verticalArrangement = Arrangement.spacedBy(12.dp),
  ) {
    Row(
      modifier = Modifier.fillMaxWidth(),
      horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
      PlaygroundButton(
        label = "Blur",
        onClick = { /* no-op for Maestro parity */ },
        testTag = "blur-button",
      )
      PlaygroundButton(
        label = "Underline",
        onClick = { underlineEnabled = !underlineEnabled },
        testTag = "underline-button",
        isActive = underlineEnabled,
      )
    }

    Row(
      modifier = Modifier.fillMaxWidth(),
      horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
      PlaygroundButton(
        label = "Insert Image",
        onClick = {
          blockImageUri?.let { uri ->
            val imageMarkdown = "![logo]($uri)"
            markdown =
              if (markdown.isNotBlank()) {
                "$markdown\n\n$imageMarkdown"
              } else {
                imageMarkdown
              }
          }
        },
        testTag = "insert-image-button",
      )
      PlaygroundButton(
        label = "Insert Inline Image",
        onClick = {
          inlineImageUri?.let { uri ->
            markdown =
              "Enriched Markdown is a library for ![icon]($uri) React Native."
          }
        },
        testTag = "insert-inline-image-button",
      )
    }

    Button(
      onClick = {
        rawInput = ""
        setMarkdownModalVisible = true
      },
      modifier = Modifier.fillMaxWidth().testTag("set-markdown-button"),
      colors =
        ButtonDefaults.buttonColors(
          containerColor = Color(0xFFBEEBD0),
          contentColor = Color(0xFF001A72),
        ),
      shape = RoundedCornerShape(8.dp),
    ) {
      Text(
        text = "Set Raw Markdown",
        fontWeight = FontWeight.SemiBold,
        fontSize = 14.sp,
      )
    }

    Text(
      text = "Preview",
      fontSize = 12.sp,
      fontWeight = FontWeight.SemiBold,
      color = Color(0xFF9CA3AF),
    )

    Surface(
      modifier =
        Modifier
          .fillMaxWidth()
          .border(1.dp, Color(0xFFD1D5DB), RoundedCornerShape(10.dp))
          .testTag("preview-container"),
      shape = RoundedCornerShape(10.dp),
      color = Color.White,
    ) {
      if (markdown.isEmpty()) {
        Text(
          text = "Preview will appear here",
          modifier =
            Modifier
              .padding(14.dp)
              .testTag("preview-empty"),
          color = Color(0xFF9CA3AF),
          fontStyle = androidx.compose.ui.text.font.FontStyle.Italic,
        )
      } else {
        EnrichedMarkdownText(
          markdown = markdown,
          modifier =
            Modifier
              .fillMaxWidth()
              .padding(14.dp)
              .testTag("preview-text"),
          style = PlaygroundMarkdownStyle,
          flags = Md4cFlags(underline = underlineEnabled),
        )
      }
    }
  }

  if (setMarkdownModalVisible) {
    Dialog(onDismissRequest = { setMarkdownModalVisible = false }) {
      Surface(
        shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp),
        color = Color.White,
      ) {
        Column(
          modifier =
            Modifier
              .semantics { testTagsAsResourceId = true }
              .padding(16.dp),
          verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
          Text(
            text = "Set Raw Markdown",
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
          )
          OutlinedTextField(
            value = rawInput,
            onValueChange = { rawInput = it },
            modifier =
              Modifier
                .fillMaxWidth()
                .testTag("set-markdown-input"),
            placeholder = { Text("Paste or type markdown...") },
            minLines = 4,
          )
          Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
          ) {
            TextButton(
              onClick = { setMarkdownModalVisible = false },
              modifier = Modifier.testTag("set-markdown-cancel"),
            ) {
              Text("Cancel")
            }
            Button(
              onClick = {
                markdown = rawInput
                setMarkdownModalVisible = false
              },
              modifier = Modifier.testTag("set-markdown-confirm"),
              colors =
                ButtonDefaults.buttonColors(
                  containerColor = Color(0xFFBEEBD0),
                  contentColor = Color(0xFF001A72),
                ),
            ) {
              Text("Set")
            }
          }
        }
      }
    }
  }
}

@Composable
private fun RowScope.PlaygroundButton(
  label: String,
  onClick: () -> Unit,
  testTag: String,
  isActive: Boolean = false,
) {
  Button(
    onClick = onClick,
    modifier = Modifier.weight(1f).testTag(testTag),
    colors =
      if (isActive) {
        ButtonDefaults.buttonColors(
          containerColor = Color(0xFFBEEBD0),
          contentColor = Color(0xFF001A72),
        )
      } else {
        ButtonDefaults.buttonColors(
          containerColor = Color(0xFFE5E7EB),
          contentColor = Color(0xFF374151),
        )
      },
    shape = RoundedCornerShape(8.dp),
  ) {
    Text(
      text = label,
      fontWeight = FontWeight.SemiBold,
      fontSize = 13.sp,
    )
  }
}
