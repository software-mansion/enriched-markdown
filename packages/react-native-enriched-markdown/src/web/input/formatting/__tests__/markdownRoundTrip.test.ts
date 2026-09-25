import { parseToPlainTextAndRanges } from '../InputParser';
import { FormattingStore } from '../FormattingStore';
import { BlockStore } from '../BlockStore';
import { markdownLinePrefix, serialize } from '../MarkdownSerializer';

async function roundTrip(markdown: string): Promise<string> {
  const { plainText, formattingRanges, blockRanges } =
    await parseToPlainTextAndRanges(markdown);

  const styles = new FormattingStore();
  styles.setRanges(formattingRanges);
  const blocks = new BlockStore();
  blocks.setRanges(blockRanges);

  return serialize(
    plainText,
    styles.allRanges,
    blocks.allRanges,
    markdownLinePrefix
  );
}

// Canonical documents: already in the serializer's output form, so the
// round trip must reproduce them byte for byte.
const CANONICAL_FIXTURES = [
  '',
  'rebase the **feature** branch onto *main*',
  'checkout _detached_, drop ~~WIP~~, hide ||the token||',
  'read the [docs](https://git-scm.com) first',
  'bare https://git-scm.com stays plain text',
  '# Setup',
  '## Rebase\n\n1. fetch\n2. merge',
  '### Deploy **now**',
  '***hotfix***',
  '**_hotfix_**',
  '- stack\n   - review',
  '- a\n   - b\n      - c',
  '- stack\n   - review\n   1. merge',
  '1. fetch\n2. merge\n\nrebase\n\n1. push',
  'git fetch\n\n\n\ngit merge',
];

// Non-canonical input: one pass normalizes it into the expected form.
const NORMALIZATION_FIXTURES: Array<[before: string, after: string]> = [
  ['**force push', '**force push**'],
  ['~~drop ||squash', '~~drop ||squash||~~'],
  ['[changelog](https://git-scm', '[changelog](https://git-scm)'],
  // Styles covering exactly the link text move outside the link.
  ['[**docs**](https://x.dev)', '**[docs](https://x.dev)**'],
  // An empty heading is an editing-time anchor; import drops it (as native).
  ['# ', ''],
];

describe('markdown round trip', () => {
  it('reproduces canonical documents byte for byte', async () => {
    for (const markdown of CANONICAL_FIXTURES) {
      expect(await roundTrip(markdown)).toBe(markdown);
    }
  });

  it('normalizes dangling and nested-style forms in one pass', async () => {
    for (const [before, after] of NORMALIZATION_FIXTURES) {
      expect(await roundTrip(before)).toBe(after);
    }
  });

  it('is idempotent: a second pass changes nothing', async () => {
    const inputs = [
      ...CANONICAL_FIXTURES,
      ...NORMALIZATION_FIXTURES.map(([before]) => before),
    ];
    for (const markdown of inputs) {
      const once = await roundTrip(markdown);
      expect(await roundTrip(once)).toBe(once);
    }
  });
});
