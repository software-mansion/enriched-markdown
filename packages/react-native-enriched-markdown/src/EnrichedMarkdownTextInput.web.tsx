import {
  forwardRef,
  useImperativeHandle,
  useLayoutEffect,
  useRef,
  useState,
  type CSSProperties,
  type HTMLAttributes,
} from 'react';
import { toHeadingLevel } from './headingLevel';
import type {
  CaretRect,
  HeadingLevel,
  HistoryState,
  MarkdownTextInputInstance,
  MeasureCallback,
  MeasureInWindowCallback,
  MeasureLayoutCallback,
  StyleState,
} from './types/MarkdownTextInputInstance';
import type { MarkdownTextInputStyle } from './types/MarkdownTextInputStyle';
import { ImportQueue } from './web/input/editing/ImportQueue';
import { InputHost } from './web/input/editing/InputHost';
import type { InputState } from './web/input/editing/InputState';
import {
  ENRM_INPUT_CLASS,
  ENRM_INPUT_SELECTION_VAR,
} from './web/input/render/inputStyles';
import { inputStyleVariables } from './web/input/render/inputStyleVariables';
import { filterNativeOnlyInputProps } from './web/input/nativeInputProps';
import {
  measure,
  measureInWindow,
  measureLayout,
} from './web/input/measureElement';
import { preloadParser } from './web/parseMarkdown';

// Warmed at module load, not on mount: the mount starts the `defaultValue`
// import in the same layout effect, so that would give no head start, and the
// editor drops keystrokes while that parse is pending.
preloadParser();

export type {
  CaretRect,
  HeadingLevel,
  HistoryState,
  MeasureCallback,
  MeasureInWindowCallback,
  MeasureLayoutCallback,
  StyleState,
};
export type EnrichedMarkdownTextInputInstance =
  MarkdownTextInputInstance<Element>;

// `children` and `dangerouslySetInnerHTML` would have React reconcile against
// a subtree the renderer rewrites by index, which throws a `NotFoundError` on
// the next update; `contentEditable` is re-applied by React on every render
// and would silently undo `editable`. `spellCheck` is redeclared below because
// the host sets it itself.
type ForwardedDomProps = Omit<
  HTMLAttributes<HTMLDivElement>,
  | 'style'
  | 'children'
  | 'dangerouslySetInnerHTML'
  | 'contentEditable'
  | 'spellCheck'
  | 'defaultValue'
  | 'onFocus'
  | 'onBlur'
>;

export interface EnrichedMarkdownTextInputProps extends ForwardedDomProps {
  defaultValue?: string;
  placeholder?: string;
  placeholderTextColor?: string;
  editable?: boolean;
  autoFocus?: boolean;
  spellCheck?: boolean;
  style?: CSSProperties;
  /** Formatting colors and heading sizes. `linkVariants` is ignored on web. */
  markdownStyle?: MarkdownTextInputStyle;
  onChangeText?: (text: string) => void;
  onChangeSelection?: (selection: { start: number; end: number }) => void;
  onChangeState?: (state: StyleState) => void;
  onChangeMarkdown?: (markdown: string) => void;
  onChangeHistoryState?: (state: HistoryState) => void;
  onFocus?: () => void;
  onBlur?: () => void;
  /** Rendered as `data-testid`, as `EnrichedMarkdownText` does. */
  testID?: string;
  /** Background of selected text (`::selection`). */
  selectionColor?: string;
  /** Color of the caret (`caret-color`). */
  cursorColor?: string;
}

const EMPTY_CARET_RECT: CaretRect = { x: 0, y: 0, width: 0, height: 0 };

function logImportError(error: unknown): void {
  console.error('EnrichedMarkdownTextInput.setValue failed', error);
}

function logCommandError(error: unknown): void {
  console.error('EnrichedMarkdownTextInput command failed', error);
}

function toStyleState(state: InputState): StyleState {
  return {
    ...state,
    heading: {
      isActive: state.heading.isActive,
      level: toHeadingLevel(state.heading.level),
    },
  };
}

function warnOnce(): (name: string) => () => void {
  const warned = new Set<string>();
  return (name) => () => {
    if (!warned.has(name)) {
      warned.add(name);
      console.warn(
        `EnrichedMarkdownTextInput.${name} is not yet implemented on web`
      );
    }
  };
}

