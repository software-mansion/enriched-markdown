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
import { ImportQueue } from './web/input/editing/ImportQueue';
import { InputHost } from './web/input/editing/InputHost';
import type { InputState } from './web/input/editing/InputState';
import {
  ENRM_INPUT_CLASS,
  ENRM_INPUT_SELECTION_VAR,
} from './web/input/render/inputStyles';
import { filterNativeOnlyInputProps } from './web/input/nativeInputProps';
import {
  measure,
  measureInWindow,
  measureLayout,
} from './web/input/measureElement';
import { preloadParser } from './web/parseMarkdown';

// Warmed when the component is declared, not when it mounts: the mount starts
// the `defaultValue` import in the same layout effect, so that would give no
// head start, and the editor drops keystrokes while that parse is pending.
// With the parser ready, the import settles before the next input event.
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

// The DOM attributes this component passes through, minus the ones the host
// owns outright. `children` and `dangerouslySetInnerHTML` would have React
// reconcile against a subtree the renderer rewrites by index, which throws a
// `NotFoundError` on the next update; `contentEditable` is re-applied by React
// on every render and would silently undo `editable`. `spellCheck` is held
// back here and offered again below, because the host sets it itself.
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
  // Native-only props would otherwise reach the DOM (review §2.8.2).
  const domProps = filterNativeOnlyInputProps(rest);
  const rootRef = useRef<HTMLDivElement>(null);
  const host = useRef<InputHost | null>(null);
  // The node `host` was built on. A host is reattached only to its own node.
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

  // A layout effect rather than a passive one: `useImperativeHandle` installs
  // the handle in the layout phase, so a parent driving the input from its own
  // layout effect or from a ref callback would otherwise reach a handle whose
  // host is still null, and every command it issued would be dropped with no
  // diagnostic at all.
  //
  // React also runs this again over the same node without unmounting - an
  // `<Activity>` hidden and shown, a Suspense boundary suspending again,
  // StrictMode's double run - so the cleanup only detaches the host, and a
  // re-run over the same node attaches it again with the user's text, caret
  // and undo history intact. Only a new host imports `defaultValue` and takes
  // `autoFocus`: re-importing would replace what the user typed with the
  // mount-time value, and focusing would steal focus on every reveal.
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
      // `importValue`, not `setValue`: the app supplied this markdown, so
      // reporting it back would make `onChangeMarkdown` hand the app the
      // serializer's re-normalization of its own source string. Neither
      // native emits anything for a `defaultValue`.
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

  // Serializing the document after every edit is only worth doing when
  // something is listening, and the host cannot tell from the callback alone:
  // the forwarding closure above is there whether or not the prop is.
  const emitsMarkdown = onChangeMarkdown !== undefined;
  useLayoutEffect(() => {
    host.current?.setMarkdownEmitEnabled(emitsMarkdown);
  }, [emitsMarkdown]);

  useImperativeHandle(ref, () => {
    const root = rootRef.current!;
    const notImplemented = warnOnce();
    // The host while it is attached. A detached one - unmounted, or hidden
    // in an `<Activity>` - still holds the document, so reads answer from it,
    // but nothing writes to it or makes it emit through a handle the app
    // kept past the unmount.
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
      // Parsed like an import (natives treat it as markdown), so it holds
      // the queue the same way: a command issued right after it acts on the
      // inserted text.
      insertText: (text) =>
        queue.startImport(() => live()?.insertText(text), logCommandError),
      // Resolves with the document even once the input is gone, so a "save
      // the draft on unmount" flow saves what was typed. Native rejects
      // requests pending at unmount instead; web can answer them.
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
      // React owns the class list, so the host's own `classList.add` is not
      // enough: React remembers only the caller's value and rewrites the
      // attribute wholesale the first time `className` changes, which would
      // drop the class every style rule is scoped under.
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
