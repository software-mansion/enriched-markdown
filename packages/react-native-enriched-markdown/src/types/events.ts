export interface LinkPressEvent {
  url: string;
}

export interface LinkLongPressEvent {
  url: string;
}

export interface TaskListItemPressEvent {
  index: number;
  checked: boolean;
  text: string;
}

export interface CopyPressEvent {
  code: string;
  language: string;
}

/**
 * Native-level context menu item config sent to the native component.
 * Does not include the `onPress` callback — callbacks are managed on the JS side.
 */
export interface ContextMenuItemConfig {
  text: string;
  icon?: string;
}

/**
 * Event payload fired by the native component when a context menu item is pressed.
 */
export interface OnContextMenuItemPressEvent {
  itemText: string;
  selectedText: string;
  selectionStart: number;
  selectionEnd: number;
}