export const EnrichedMarkdownTextInput = forwardRef<
  EnrichedMarkdownTextInputInstance,
  EnrichedMarkdownTextInputProps
>(function EnrichedMarkdownTextInput(
  {
    defaultValue,
    placeholder,
    placeholderTextColor,
    editable = true,
    autoFocus = false,
    spellCheck,
    style,
    markdownStyle,
    className,
    onChangeText,
    onChangeSelection,
    onChangeState,
    onChangeMarkdown,
    onChangeHistoryState,
    onFocus,
    onBlur,
    testID,
    selectionColor,
    cursorColor,
    ...rest
  },
  ref
) {
  const domProps = filterNativeOnlyInputProps(rest);
  const rootRef = useRef<HTMLDivElement>(null);
  const host = useRef<InputHost | null>(null);
  // A host is reattached only to the node it was built on.
  const hostRoot = useRef<HTMLDivElement | null>(null);
  const [queue] = useState(() => new ImportQueue());
  const initialDefaultValue = useRef(defaultValue).current;
  const initialAutoFocus = useRef(autoFocus).current;
  const initialSpellCheck = useRef(spellCheck).current;
  const currentCallbacks = {
    onChangeText,
    onChangeSelection,
    onChangeState,
    onChangeMarkdown,
    onChangeHistoryState,
    onFocus,
    onBlur,
  };
  const callbacks = useRef(currentCallbacks);
  const latestEditable = useRef(editable);
  useLayoutEffect(() => {
    callbacks.current = currentCallbacks;
    latestEditable.current = editable;
  });

  // A layout effect, not a passive one: `useImperativeHandle` installs the
  // handle in the layout phase, so a parent driving the input from its own
  // layout effect or a ref callback would otherwise reach a null host and its
  // commands would be silently dropped.
  //
  // React reruns this over the same node without unmounting (`<Activity>`,
  // Suspense re-suspending, StrictMode), so the cleanup only detaches and a
  // rerun reattaches with text, caret and undo history intact. Only a new host
  // imports `defaultValue` and takes `autoFocus`: otherwise a rerun would
  // overwrite what the user typed and steal focus on every reveal.
  useLayoutEffect(() => {
    const root = rootRef.current!;
    let instance = host.current;
    const isNew = instance === null || hostRoot.current !== root;
    if (isNew) {
      instance?.destroy();
      instance = new InputHost(
        root,
        {
          onChangeText: (text) => callbacks.current.onChangeText?.(text),
          onChangeSelection: (selection) =>
            callbacks.current.onChangeSelection?.(selection),
          onChangeState: (state) =>
            callbacks.current.onChangeState?.(toStyleState(state)),
          onChangeMarkdown: (markdown) =>
            callbacks.current.onChangeMarkdown?.(markdown),
          onChangeHistoryState: (state) =>
            callbacks.current.onChangeHistoryState?.(state),
        },
        { spellCheck: initialSpellCheck }
      );
      host.current = instance;
      hostRoot.current = root;
    } else {
      instance!.attach();
    }
    const attached = instance!;
    // Before the `autoFocus` below, which dispatches `focus` synchronously:
    // a listener added after it would never see the event.
    const handleFocus = () => callbacks.current.onFocus?.();
    const handleBlur = () => callbacks.current.onBlur?.();
    root.addEventListener('focus', handleFocus);
    root.addEventListener('blur', handleBlur);
    attached.setEditable(latestEditable.current);
    if (isNew && initialDefaultValue !== undefined) {
      // `importValue`, not `setValue`: reporting the app's own markdown back
      // would hand it the serializer's re-normalization. Neither native emits
      // anything for a `defaultValue`.
      queue.startImport(
        () => attached.importValue(initialDefaultValue),
        logImportError
      );
    }
    if (isNew && initialAutoFocus) {
      attached.focus();
    }
    return () => {
      root.removeEventListener('focus', handleFocus);
      root.removeEventListener('blur', handleBlur);
      attached.detach();
    };
  }, [queue, initialDefaultValue, initialAutoFocus, initialSpellCheck]);

  useLayoutEffect(() => {
    host.current?.setEditable(editable);
  }, [editable]);

  // The host cannot tell whether anyone listens: the forwarding closure above
  // exists whether or not the prop does, and serializing every edit is costly.
  const emitsMarkdown = onChangeMarkdown !== undefined;
  useLayoutEffect(() => {
    host.current?.setMarkdownEmitEnabled(emitsMarkdown);
  }, [emitsMarkdown]);

  useImperativeHandle(ref, () => {
    const root = rootRef.current!;
    const notImplemented = warnOnce();
    // A detached host (unmounted, or hidden in an `<Activity>`) still holds
    // the document, so reads answer from it, but a handle kept past unmount
    // must not write to it or make it emit.
    const live = () => (host.current?.isAttached ? host.current : null);
    const run = (command: () => void) =>
      queue.runAfterImport(command, logCommandError);
    return {
      focus: () => live()?.focus(),
      blur: () => live()?.blur(),
      measure: (callback) => measure(root, callback),
      measureInWindow: (callback) => measureInWindow(root, callback),
      measureLayout: (relativeTo, onSuccess, onFail) =>
        measureLayout(root, relativeTo, onSuccess, onFail),

      setValue: (markdown) =>
        queue.startImport(() => live()?.setValue(markdown), logImportError),
      setSelection: (start, end) => run(() => live()?.setSelection(start, end)),
      // Parsed like an import (natives treat it as markdown), so it holds the
      // queue: a command issued right after it acts on the inserted text.
      insertText: (text) =>
        queue.startImport(() => live()?.insertText(text), logCommandError),
      // Resolves even once the input is gone, so a "save the draft on
      // unmount" flow works. Native rejects requests pending at unmount.
      getMarkdown: async () =>
        queue.afterImport(() => host.current?.getMarkdown() ?? ''),
      // A caret needs a mounted, laid-out node; as on native, a request the
      // input can no longer answer rejects rather than resolving to zeros.
      getCaretRect: async () =>
        queue.afterImport(() => {
          const attached = live();
          if (attached === null) {
            throw new Error('Component unmounted');
          }
          return attached.caretRect() ?? EMPTY_CARET_RECT;
        }),

      toggleBold: () => run(() => live()?.toggleBold()),
      toggleItalic: () => run(() => live()?.toggleItalic()),
      toggleUnderline: () => run(() => live()?.toggleUnderline()),
      toggleStrikethrough: () => run(() => live()?.toggleStrikethrough()),
      toggleSpoiler: () => run(() => live()?.toggleSpoiler()),
      toggleHeading: (level) => run(() => live()?.toggleHeading(level)),
      toggleUnorderedList: () => run(() => live()?.toggleUnorderedList()),
      toggleOrderedList: () => run(() => live()?.toggleOrderedList()),
      indentList: () => run(() => live()?.indentList()),
      outdentList: () => run(() => live()?.outdentList()),
      undo: () => run(() => live()?.undo()),
      redo: () => run(() => live()?.redo()),

      setLink: notImplemented('setLink'),
      insertLink: notImplemented('insertLink'),
      removeLink: notImplemented('removeLink'),
      insertMention: notImplemented('insertMention'),
      startMention: notImplemented('startMention'),
      copyToClipboard: notImplemented('copyToClipboard'),
    };
  }, [queue]);

  const cssVariables = {
    ...inputStyleVariables(markdownStyle),
    '--enrm-placeholder-color': placeholderTextColor,
    ...(selectionColor === undefined
      ? {}
      : { [ENRM_INPUT_SELECTION_VAR]: selectionColor }),
    ...(cursorColor === undefined ? {} : { caretColor: cursorColor }),
  } as CSSProperties;
  return (
    <div
      {...domProps}
      ref={rootRef}
      // The host's own `classList.add` is not enough: React rewrites the
      // attribute wholesale when `className` changes, dropping the class every
      // style rule is scoped under.
      className={
        className === undefined
          ? ENRM_INPUT_CLASS
          : `${ENRM_INPUT_CLASS} ${className}`
      }
      style={{ ...cssVariables, ...style }}
      data-placeholder={placeholder}
      data-testid={testID}
      data-selection-color={selectionColor === undefined ? undefined : ''}
      aria-disabled={!editable}
    />
  );
});
