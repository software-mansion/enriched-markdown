// RN's measurement commands in react-native-web's own terms, so a component
// that measures an `EnrichedMarkdownTextInput` reads the same numbers off it
// as off any other view on the page.
//
// Three details are react-native-web's rather than obvious. The geometry for
// `measure` and `measureLayout` is walked up the `offsetParent` chain
// (`offsetLeft` plus `clientLeft` minus `scrollLeft` at every step) instead of
// read off `getBoundingClientRect`, which keeps transforms out of it the way
// the native layout boxes do. `measure` answers `x`/`y` relative to the parent
// element, with `pageX`/`pageY` in viewport coordinates and not document ones.
// And all three are asynchronous and skip a node that has left the document,
// so a measurement scheduled just before an unmount resolves to nothing
// instead of throwing.
import type {
  MeasureCallback,
  MeasureInWindowCallback,
  MeasureLayoutCallback,
} from '../../types/MarkdownTextInputInstance';

interface LayoutBox {
  left: number;
  top: number;
  width: number;
  height: number;
}

function layoutBoxOf(element: HTMLElement): LayoutBox {
  const width = element.offsetWidth;
  const height = element.offsetHeight;
  let left = element.offsetLeft;
  let top = element.offsetTop;
  let ancestor = element.offsetParent;
  while (ancestor !== null) {
    const box = ancestor as HTMLElement;
    left += box.offsetLeft + box.clientLeft - box.scrollLeft;
    top += box.offsetTop + box.clientTop - box.scrollTop;
    ancestor = box.offsetParent;
  }
  return {
    left: left - window.scrollX,
    top: top - window.scrollY,
    width,
    height,
  };
}

let warnedAboutNodeHandle = false;

// `relativeTo` is typed `number | Node` for the native platforms, where the
// number is a view tag. react-native-web's `findNodeHandle` answers the DOM
// node instead, so that is the form this can resolve: a number got here from
// RN's own `findNodeHandle` and names a registry web does not have. It says so
// once instead of measuring against something arbitrary.
function relativeElementOf(relativeTo: number | Node): HTMLElement | null {
  if (relativeTo instanceof HTMLElement) {
    return relativeTo;
  }
  if (typeof relativeTo === 'number' && !warnedAboutNodeHandle) {
    warnedAboutNodeHandle = true;
    console.error(
      "EnrichedMarkdownTextInput.measureLayout was given a numeric node handle, which cannot be resolved on web. Pass the element to measure against, which is what react-native-web's findNodeHandle returns."
    );
  }
  return null;
}

export function measure(element: HTMLElement, callback: MeasureCallback): void {
  const parent = element.parentElement;
  if (parent === null) {
    return;
  }
  setTimeout(() => {
    if (!element.isConnected || !parent.isConnected) {
      return;
    }
    const box = layoutBoxOf(element);
    const origin = layoutBoxOf(parent);
    callback(
      box.left - origin.left,
      box.top - origin.top,
      box.width,
      box.height,
      box.left,
      box.top
    );
  }, 0);
}

export function measureInWindow(
  element: HTMLElement,
  callback: MeasureInWindowCallback
): void {
  setTimeout(() => {
    if (!element.isConnected) {
      return;
    }
    const rect = element.getBoundingClientRect();
    callback(rect.left, rect.top, rect.width, rect.height);
  }, 0);
}

export function measureLayout(
  element: HTMLElement,
  relativeTo: number | Node,
  onSuccess: MeasureLayoutCallback,
  onFail?: () => void
): void {
  const origin = relativeElementOf(relativeTo);
  if (origin === null) {
    onFail?.();
    return;
  }
  setTimeout(() => {
    if (!element.isConnected || !origin.isConnected) {
      onFail?.();
      return;
    }
    const box = layoutBoxOf(element);
    const originBox = layoutBoxOf(origin);
    onSuccess(
      box.left - originBox.left,
      box.top - originBox.top,
      box.width,
      box.height
    );
  }, 0);
}
