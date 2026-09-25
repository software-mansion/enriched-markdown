import {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useLayoutEffect,
  useRef,
  useState,
  type CSSProperties,
  type HTMLAttributes,
} from 'react';
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

export interface EnrichedMarkdownTextInputProps extends Omit<
  HTMLAttributes<HTMLDivElement>,
  'style' | 'defaultValue' | 'onFocus' | 'onBlur'
> {
  defaultValue?: string;
  placeholder?: string;
  placeholderTextColor?: string;
  editable?: boolean;
  autoFocus?: boolean;
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

function toStyleState(state: InputState): StyleState {
  return {
    ...state,
    heading: {
      isActive: state.heading.isActive,
      level: state.heading.level as HeadingLevel,
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
    style,
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
  const currentCallbacks = {
    onChangeText,
    onChangeSelection,
    onChangeState,
    onChangeMarkdown,
    onFocus,
    onBlur,
  };
  const callbacks = useRef(currentCallbacks);
  useLayoutEffect(() => {
    callbacks.current = currentCallbacks;
  });

  useEffect(() => {
    const instance = new InputHost(rootRef.current!, {
      onChangeText: (text) => callbacks.current.onChangeText?.(text),
      onChangeSelection: (selection) =>
        callbacks.current.onChangeSelection?.(selection),
      onChangeState: (state) =>
        callbacks.current.onChangeState?.(toStyleState(state)),
      onChangeMarkdown: (markdown) =>
        callbacks.current.onChangeMarkdown?.(markdown),
    });
    host.current = instance;
    if (initialDefaultValue !== undefined) {
      queue.startImport(
        () => instance.setValue(initialDefaultValue),
        logImportError
      );
    }
    if (initialAutoFocus) {
      instance.focus();
    }
    return () => {
      instance.destroy();
      host.current = null;
    };
  }, [queue, initialDefaultValue, initialAutoFocus]);

  useEffect(() => {
    host.current?.setEditable(editable);
  }, [editable]);

  useEffect(() => {
    const root = rootRef.current!;
    const handleFocus = () => callbacks.current.onFocus?.();
    const handleBlur = () => callbacks.current.onBlur?.();
    root.addEventListener('focus', handleFocus);
    root.addEventListener('blur', handleBlur);
    return () => {
      root.removeEventListener('focus', handleFocus);
      root.removeEventListener('blur', handleBlur);
    };
  }, []);

  useImperativeHandle(ref, () => {
    const root = rootRef.current!;
    const notImplemented = warnOnce();
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
        queue.afterImport(() => host.current?.setSelection(start, end)),
      insertText: (text) =>
        queue.afterImport(() => host.current?.insertText(text)),
      getMarkdown: () =>
        Promise.resolve(
          queue.afterImport(() => host.current?.getMarkdown() ?? '')
        ),
      getCaretRect: () =>
        Promise.resolve(
          queue.afterImport(() => host.current?.caretRect() ?? EMPTY_CARET_RECT)
        ),

      toggleBold: () => queue.afterImport(() => host.current?.toggleBold()),
      toggleItalic: () => queue.afterImport(() => host.current?.toggleItalic()),
      toggleUnderline: () =>
        queue.afterImport(() => host.current?.toggleUnderline()),
      toggleStrikethrough: () =>
        queue.afterImport(() => host.current?.toggleStrikethrough()),
      toggleSpoiler: () =>
        queue.afterImport(() => host.current?.toggleSpoiler()),
      toggleHeading: (level) =>
        queue.afterImport(() => host.current?.toggleHeading(level)),
      toggleUnorderedList: () =>
        queue.afterImport(() => host.current?.toggleUnorderedList()),
      toggleOrderedList: () =>
        queue.afterImport(() => host.current?.toggleOrderedList()),
      indentList: () => queue.afterImport(() => host.current?.indentList()),
      outdentList: () => queue.afterImport(() => host.current?.outdentList()),

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
      style={{ ...cssVariables, ...style }}
      data-placeholder={placeholder}
      aria-disabled={!editable}
    />
  );
});
