import { useEffect, useRef, useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
  type PressableStateCallbackType,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import {
  EnrichedMarkdownTextInput,
  type EnrichedMarkdownTextInputInstance,
  type StyleState,
} from 'react-native-enriched-markdown';

const SAMPLE =
  '## Rebase\n\nfetch **now**, then *merge* the [branch](https://git-scm.com)\n\n- stack\n   - review\n\n1. fetch\n2. merge\n\n||spoiler|| and _underline_ and 🎉';

type Instance = EnrichedMarkdownTextInputInstance;
type IconName = React.ComponentProps<typeof MaterialIcons>['name'];
type WebPressableState = PressableStateCallbackType & {
  hovered?: boolean;
  focused?: boolean;
};

interface Button {
  key: string;
  title: string;
  icon?: IconName;
  label?: string;
  active: (s: StyleState | null) => boolean;
  run: (input: Instance) => void;
  disabled?: boolean;
}

const GROUPS: Button[][] = [
  [
    {
      key: 'bold',
      title: 'Bold',
      icon: 'format-bold',
      active: (s) => !!s?.bold.isActive,
      run: (i) => i.toggleBold(),
    },
    {
      key: 'italic',
      title: 'Italic',
      icon: 'format-italic',
      active: (s) => !!s?.italic.isActive,
      run: (i) => i.toggleItalic(),
    },
    {
      key: 'underline',
      title: 'Underline',
      icon: 'format-underlined',
      active: (s) => !!s?.underline.isActive,
      run: (i) => i.toggleUnderline(),
    },
    {
      key: 'strikethrough',
      title: 'Strikethrough',
      icon: 'strikethrough-s',
      active: (s) => !!s?.strikethrough.isActive,
      run: (i) => i.toggleStrikethrough(),
    },
    {
      key: 'spoiler',
      title: 'Spoiler',
      icon: 'visibility-off',
      active: (s) => !!s?.spoiler.isActive,
      run: (i) => i.toggleSpoiler(),
    },
  ],
  ([1, 2, 3, 4, 5, 6] as const).map((level) => ({
    key: `h${level}`,
    title: `Heading ${level}`,
    label: `H${level}`,
    active: (s: StyleState | null) =>
      !!s?.heading.isActive && s.heading.level === level,
    run: (i: Instance) => i.toggleHeading(level),
  })),
  [
    {
      key: 'bullet',
      title: 'Bulleted list',
      icon: 'format-list-bulleted',
      active: (s) => !!s?.unorderedList.isActive,
      run: (i) => i.toggleUnorderedList(),
    },
    {
      key: 'ordered',
      title: 'Numbered list',
      icon: 'format-list-numbered',
      active: (s) => !!s?.orderedList.isActive,
      run: (i) => i.toggleOrderedList(),
    },
    {
      key: 'outdent',
      title: 'Outdent',
      icon: 'format-indent-decrease',
      active: () => false,
      run: (i) => i.outdentList(),
    },
    {
      key: 'indent',
      title: 'Indent',
      icon: 'format-indent-increase',
      active: () => false,
      run: (i) => i.indentList(),
    },
  ],
  [
    // Links are not wired on web yet, so the control is shown but disabled.
    {
      key: 'link',
      title: 'Link (not available yet)',
      icon: 'add-link',
      active: (s) => !!s?.link.isActive,
      run: () => {},
      disabled: true,
    },
  ],
];

const COLORS = {
  icon: '#374151',
  iconOnActive: '#ffffff',
  iconDisabled: '#b6bcc6',
  active: '#2563eb',
  hover: '#eceef1',
  focusRing: '#93c5fd',
  border: '#e5e7eb',
  bar: '#f9fafb',
  sourceBackground: '#fbfbfd',
  sourceText: '#4b5563',
  label: '#9ca3af',
};

function ToolbarButton({
  button,
  active,
  onRun,
}: {
  button: Button;
  active: boolean;
  onRun: () => void;
}) {
  const color = button.disabled
    ? COLORS.iconDisabled
    : active
      ? COLORS.iconOnActive
      : COLORS.icon;
  return (
    <Pressable
      accessibilityLabel={button.title}
      aria-pressed={active}
      disabled={button.disabled}
      onPointerDown={(event) => event.preventDefault()}
      onPress={onRun}
      style={(state: WebPressableState) => [
        styles.button,
        active && styles.buttonActive,
        !active && !button.disabled && state.hovered && styles.buttonHovered,
        state.focused && styles.buttonFocused,
      ]}
    >
      {button.icon ? (
        <MaterialIcons name={button.icon} size={20} color={color} />
      ) : (
        <Text style={[styles.buttonLabel, { color }]}>{button.label}</Text>
      )}
    </Pressable>
  );
}

export function InputEditor() {
  const inputRef = useRef<Instance>(null);
  const [state, setState] = useState<StyleState | null>(null);
  const [markdown, setMarkdown] = useState(SAMPLE);
  const { height: windowHeight } = useWindowDimensions();

  useEffect(() => {
    inputRef.current?.setValue(SAMPLE);
  }, []);

  return (
    <View style={styles.wrap}>
      <View style={[styles.card, { minHeight: windowHeight - 110 }]}>
        <View style={styles.editorPane}>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            style={styles.toolbar}
            contentContainerStyle={styles.toolbarContent}
            accessibilityRole="toolbar"
          >
            {GROUPS.map((group, index) => (
              <View key={index} style={styles.group}>
                {index > 0 ? <View style={styles.separator} /> : null}
                {group.map((button) => (
                  <ToolbarButton
                    key={button.key}
                    button={button}
                    active={button.active(state)}
                    onRun={() => {
                      if (inputRef.current) button.run(inputRef.current);
                    }}
                  />
                ))}
              </View>
            ))}
          </ScrollView>

          <View style={styles.editorArea}>
            <EnrichedMarkdownTextInput
              ref={inputRef}
              placeholder="Write markdown…"
              style={editorStyle}
              onChangeState={setState}
              onChangeMarkdown={setMarkdown}
            />
          </View>
        </View>

        <View style={styles.sourcePane}>
          <View style={styles.sourceLabelBar}>
            <Text style={styles.sourceLabel}>MARKDOWN</Text>
          </View>
          <pre style={sourceStyle}>{markdown}</pre>
        </View>
      </View>
    </View>
  );
}

const BAR_HEIGHT = 46;

const styles = StyleSheet.create({
  wrap: { padding: 24 },
  card: {
    flexDirection: 'row',
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 12,
    overflow: 'hidden',
    backgroundColor: '#ffffff',
    boxShadow: '0 1px 3px rgba(0,0,0,0.06), 0 8px 24px rgba(0,0,0,0.04)',
  },
  editorPane: { flex: 1, minWidth: 0 },
  toolbar: {
    flexGrow: 0,
    height: BAR_HEIGHT,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
    backgroundColor: COLORS.bar,
  },
  toolbarContent: {
    alignItems: 'center',
    paddingHorizontal: 10,
    gap: 2,
  },
  group: { flexDirection: 'row', alignItems: 'center', gap: 2 },
  separator: {
    width: 1,
    height: 22,
    marginHorizontal: 4,
    backgroundColor: COLORS.border,
  },
  button: {
    minWidth: 30,
    height: 30,
    paddingHorizontal: 5,
    borderRadius: 7,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonActive: { backgroundColor: COLORS.active },
  buttonHovered: { backgroundColor: COLORS.hover },
  buttonFocused: { outlineWidth: 2, outlineColor: COLORS.focusRing },
  buttonLabel: { fontSize: 13, fontWeight: '700' },
  editorArea: { flex: 1, paddingVertical: 20, paddingHorizontal: 24 },
  sourcePane: {
    flex: 1,
    minWidth: 0,
    borderLeftWidth: 1,
    borderLeftColor: COLORS.border,
    backgroundColor: COLORS.sourceBackground,
  },
  sourceLabelBar: {
    height: BAR_HEIGHT,
    justifyContent: 'center',
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
    backgroundColor: COLORS.bar,
  },
  sourceLabel: {
    fontSize: 10,
    fontWeight: '700',
    letterSpacing: 1.2,
    color: COLORS.label,
  },
});

const editorStyle: React.CSSProperties = {
  fontSize: 16,
  lineHeight: 1.65,
  outline: 'none',
  minHeight: '100%',
};

const sourceStyle: React.CSSProperties = {
  flex: 1,
  margin: 0,
  padding: '18px 20px',
  fontFamily: 'ui-monospace, monospace',
  fontSize: 13,
  lineHeight: 1.65,
  color: COLORS.sourceText,
  whiteSpace: 'pre-wrap',
  overflowWrap: 'anywhere',
  overflow: 'auto',
};
