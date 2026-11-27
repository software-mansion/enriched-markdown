import { codegenNativeComponent, type ViewProps } from 'react-native';

/**
 * Child of the GFM `EnrichedMarkdown` host carrying one React replacement for a
 * block. The host's shadow node measures and places it where the native block
 * would have been; `slotId` is the block id from `collectBlockSlots`.
 */
export interface NativeProps extends ViewProps {
  slotId: string;
}

export default codegenNativeComponent<NativeProps>('EnrichedMarkdownBlockSlot');
