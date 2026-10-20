/**
 * @jest-environment jsdom
 */
// The host projects only the lines its hints say changed. A missing or wrong
// hint shows up as a DOM that differs from a full projection of the model, or
// as the projector's fallback report; seeded random sessions check both.
import { DomRenderer } from '../../render/DomRenderer';
import { projectParagraphs } from '../../render/InputProjection';
import type { BlockStore } from '../../formatting/BlockStore';
import type { FormattingStore } from '../../formatting/FormattingStore';
import type { InputHost } from '../InputHost';
import { mount, selectRangeFocused, sendInput, typeText } from './inputHostKit';

afterEach(() => {
  document.body.replaceChildren();
});

// A span that lost its last style keeps an empty `class` attribute, which a
// freshly built one never had; the two render the same.
function markup(root: HTMLElement): string {
  return root.innerHTML.replaceAll(' class=""', '');
}

// The stores are private; the full projection needs their ranges.
interface HostModel {
  formattingStore: FormattingStore;
  blockStore: BlockStore;
}

function renderedFromScratch(host: InputHost): string {
  const { formattingStore, blockStore } = host as unknown as HostModel;
  const root = document.createElement('div');
  new DomRenderer(root).render(
    projectParagraphs(
      host.value,
      formattingStore.allRanges,
      blockStore.allRanges
    )
  );
  return markup(root);
}

describe('incremental projection', () => {
  it.each([1, 2, 3, 4, 5, 6, 7, 8])(
    'renders what a full projection renders (seed %i)',
    (initialSeed) => {
      let seed = initialSeed;
      const random = () => {
        seed = (seed * 1103515245 + 12345) % 2 ** 31;
        return seed / 2 ** 31;
      };
      const pick = <T>(options: readonly T[]): T =>
        options[Math.floor(random() * options.length)]!;

      const error = jest.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const { host, root } = mount();
        const steps: string[] = [];
        for (let step = 0; step < 400; step++) {
          const length = host.value.length;
          const start = Math.floor(random() * (length + 1));
          // Short selections, so the document grows instead of being
          // replaced every few steps.
          const end =
            random() < 0.5
              ? start
              : Math.min(length, start + 1 + Math.floor(random() * 6));
          selectRangeFocused(root, start, end);

          const action = pick([
            // Typed text, applied literally and at once (`typeText` plays the
            // browser where it is left to type); `insertText` and paste parse
            // markdown, asynchronously.
            () => typeText(root, pick(['x', 'ab', '\n', 'q\nr', 'one two'])),
            () => typeText(root, pick(['word ', 'a\nb\nc', '\n\n'])),
            () => {
              if (start === end) typeText(root, 'k');
            },
            () => {
              if (start === end) typeText(root, 'z');
            },
            () => sendInput(root, 'deleteContentBackward'),
            () => sendInput(root, 'deleteContentForward'),
            () => sendInput(root, 'insertParagraph'),
            () => host.toggleBold(),
            () => host.toggleItalic(),
            () => host.toggleUnorderedList(),
            () => host.toggleOrderedList(),
            () => host.toggleHeading(1 + Math.floor(random() * 3)),
            () => host.indentList(),
            () => host.outdentList(),
            () => host.undo(),
            () => host.redo(),
          ]);
          steps.push(`${step}: [${start}, ${end}) ${action.toString()}`);
          action();

          expect({ steps, html: markup(root) }).toEqual({
            steps,
            html: renderedFromScratch(host),
          });
        }
        expect(error).not.toHaveBeenCalled();
      } finally {
        error.mockRestore();
      }
    }
  );
});
