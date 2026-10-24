import React from 'react';
import { EnrichedMarkdownTextStory } from '../EnrichedMarkdownTextStory';
import { storyMeta } from '../shared/storyMeta';
import type { TextStory } from '../shared/storyTypes';

type WritingDirection =
  | 'auto'
  | 'ltr'
  | 'rtl'
  | 'first-strong'
  | 'word-majority';

type WritingDirectionStoryExtra = {
  writingDirection: WritingDirection;
};

const MARKDOWN = `# عنوان عربي

هذه فقرة عربية تتبع اتجاه اليمين إلى اليسار تلقائيًا حسب أول حرف قوي فيها.

This English paragraph stays left-to-right in the same document.

- عنصر عربي في القائمة
- English list item

> اقتباس عربي لاختبار موضع الحد الجانبي للاقتباس.

123 456 789.`;

const WRITING_DIRECTION_OPTIONS: WritingDirection[] = [
  'first-strong',
  'auto',
  'ltr',
  'rtl',
  'word-majority',
];

const argTypes = {
  writingDirection: {
    options: WRITING_DIRECTION_OPTIONS,
    control: { type: 'inline-radio' as const },
    description:
      "'first-strong' (default): resolve per paragraph from its first strong directional character; neutral-only paragraphs fall back to the view's layout direction. 'auto': React Native parity, follows the app's UI layout direction. 'ltr'/'rtl': force base direction on every paragraph. 'word-majority': each block follows most of its words (iOS and Android). Code blocks always stay LTR.",
  },
};

export default storyMeta('Props', 'Writing Direction');

export const Default: TextStory<WritingDirectionStoryExtra> = {
  args: {
    markdown: MARKDOWN,
    writingDirection: 'first-strong',
    flavor: 'github',
  },
  argTypes,
  render: ({ writingDirection, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Writing Direction"
      description="iOS only. Compare 'first-strong' (per-paragraph autodetection, matches Android) against 'auto' (RN parity — follows the app's UI direction), and the forced 'ltr'/'rtl' modes. Mixed Arabic/English content makes the difference visible at a glance."
      {...args}
      writingDirection={writingDirection}
    />
  ),
};

// English-led Arabic blocks: 'first-strong' turns them LTR from the first word,
// 'word-majority' keeps them RTL.
const MIXED_MARKDOWN = `## StrictMode: يعيد العرض مرتين في التطوير

React: يستدعي \`useEffect\` مرتين، والدالة \`fetch()\` تعمل كما هي.

- API: واجهة برمجة التطبيقات
- Hook: دالة خاصة في React

> Note: هذا اقتباس عربي يبدأ بكلمة إنجليزية.

| Hook | الوصف |
| --- | --- |
| useState | يحفظ حالة المكوّن |
| useMemo | يتذكر نتيجة الحساب |

The translation is "مرحبا بالعالم" and stays LTR.

\`\`\`ts
// تعليق عربي
const count = useState(0);
\`\`\``;

export const WordMajority: TextStory<WritingDirectionStoryExtra> = {
  args: {
    markdown: MIXED_MARKDOWN,
    writingDirection: 'word-majority',
    flavor: 'github',
  },
  argTypes,
  render: ({ writingDirection, ...args }) => (
    <EnrichedMarkdownTextStory
      title="Word Majority"
      description="iOS and Android. Each block takes the direction of most of its words, so English-led Arabic stays RTL. Switch to 'first-strong' to compare."
      {...args}
      writingDirection={writingDirection}
    />
  ),
};
