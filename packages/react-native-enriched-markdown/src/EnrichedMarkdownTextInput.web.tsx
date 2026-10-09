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
  MarkdownTextInputInstance,
  MeasureCallback,
  MeasureInWindowCallback,
  MeasureLayoutCallback,
  StyleState,
} from './types/MarkdownTextInputInstance';
import { ImportQueue } from './web/input/editing/ImportQueue';
import { InputHost } from './web/input/editing/InputHost';
import type { InputState } from './web/input/editing/InputState';
import { ENRM_INPUT_CLASS } from './web/input/render/inputStyles';
import {
  measure,
  measureInWindow,
  measureLayout,
} from './web/input/measureElement';

export type {
  CaretRect,
  HeadingLevel,
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
  onFocus?: () => void;
  onBlur?: () => void;
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
    onFocus,
    onBlur,
    ...domProps
  },
  ref
) {
  const rootRef = useRef<HTMLDivElement>(null);
  const host = useRef<InputHost | null>(null);
  const [queue] = useState(() => new ImportQueue());
  const initialDefaultValue = useRef(defaultValue).current;
  const initialAutoFocus = useRef(autoFocus).current;
  const initialSpellCheck = useRef(spellCheck).current;
  const currentCallbacks = {
    onChangeText,
    onChangeSelection,
    onChangeState,
    onChangeMarkdown,
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
  useLayoutEffect(() => {
    const root = rootRef.current!;
    const instance = new InputHost(
      root,
      {
        onChangeText: (text) => callbacks.current.onChangeText?.(text),
        onChangeSelection: (selection) =>
          callbacks.current.onChangeSelection?.(selection),
        onChangeState: (state) =>
          callbacks.current.onChangeState?.(toStyleState(state)),
        onChangeMarkdown: (markdown) =>
          callbacks.current.onChangeMarkdown?.(markdown),
      },
      { spellCheck: initialSpellCheck }
    );
    host.current = instance;
    // Before the `autoFocus` below, which dispatches `focus` synchronously:
    // a listener added after it would never see the event.
    const handleFocus = () => callbacks.current.onFocus?.();
    const handleBlur = () => callbacks.current.onBlur?.();
    root.addEventListener('focus', handleFocus);
    root.addEventListener('blur', handleBlur);
    instance.setEditable(latestEditable.current);
    if (initialDefaultValue !== undefined) {
      // `importValue`, not `setValue`: the app supplied this markdown, so
      // reporting it back would make `onChangeMarkdown` hand the app the
      // serializer's re-normalization of its own source string. Neither
      // native emits anything for a `defaultValue`.
      queue.startImport(
        () => instance.importValue(initialDefaultValue),
        logImportError
      );
    }
    if (initialAutoFocus) {
      instance.focus();
    }
    return () => {
      root.removeEventListener('focus', handleFocus);
      root.removeEventListener('blur', handleBlur);
      instance.destroy();
      host.current = null;
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
    const run = (command: () => void) =>
      queue.runAfterImport(command, logCommandError);
    return {
      focus: () => host.current?.focus(),
      blur: () => host.current?.blur(),
      measure: (callback) => measure(root, callback),
      measureInWindow: (callback) => measureInWindow(root, callback),
      measureLayout: (relativeTo, onSuccess, onFail) =>
        measureLayout(root, relativeTo, onSuccess, onFail),

      setValue: (markdown) =>
        queue.startImport(
          () => host.current?.setValue(markdown),
          logImportError
        ),
      setSelection: (start, end) =>
        run(() => host.current?.setSelection(start, end)),
      insertText: (text) => run(() => host.current?.insertText(text)),
      getMarkdown: async () =>
        queue.afterImport(() => host.current?.getMarkdown() ?? ''),
      getCaretRect: async () =>
        queue.afterImport(() => host.current?.caretRect() ?? EMPTY_CARET_RECT),

      toggleBold: () => run(() => host.current?.toggleBold()),
      toggleItalic: () => run(() => host.current?.toggleItalic()),
      toggleUnderline: () => run(() => host.current?.toggleUnderline()),
      toggleStrikethrough: () => run(() => host.current?.toggleStrikethrough()),
      toggleSpoiler: () => run(() => host.current?.toggleSpoiler()),
      toggleHeading: (level) => run(() => host.current?.toggleHeading(level)),
      toggleUnorderedList: () => run(() => host.current?.toggleUnorderedList()),
      toggleOrderedList: () => run(() => host.current?.toggleOrderedList()),
      indentList: () => run(() => host.current?.indentList()),
      outdentList: () => run(() => host.current?.outdentList()),

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
      aria-disabled={!editable}
    />
  );
});
