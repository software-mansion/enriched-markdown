/**
 * Bridges EnrichedMarkdownTextInput into React Native's TextInputState focus
 * registry so it participates in RN's keyboard-dismiss behavior (issue #577).
 *
 * RN's tap-to-dismiss logic (ScrollView's keyboardShouldPersistTaps handling
 * and Keyboard.dismiss) is implemented entirely in JS. ScrollView's responder
 * handlers consult TextInputState, a plain JS module holding the set of
 * registered inputs and the currently focused one, to decide whether a tap
 * outside the focused field should blur it. A custom native input that never
 * registers is invisible to that logic: ScrollView concludes no text input is
 * focused and leaves the keyboard up.
 *
 * Registering a non-TextInput host component is safe by design. When
 * ScrollView dismisses, TextInputState.blurTextInput dispatches the built-in
 * TextInput's "blur" command at the registered instance, and Fabric command
 * dispatch is name-based; TextInputState.js states "commands don't actually
 * care as long as the thing being passed in actually has a command with that
 * name". EnrichedMarkdownTextInput ships focus/blur commands under those
 * exact names, so the dispatch lands in the existing native handlers and no
 * native changes are needed.
 *
 * The registry has no complete public export: TextInput.State exposes only
 * blurTextInput/focusTextInput/currentlyFocusedInput and lacks the
 * registerInput/focusInput/blurInput bookkeeping functions, so a deep import
 * is required. This is the same approach @expensify/react-native-live-markdown
 * uses. The import is typed here via a local interface; requiring at runtime
 * keeps the internal module out of the public type surface.
 */
import type { HostInstance } from 'react-native';

interface TextInputStateModule {
  registerInput(input: HostInstance): void;
  unregisterInput(input: HostInstance): void;
  focusInput(input: HostInstance | null): void;
  blurInput(input: HostInstance | null): void;
  blurTextInput(input: HostInstance | null): void;
  currentlyFocusedInput(): HostInstance | null;
}

/**
 * The internal module's export shape has changed across RN versions: newer
 * versions use `export default` (surfacing as `.default` after Metro's CJS
 * transform) while older ones assigned `module.exports` directly. A raw
 * require bypasses Babel's import interop, so both shapes are handled here.
 */
const TextInputStateModuleImpl =
  // eslint-disable-next-line @react-native/no-deep-imports
  require('react-native/Libraries/Components/TextInput/TextInputState');

export const TextInputState = (TextInputStateModuleImpl.default ??
  TextInputStateModuleImpl) as TextInputStateModule;
