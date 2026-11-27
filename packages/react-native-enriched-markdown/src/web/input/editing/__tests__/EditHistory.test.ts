import {
  EditHistory,
  GROUP_INTERVAL_MS,
  type ModelSnapshot,
} from '../EditHistory';
import { createBlockRange } from '../../model/blocks';
import type { BlockRange } from '../../model/blocks';
import type { FormattingRange } from '../../model/inlineStyles';
import type { TextEdit } from '../../model/textEdit';

function insert(editStart: number, insertedText: string): TextEdit {
  return { editStart, deletedText: '', insertedText };
}

function remove(editStart: number, deletedText: string): TextEdit {
  return { editStart, deletedText, insertedText: '' };
}

function snapshot(caret = 0): ModelSnapshot {
  return {
    formatting: [],
    blocks: [],
    selection: { start: caret, end: caret },
    backward: false,
  };
}

// A history on a clock the test moves, and a capture that counts its calls.
function setup(maxDepth?: number) {
  let time = 0;
  const history = new EditHistory(() => time, maxDepth);
  let captures = 0;
  const capture = () => {
    captures++;
    return snapshot();
  };
  return {
    history,
    capture,
    captures: () => captures,
    advance: (ms: number) => {
      time += ms;
    },
  };
}

// How many undo steps the history holds, by draining a copy of it.
function depth(history: EditHistory): number {
  let steps = 0;
  while (history.undo(() => snapshot()) !== null) {
    steps++;
  }
  return steps;
}

