import { useMemo, useSyncExternalStore } from 'react';
import type { Spec } from './NativeEnrichedMarkdownParser';

/**
 * Markdown arriving in pieces (an LLM answer), shown by passing it to
 * `EnrichedMarkdownText` as `stream`. Appending re-renders nothing: only the
 * views showing the stream update, once per frame. Create it outside React
 * (for example next to the message in your store), so it outlives the views.
 */
export interface MarkdownStream {
  /** Adds `chunk` to the end of the text. Ignored after `end()` or `dispose()`, with a warning in development. */
  append(chunk: string): void;
  /** The text appended so far; empty after `dispose()`, even while a view still shows it. */
  getText(): string;
  /** Marks the text complete: views showing it stop streaming and render it in full. */
  end(): void;
  /** Replaces the text (empty by default) and streams again, also after `dispose()`. */
  reset(text?: string): void;
  /**
   * Ends the stream, if `end()` wasn't called, and frees the text once no view
   * shows it. A view that mounts once it is freed shows nothing. A stream JS no longer references is freed too, where the engine
   * supports FinalizationRegistry.
   */
  dispose(): void;
}

/** The stream as of the last frame. */
export interface MarkdownStreamSnapshot {
  /** The native stream holding the text; 0 without the native module. */
  readonly streamId: number;
  /** The native stream's length in bytes. */
  readonly length: number;
  /** The text itself, without the native module (web, Jest). */
  readonly text: string;
  readonly ended: boolean;
}

type NativeStreams = Pick<
  Spec,
  'createStream' | 'appendToStream' | 'readStream' | 'disposeStream'
>;

// Set by the native entry (native/EnrichedMarkdownText): importing the module
// here would pull react-native into the web build.
let nativeStreams: NativeStreams | null = null;

export function setNativeMarkdownStreams(
  module: NativeStreams | null | undefined
): void {
  nativeStreams = module ?? null;
}

const scheduleFrame: (callback: () => void) => void =
  typeof requestAnimationFrame === 'function'
    ? (callback) => requestAnimationFrame(callback)
    : (callback) => setTimeout(callback, 16);

// The native stream's id and the module holding it.
type NativeStream = { id: number; module: NativeStreams | null };

// Frees a stream's native text once JS drops the stream without dispose().
const finalizer =
  typeof FinalizationRegistry === 'function'
    ? new FinalizationRegistry<NativeStream>((native) => {
        if (native.id !== 0) {
          native.module?.disposeStream(native.id);
        }
      })
    : null;

class Stream implements MarkdownStream {
  // Apart from the stream so the finalizer can hold it.
  private readonly native: NativeStream = { id: 0, module: null };
  private length = 0;
  private text = '';
  // A chunk ending halfway through a surrogate pair: UTF-8 has no half characters.
  private highSurrogate = '';
  private ended = false;
  private disposed = false;
  private framePending = false;
  // Native streams a reset replaced, freed once the new one is published.
  private retired: NativeStream[] = [];
  private snapshot: MarkdownStreamSnapshot;
  private readonly listeners = new Set<() => void>();

  constructor(text: string) {
    this.start(text);
    this.snapshot = this.takeSnapshot();
    finalizer?.register(this, this.native);
  }

  append(chunk: string): void {
    if (this.ended || this.disposed) {
      if (__DEV__) {
        console.warn(
          `[react-native-enriched-markdown] MarkdownStream.append() after ${this.disposed ? 'dispose()' : 'end()'} is ignored.`
        );
      }
      return;
    }
    this.write(this.holdBack(chunk));
  }

  getText(): string {
    if (this.disposed) return '';
    const { id, module } = this.native;
    const text = id !== 0 && module != null ? module.readStream(id) : this.text;
    return text + this.highSurrogate;
  }

  end(): void {
    if (this.ended || this.disposed) return;
    this.write(this.highSurrogate);
    this.highSurrogate = '';
    this.ended = true;
    this.publishOnNextFrame();
  }

  reset(text = ''): void {
    // A stream only grows, so a reset starts a new one.
    if (this.native.id !== 0) this.retired.push({ ...this.native });
    this.native.id = 0;
    this.highSurrogate = '';
    this.disposed = false;
    this.ended = false;
    this.start(text);
    this.publishOnNextFrame();
  }

  dispose(): void {
    // A disposed stream has ended: a view still showing it renders it in full.
    this.end();
    this.disposed = true;
    // Views showing the stream keep its text until they unmount.
    if (this.listeners.size === 0) this.release();
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
      if (this.disposed && this.listeners.size === 0) this.release();
    };
  }

  getSnapshot(): MarkdownStreamSnapshot {
    return this.snapshot;
  }

  private write(text: string) {
    if (text === '') return;
    const { id, module } = this.native;
    if (id !== 0 && module != null) {
      this.length = module.appendToStream(id, text);
    } else {
      this.text += text;
    }
    this.publishOnNextFrame();
  }

  // Writes the text as a chunk: append also gives its length in bytes.
  private start(text: string) {
    const module = nativeStreams;
    const complete = this.holdBack(text);
    this.native.module = module;
    if (module != null) {
      this.native.id = module.createStream('');
      this.length =
        complete === '' ? 0 : module.appendToStream(this.native.id, complete);
    } else {
      this.text = complete;
    }
  }

  // Keeps a trailing half surrogate pair for the next chunk.
  private holdBack(chunk: string): string {
    const text = this.highSurrogate + chunk;
    const last = text.charCodeAt(text.length - 1);
    this.highSurrogate = last >= 0xd800 && last <= 0xdbff ? text.slice(-1) : '';
    return this.highSurrogate === '' ? text : text.slice(0, -1);
  }

  // Only once no view shows the stream, so the snapshot can change at once.
  private release() {
    if (this.native.id !== 0) {
      this.native.module?.disposeStream(this.native.id);
      this.native.id = 0;
    }
    this.length = 0;
    this.text = '';
    this.snapshot = this.takeSnapshot();
  }

  private takeSnapshot(): MarkdownStreamSnapshot {
    return {
      streamId: this.native.id,
      length: this.length,
      text: this.text,
      ended: this.ended,
    };
  }

  private publishOnNextFrame() {
    if (this.framePending) return;
    this.framePending = true;
    scheduleFrame(() => {
      this.framePending = false;
      this.snapshot = this.takeSnapshot();
      this.retired.forEach((stream) => stream.module?.disposeStream(stream.id));
      this.retired = [];
      this.listeners.forEach((listener) => listener());
    });
  }
}

export function createMarkdownStream(text = ''): MarkdownStream {
  return new Stream(text);
}

const NO_SUBSCRIPTION = () => () => {};
const NO_SNAPSHOT = () => null;

/** The stream as of the last frame, re-rendering on each new frame; null without a stream. */
export function useMarkdownStreamSnapshot(
  stream: MarkdownStream | undefined
): MarkdownStreamSnapshot | null {
  const store = useMemo(() => {
    if (!(stream instanceof Stream)) {
      if (__DEV__ && stream != null) {
        console.warn(
          '[react-native-enriched-markdown] `stream` takes a stream from createMarkdownStream(); this one is ignored.'
        );
      }
      return { subscribe: NO_SUBSCRIPTION, getSnapshot: NO_SNAPSHOT };
    }
    return {
      subscribe: (listener: () => void) => stream.subscribe(listener),
      getSnapshot: () => stream.getSnapshot(),
    };
  }, [stream]);
  return useSyncExternalStore(
    store.subscribe,
    store.getSnapshot,
    store.getSnapshot
  );
}
