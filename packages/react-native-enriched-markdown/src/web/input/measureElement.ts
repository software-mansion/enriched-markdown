import type {
  MeasureCallback,
  MeasureInWindowCallback,
  MeasureLayoutCallback,
} from '../../types/MarkdownTextInputInstance';

export function measure(element: HTMLElement, callback: MeasureCallback): void {
  const rect = element.getBoundingClientRect();
  const parent = element.offsetParent?.getBoundingClientRect();
  callback(
    rect.left - (parent?.left ?? 0),
    rect.top - (parent?.top ?? 0),
    rect.width,
    rect.height,
    rect.left + window.scrollX,
    rect.top + window.scrollY
  );
}

export function measureInWindow(
  element: HTMLElement,
  callback: MeasureInWindowCallback
): void {
  const rect = element.getBoundingClientRect();
  callback(rect.left, rect.top, rect.width, rect.height);
}

export function measureLayout(
  element: HTMLElement,
  relativeTo: unknown,
  onSuccess: MeasureLayoutCallback,
  onFail?: () => void
): void {
  if (!(relativeTo instanceof Element)) {
    onFail?.();
    return;
  }
  const rect = element.getBoundingClientRect();
  const other = relativeTo.getBoundingClientRect();
  onSuccess(
    rect.left - other.left,
    rect.top - other.top,
    rect.width,
    rect.height
  );
}