describe('EditHistory', () => {
  it('starts with nothing to undo or redo', () => {
    const { history } = setup();
    expect(history.state).toEqual({ canUndo: false, canRedo: false });
    expect(history.undo(() => snapshot())).toBeNull();
    expect(history.redo()).toBeNull();
  });

  describe('grouping', () => {
    it('merges adjacent typing into one step', () => {
      const { history, capture, captures } = setup();
      history.record(insert(0, 'a'), 'typing', capture);
      history.record(insert(1, 'b'), 'typing', capture);
      history.record(insert(2, 'c'), 'typing', capture);

      const step = history.undo(() => snapshot(3));
      expect(step?.edits).toEqual([
        insert(0, 'a'),
        insert(1, 'b'),
        insert(2, 'c'),
      ]);
      expect(history.canUndo).toBe(false);
      // Once per step, not once per keystroke.
      expect(captures()).toBe(1);
    });

    it('breaks after a pause', () => {
      const { history, capture, advance } = setup();
      history.record(insert(0, 'a'), 'typing', capture);
      advance(GROUP_INTERVAL_MS);
      history.record(insert(1, 'b'), 'typing', capture);
      advance(GROUP_INTERVAL_MS + 1);
      history.record(insert(2, 'c'), 'typing', capture);

      expect(depth(history)).toBe(2);
    });

    it('breaks on a caret move', () => {
      const { history, capture } = setup();
      history.record(insert(0, 'a'), 'typing', capture);
      history.breakGroup();
      history.record(insert(1, 'b'), 'typing', capture);

      expect(depth(history)).toBe(2);
    });

    it('breaks when typing is not at the previous caret', () => {
      const { history, capture } = setup();
      history.record(insert(0, 'ab'), 'typing', capture);
      history.record(insert(0, 'c'), 'typing', capture);

      expect(depth(history)).toBe(2);
    });

    it('never merges a newline, a paste or a command', () => {
      const { history, capture } = setup();
      history.record(insert(0, 'a'), 'typing', capture);
      history.record(insert(1, '\n'), 'other', capture);
      history.record(insert(2, 'b'), 'typing', capture);
      history.record(insert(3, 'pasted'), 'other', capture);
      history.record(insert(9, 'x'), 'other', capture);

      expect(depth(history)).toBe(5);
    });

    it('keeps backspace runs and typing apart', () => {
      const { history, capture } = setup();
      history.record(insert(0, 'abc'), 'typing', capture);
      history.record(remove(2, 'c'), 'deleting', capture);
      history.record(remove(1, 'b'), 'deleting', capture);
      history.record(insert(1, 'x'), 'typing', capture);

      const steps = [];
      let step;
      while ((step = history.undo(() => snapshot())) !== null) {
        steps.push(step.edits);
      }
      expect(steps).toEqual([
        [insert(1, 'x')],
        [remove(2, 'c'), remove(1, 'b')],
        [insert(0, 'abc')],
      ]);
    });

    it('merges forward deletes at the same place', () => {
      const { history, capture } = setup();
      history.record(remove(1, 'a'), 'deleting', capture);
      history.record(remove(1, 'b'), 'deleting', capture);

      expect(depth(history)).toBe(1);
    });

    it('breaks a delete that is not adjacent', () => {
      const { history, capture } = setup();
      history.record(remove(5, 'a'), 'deleting', capture);
      history.record(remove(1, 'b'), 'deleting', capture);

      expect(depth(history)).toBe(2);
    });

    it('merges a composition however long it takes, until it breaks', () => {
      const { history, capture, advance } = setup();
      history.record(insert(0, 'k'), 'composition', capture);
      advance(GROUP_INTERVAL_MS * 10);
      history.record(
        { editStart: 0, deletedText: 'k', insertedText: 'か' },
        'composition',
        capture
      );
      history.breakGroup();
      history.record(insert(1, 'な'), 'composition', capture);

      expect(depth(history)).toBe(2);
    });

    it('gives a formatting change a step of its own', () => {
      const { history, capture } = setup();
      history.record(insert(0, 'a'), 'typing', capture);
      history.recordFormatting(capture);
      history.record(insert(1, 'b'), 'typing', capture);

      expect(depth(history)).toBe(3);
    });
  });

  describe('undo and redo', () => {
    it('hands back the before and after snapshots', () => {
      const { history } = setup();
      history.record(insert(0, 'a'), 'typing', () => snapshot(0));

      const undone = history.undo(() => snapshot(1));
      expect(undone?.target.selection).toEqual({ start: 0, end: 0 });
      expect(history.state).toEqual({ canUndo: false, canRedo: true });

      const redone = history.redo();
      expect(redone?.edits).toEqual([insert(0, 'a')]);
      expect(redone?.target.selection).toEqual({ start: 1, end: 1 });
      expect(history.state).toEqual({ canUndo: true, canRedo: false });
    });

    it('redoes to where the edit left the caret, not where it is now', () => {
      const { history, capture } = setup();
      history.record(insert(0, 'ab'), 'typing', capture);
      history.record(insert(2, 'c'), 'typing', capture, 1);

      history.undo(() => snapshot(0));
      expect(history.redo()?.target.selection).toEqual({ start: 1, end: 1 });
    });

    it('redoes a formatting change to the selection it was made on', () => {
      const { history } = setup();
      history.recordFormatting(() => ({
        ...snapshot(),
        selection: { start: 0, end: 5 },
        backward: true,
      }));

      history.undo(() => snapshot(2));
      const redone = history.redo();
      expect(redone?.target.selection).toEqual({ start: 0, end: 5 });
      expect(redone?.target.backward).toBe(true);
    });

    it('does not merge typing into a step that was redone', () => {
      const { history, capture } = setup();
      history.record(insert(0, 'a'), 'typing', capture);
      history.undo(() => snapshot());
      history.redo();
      history.record(insert(1, 'b'), 'typing', capture);

      expect(depth(history)).toBe(2);
    });

    it('clears redo on a new edit', () => {
      const { history, capture } = setup();
      history.record(insert(0, 'a'), 'typing', capture);
      history.undo(() => snapshot());
      history.record(insert(0, 'b'), 'typing', capture);

      expect(history.canRedo).toBe(false);
      expect(history.redo()).toBeNull();
    });

    it('clears redo on a formatting change', () => {
      const { history, capture } = setup();
      history.record(insert(0, 'a'), 'typing', capture);
      history.undo(() => snapshot());
      history.recordFormatting(capture);

      expect(history.canRedo).toBe(false);
    });

    it('clear drops both stacks', () => {
      const { history, capture } = setup();
      history.record(insert(0, 'a'), 'typing', capture);
      history.record(insert(1, '\n'), 'other', capture);
      history.undo(() => snapshot());
      history.clear();

      expect(history.state).toEqual({ canUndo: false, canRedo: false });
    });
  });

  describe('discardFormatting', () => {
    it('takes back the step and the redo it cleared', () => {
      const { history, capture } = setup();
      history.record(insert(0, 'a'), 'typing', capture);
      history.undo(() => snapshot());
      history.recordFormatting(capture);
      history.discardFormatting();

      expect(history.state).toEqual({ canUndo: false, canRedo: true });
    });

    it('leaves the history alone once something else was recorded', () => {
      const { history, capture } = setup();
      history.recordFormatting(capture);
      history.record(insert(0, 'a'), 'typing', capture);
      history.discardFormatting();

      expect(depth(history)).toBe(2);
    });
  });

  describe('maxDepth', () => {
    it('drops the oldest steps', () => {
      const { history, capture } = setup(3);
      for (let i = 0; i < 5; i++) {
        history.record(insert(i, '\n'), 'other', capture);
      }

      const kept = [];
      let step;
      while ((step = history.undo(() => snapshot())) !== null) {
        kept.push(step.edits[0]!.editStart);
      }
      expect(kept).toEqual([4, 3, 2]);
    });
  });

  // The stores mutate their range objects in place, so a snapshot that held
  // the live objects would drift with every later edit.
  describe('snapshot copies', () => {
    it('are isolated from later changes to the live ranges', () => {
      const formatting: FormattingRange[] = [
        { type: 'strong', start: 0, end: 3 },
        { type: 'link', start: 4, end: 6, url: 'https://x.dev' },
      ];
      const blocks: BlockRange[] = [
        createBlockRange('ordered-list-item', 0, 3, 1),
      ];
      const { history } = setup();
      history.record(insert(3, 'x'), 'typing', () => ({
        formatting,
        blocks,
        selection: { start: 3, end: 3 },
        backward: false,
      }));
      formatting[0]!.end = 4;
      blocks[0]!.end = 4;
      blocks[0]!.level = 0;
      blocks[0]!.ordinal = 7;

      const step = history.undo(() => snapshot());
      expect(step?.target.formatting).toEqual([
        { type: 'strong', start: 0, end: 3 },
        { type: 'link', start: 4, end: 6, url: 'https://x.dev' },
      ]);
      expect(step?.target.blocks).toEqual([
        createBlockRange('ordered-list-item', 0, 3, 1),
      ]);
    });

    it('hand out fresh ranges on every restore', () => {
      const { history } = setup();
      history.record(insert(0, 'a'), 'typing', () => ({
        formatting: [{ type: 'em', start: 0, end: 1 }],
        blocks: [createBlockRange('h1', 0, 1, 1)],
        selection: { start: 0, end: 0 },
        backward: false,
      }));
      const first = history.undo(() => snapshot())!;
      (first.target.formatting[0] as FormattingRange).end = 9;
      (first.target.blocks[0] as BlockRange).level = 4;
      history.redo();

      const second = history.undo(() => snapshot())!;
      expect(second.target.formatting).toEqual([
        { type: 'em', start: 0, end: 1 },
      ]);
      expect(second.target.blocks).toEqual([createBlockRange('h1', 0, 1, 1)]);
    });

    it('keep their edits apart from the caller', () => {
      const { history, capture } = setup();
      const edit = insert(0, 'a');
      history.record(edit, 'typing', capture);
      edit.insertedText = 'changed';

      expect(history.undo(() => snapshot())?.edits).toEqual([insert(0, 'a')]);
    });
  });

  // Structural guards: the cost of history must not grow with its length.
  describe('cost', () => {
    it('captures once for a typed sentence', () => {
      const { history, capture, captures } = setup();
      const sentence = 'the quick brown fox jumps over the lazy dog';
      for (let i = 0; i < sentence.length; i++) {
        history.record(insert(i, sentence[i]!), 'typing', capture);
      }
      expect(captures()).toBe(1);
    });

    it('releases the redo steps a new edit invalidates', () => {
      const { history, capture } = setup();
      for (let i = 0; i < 10; i++) {
        history.record(insert(i, '\n'), 'other', capture);
      }
      for (let i = 0; i < 10; i++) {
        history.undo(() => snapshot());
      }
      history.record(insert(0, 'a'), 'typing', capture);

      expect(history.redo()).toBeNull();
      expect(depth(history)).toBe(1);
    });
  });
});
