import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { customMarkdownStyle } from '../../markdownStyles';

const STREAM_SOURCE = `Here is a longer streamed answer used to stress GitHub-flavored markdown streaming on iOS.

The goal is to keep normal text flowing while completed tables and block LaTeX views stay stable. Each section below adds enough text between block views to make layout changes easier to notice during streaming.

First summary table:

| Area | Why it matters | Expected behavior |
| --- | --- | --- |
| Text | Keeps streaming frequently | Tail text fades in |
| Table | Expensive native block | Existing table is reused |
| Math | Expensive native block | Existing formula is reused |

After the first table, the answer continues with regular prose. This paragraph should stream normally and should not cause the completed table above to be recreated. It gives the preview enough height to make jumps and delayed measurements visible.

First LaTeX block:

$$
E = mc^2
$$

The first equation is intentionally short. The following text continues immediately after it so we can verify that the math block appears once, then remains stable while more text is appended below.

Second progress table:

| Step | Status | Notes |
| --- | --- | --- |
| Parse markdown | done | AST is ready |
| Split segments | done | Text, table, and math are separated |
| Reconcile views | active | Unchanged blocks should be reused |
| Measure height | active | Height should update only when needed |

The stream now adds a longer paragraph to simulate a real assistant response. The important thing is that appending this text should not force the previous table or formula to flash, fade again, or rebuild their native views.

Second LaTeX block:

$$
a^2 + b^2 = c^2
$$

More explanatory text follows the second formula. This gives us another opportunity to check that previously completed blocks remain visually stable while the tail of the message continues to animate.

Comparison table:

| Scenario | Static GFM | Streaming GFM |
| --- | --- | --- |
| Complete table | Renders immediately | Renders when complete |
| Incomplete table | Renders as parser allows | Hidden until complete |
| Complete math block | Renders immediately | Renders when complete |
| Incomplete math block | Renders as parser allows | Hidden until closing delimiter |

This paragraph is intentionally a little longer. It should make the preview scrollable and help us see whether the UI thread stays smooth when several completed block views already exist above the streaming tail.

Third LaTeX block:

$$
F(x) = \\int_0^x t^2\\,dt = \\frac{x^3}{3}
$$

Final validation table:

| Check | Result |
| --- | --- |
| Text keeps streaming | expected |
| Completed tables stay visible | expected |
| Completed math stays visible | expected |
| Incomplete block is hidden | expected |
| Height grows only for rendered content | expected |

The streamed answer is complete. At this point all tables and block LaTeX sections should be visible, and none of the earlier blocks should have been recreated unnecessarily while the final text was appended.`;

const TICK_MS = 80;
const CHARS_PER_TICK = 6;

export default function StreamingMarkdownSimulator() {
  const [cursor, setCursor] = useState(0);
  const [isStreaming, setIsStreaming] = useState(false);
  const markdownStyle = useMemo(() => customMarkdownStyle, []);

  const markdown = STREAM_SOURCE.slice(0, cursor);
  const isComplete = cursor >= STREAM_SOURCE.length;

  const step = useCallback(() => {
    setCursor((current) =>
      Math.min(current + CHARS_PER_TICK, STREAM_SOURCE.length)
    );
  }, []);

  const reset = useCallback(() => {
    setIsStreaming(false);
    setCursor(0);
  }, []);

  useEffect(() => {
    if (!isStreaming || isComplete) {
      if (isComplete) {
        setIsStreaming(false);
      }
      return;
    }

    const interval = setInterval(step, TICK_MS);
    return () => clearInterval(interval);
  }, [isStreaming, isComplete, step]);

  return (
    <ScrollView
      style={styles.root}
      contentContainerStyle={styles.content}
      testID="stream-screen"
    >
      <Text style={styles.title}>Streaming markdown simulator</Text>
      <Text style={styles.subtitle}>
        JS-only stream: longer text, several tables, and several block LaTeX
        segments.
      </Text>

      <View style={styles.controls}>
        <ControlButton
          label={isStreaming ? 'Pause' : isComplete ? 'Replay' : 'Start'}
          onPress={() => {
            if (isComplete) {
              setCursor(0);
              setIsStreaming(true);
              return;
            }
            setIsStreaming((value) => !value);
          }}
        />
        <ControlButton label="Step" onPress={step} disabled={isComplete} />
        <ControlButton label="Reset" onPress={reset} />
      </View>

      <Text style={styles.progress}>
        {cursor}/{STREAM_SOURCE.length} characters
      </Text>

      <View style={styles.preview}>
        <EnrichedMarkdownText
          flavor="github"
          markdown={markdown}
          markdownStyle={markdownStyle}
          md4cFlags={{ latexMath: true }}
          streaming={!isComplete}
          streamingConfig={{
            tableMode: 'progressive',
          }}
        />
      </View>

      <Text style={styles.rawLabel}>Raw streamed markdown</Text>
      <Text style={styles.raw}>{markdown || 'Waiting to stream...'}</Text>
    </ScrollView>
  );
}

function ControlButton({
  label,
  onPress,
  disabled = false,
}: {
  label: string;
  onPress: () => void;
  disabled?: boolean;
}) {
  return (
    <TouchableOpacity
      style={[styles.button, disabled && styles.buttonDisabled]}
      onPress={onPress}
      disabled={disabled}
    >
      <Text style={styles.buttonText}>{label}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
  content: {
    padding: 16,
    gap: 12,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    color: '#111827',
  },
  subtitle: {
    fontSize: 14,
    color: '#6B7280',
  },
  controls: {
    flexDirection: 'row',
    gap: 8,
  },
  button: {
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 8,
    backgroundColor: '#2563EB',
  },
  buttonDisabled: {
    backgroundColor: '#9CA3AF',
  },
  buttonText: {
    color: '#FFFFFF',
    fontWeight: '600',
  },
  progress: {
    color: '#6B7280',
    fontSize: 12,
  },
  preview: {
    padding: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#D1D5DB',
    borderRadius: 12,
    backgroundColor: '#FFFFFF',
  },
  rawLabel: {
    marginTop: 8,
    color: '#374151',
    fontWeight: '600',
  },
  raw: {
    padding: 12,
    borderRadius: 8,
    backgroundColor: '#F3F4F6',
    color: '#111827',
    fontFamily: 'Menlo',
    fontSize: 12,
  },
});
