import { useCallback, useState } from 'react';
import { Linking, ScrollView, StyleSheet, View, Text } from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import type {
  LinkPressEvent,
  LinkLongPressEvent,
  ImagePressEvent,
  TaskListItemPressEvent,
} from 'react-native-enriched-markdown';
import { sampleMarkdown } from './sampleMarkdown';

const latexMarkdown = `
## Inline Math

The **quadratic formula** solves $ax^2 + bx + c = 0$, giving $x = \\dfrac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$.

Euler's identity $e^{i\\pi} + 1 = 0$ is often called the most beautiful equation in mathematics.

Einstein's mass-energy equivalence: $E = mc^2$.

## Display Math

The Gaussian integral:

$$\\int_{-\\infty}^{\\infty} e^{-x^2} \\, dx = \\sqrt{\\pi}$$

Newton's second law in differential form:

$$F = m\\frac{d^2x}{dt^2}$$

The Schrödinger equation:

$$i\\hbar\\frac{\\partial}{\\partial t}\\Psi(\\mathbf{r},t) = \\left[-\\frac{\\hbar^2}{2m}\\nabla^2 + V(\\mathbf{r},t)\\right]\\Psi(\\mathbf{r},t)$$

Bayes' theorem:

$$P(A \\mid B) = \\frac{P(B \\mid A) \\, P(A)}{P(B)}$$
`.trim();

const rtlMarkdown = `
# مرحباً بالعالم

هذا مثال على **النص العربي** في اتجاه RTL مع دعم كامل لتنسيق Markdown. يمكنك أيضاً استخدام *تنسيق مائل* و~~نص مشطوب~~.

---

## الاقتباسات

> اقتباس: يجب أن يظهر الحد العمودي على **الجانب الأيمن** في وضع RTL.
>
> هذا السلوك مدعوم تلقائياً عبر خاصية CSS المنطقية \`border-inline-start\`.

## قوائم المهام

- [x] تصميم واجهة المستخدم
- [x] تطوير الواجهة الخلفية
- [ ] كتابة الاختبارات
- [ ] نشر التطبيق

## قائمة مرتبة

1. الخطوة الأولى: تثبيت المكتبة
2. الخطوة الثانية: إضافة المكوّن
3. الخطوة الثالثة: تخصيص الأنماط

## قائمة متداخلة

- العنصر الأول
  - عنصر متداخل
  - عنصر متداخل آخر
- العنصر الثاني
  - قائمة متداخلة ثانية

## الروابط والصور

تفضل بزيارة [موقع المكتبة](https://github.com) لمزيد من المعلومات.

## الجداول

| الاسم    | الدور       | الحالة  |
| -------- | ----------- | ------- |
| أحمد     | مطوّر       | نشط     |
| فاطمة    | مصمّمة      | نشط     |
| محمد     | مدير مشروع  | غائب    |

## الكود

استخدم الدالة \`console.log()\` لطباعة الرسائل.

\`\`\`javascript
function greet(name) {
  return \`مرحباً، \${name}!\`;
}

console.log(greet("العالم"));
\`\`\`
`.trim();

interface EventLog {
  kind: 'link' | 'linkLong' | 'image' | 'task';
  label: string;
  detail: string;
}

const KIND_COLOR: Record<EventLog['kind'], string> = {
  link: '#2563EB',
  linkLong: '#7C3AED',
  image: '#DB2777',
  task: '#059669',
};

export default function App() {
  const [lastEvent, setLastEvent] = useState<EventLog | null>(null);

  const onLinkPress = useCallback(({ url }: LinkPressEvent) => {
    setLastEvent({ kind: 'link', label: 'onLinkPress', detail: url });
    Linking.openURL(url);
  }, []);

  const onLinkLongPress = useCallback(({ url }: LinkLongPressEvent) => {
    setLastEvent({ kind: 'linkLong', label: 'onLinkLongPress', detail: url });
  }, []);

  const onImagePress = useCallback(({ url, altText }: ImagePressEvent) => {
    setLastEvent({
      kind: 'image',
      label: 'onImagePress',
      detail: `${altText || 'Image'} — ${url}`,
    });
  }, []);

  const onTaskListItemPress = useCallback(
    ({ index, checked, text }: TaskListItemPressEvent) => {
      setLastEvent({
        kind: 'task',
        label: 'onTaskListItemPress',
        detail: `index=${index} checked=${checked} "${text.slice(0, 40)}${text.length > 40 ? '…' : ''}"`,
      });
    },
    []
  );

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerText}>
          react-native-enriched-markdown — web example
        </Text>
      </View>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
      >
        <SectionLabel>LaTeX</SectionLabel>
        <EnrichedMarkdownText markdown={latexMarkdown} />

        <View style={styles.divider} />

        <SectionLabel>LTR</SectionLabel>
        <EnrichedMarkdownText
          markdown={sampleMarkdown}
          onLinkPress={onLinkPress}
          onLinkLongPress={onLinkLongPress}
          onImagePress={onImagePress}
          onTaskListItemPress={onTaskListItemPress}
          selectionColor="#DCDDFE"
          md4cFlags={{
            superscript: true,
            subscript: true,
          }}
        />

        <View style={styles.divider} />

        <SectionLabel>RTL</SectionLabel>
        <EnrichedMarkdownText
          markdown={rtlMarkdown}
          dir="rtl"
          onTaskListItemPress={onTaskListItemPress}
        />
      </ScrollView>

      {lastEvent && (
        <View style={styles.eventBar}>
          <View
            style={[
              styles.kindBadge,
              { backgroundColor: KIND_COLOR[lastEvent.kind] },
            ]}
          >
            <Text style={styles.kindText}>{lastEvent.label}</Text>
          </View>
          <Text style={styles.detailText} numberOfLines={1}>
            {lastEvent.detail}
          </Text>
          <Text style={styles.dismissText} onPress={() => setLastEvent(null)}>
            ✕
          </Text>
        </View>
      )}
    </View>
  );
}

function SectionLabel({ children }: { children: string }) {
  return (
    <View style={styles.sectionLabel}>
      <Text style={styles.sectionLabelText}>{children}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  header: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E7EB',
    backgroundColor: '#F9FAFB',
  },
  headerText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#374151',
    fontFamily: 'monospace',
  },
  scroll: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: 24,
    paddingVertical: 16,
  },
  divider: {
    height: 1,
    backgroundColor: '#E5E7EB',
    marginVertical: 24,
  },
  sectionLabel: {
    marginBottom: 12,
  },
  sectionLabelText: {
    fontSize: 11,
    fontWeight: '600',
    color: '#9CA3AF',
    fontFamily: 'monospace',
    letterSpacing: 1,
  },
  eventBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderTopWidth: 1,
    borderTopColor: '#E5E7EB',
    backgroundColor: '#F9FAFB',
  },
  kindBadge: {
    borderRadius: 4,
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  kindText: {
    fontSize: 11,
    fontWeight: '600',
    color: '#ffffff',
    fontFamily: 'monospace',
  },
  detailText: {
    flex: 1,
    fontSize: 12,
    color: '#374151',
    fontFamily: 'monospace',
  },
  dismissText: {
    fontSize: 14,
    color: '#9CA3AF',
    paddingLeft: 4,
  },
});
