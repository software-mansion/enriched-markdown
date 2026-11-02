/**
 * @jest-environment jsdom
 */
import { measure, measureInWindow, measureLayout } from '../measureElement';

interface Offsets {
  offsetLeft: number;
  offsetTop: number;
  offsetWidth: number;
  offsetHeight: number;
  offsetParent?: HTMLElement | null;
  clientLeft?: number;
  clientTop?: number;
  scrollLeft?: number;
  scrollTop?: number;
}

// jsdom reports every offset as 0 and every `offsetParent` as null, so the
// layout the commands walk has to be supplied by hand.
function laidOut(offsets: Offsets): HTMLElement {
  const element = document.createElement('div');
  document.body.appendChild(element);
  for (const [name, value] of Object.entries(offsets)) {
    Object.defineProperty(element, name, { value, configurable: true });
  }
  return element;
}

// jsdom keeps the scroll offsets as plain value properties, which `spyOn`
// declines to take over.
function scrolledTo(x: number, y: number): void {
  Object.defineProperty(window, 'scrollX', { value: x, configurable: true });
  Object.defineProperty(window, 'scrollY', { value: y, configurable: true });
}

beforeEach(() => {
  jest.useFakeTimers();
});

afterEach(() => {
  jest.runOnlyPendingTimers();
  jest.useRealTimers();
  jest.restoreAllMocks();
  scrolledTo(0, 0);
  document.body.replaceChildren();
});

describe('measure', () => {
  // react-native-web answers `x`/`y` relative to the parent element, and
  // `pageX`/`pageY` in viewport coordinates rather than document ones.
  it('reports the offset from the parent and the viewport position', () => {
    const parent = laidOut({
      offsetLeft: 10,
      offsetTop: 20,
      offsetWidth: 400,
      offsetHeight: 300,
    });
    const element = laidOut({
      offsetLeft: 15,
      offsetTop: 25,
      offsetWidth: 200,
      offsetHeight: 100,
      offsetParent: parent,
    });
    parent.appendChild(element);
    const onMeasure = jest.fn();

    measure(element, onMeasure);
    jest.runAllTimers();

    expect(onMeasure).toHaveBeenCalledWith(15, 25, 200, 100, 25, 45);
  });

  // The chain, not just the first link: `offsetLeft` is relative to the
  // nearest positioned ancestor, so every step up adds its own offset plus
  // its border and minus its scroll.
  it('walks the whole offsetParent chain', () => {
    const outer = laidOut({
      offsetLeft: 100,
      offsetTop: 200,
      offsetWidth: 800,
      offsetHeight: 600,
    });
    const scroller = laidOut({
      offsetLeft: 10,
      offsetTop: 20,
      offsetWidth: 400,
      offsetHeight: 300,
      offsetParent: outer,
      clientLeft: 1,
      clientTop: 2,
      scrollLeft: 30,
      scrollTop: 40,
    });
    const element = laidOut({
      offsetLeft: 5,
      offsetTop: 5,
      offsetWidth: 50,
      offsetHeight: 50,
      offsetParent: scroller,
    });
    scroller.appendChild(element);
    const onMeasure = jest.fn();

    measure(element, onMeasure);
    jest.runAllTimers();

    const [, , , , pageX, pageY] = onMeasure.mock.calls[0]!;
    expect([pageX, pageY]).toEqual([
      5 + 10 + 1 - 30 + 100,
      5 + 20 + 2 - 40 + 200,
    ]);
  });

  it('takes the page scroll out of the viewport position', () => {
    const parent = laidOut({
      offsetLeft: 0,
      offsetTop: 0,
      offsetWidth: 400,
      offsetHeight: 300,
    });
    const element = laidOut({
      offsetLeft: 40,
      offsetTop: 80,
      offsetWidth: 10,
      offsetHeight: 10,
      offsetParent: parent,
    });
    parent.appendChild(element);
    scrolledTo(7, 13);
    const onMeasure = jest.fn();

    measure(element, onMeasure);
    jest.runAllTimers();

    expect(onMeasure).toHaveBeenCalledWith(40, 80, 10, 10, 33, 67);
  });

  // Asynchronous, like react-native-web's: a measurement scheduled right
  // before an unmount resolves to nothing rather than reading a detached node.
  it('skips a node that left the document before the callback ran', () => {
    const parent = laidOut({
      offsetLeft: 0,
      offsetTop: 0,
      offsetWidth: 400,
      offsetHeight: 300,
    });
    const element = laidOut({
      offsetLeft: 0,
      offsetTop: 0,
      offsetWidth: 10,
      offsetHeight: 10,
      offsetParent: parent,
    });
    parent.appendChild(element);
    const onMeasure = jest.fn();

    measure(element, onMeasure);
    element.remove();
    jest.runAllTimers();

    expect(onMeasure).not.toHaveBeenCalled();
  });

  it('does nothing for a node with no parent element', () => {
    const element = document.createElement('div');
    const onMeasure = jest.fn();

    measure(element, onMeasure);
    jest.runAllTimers();

    expect(onMeasure).not.toHaveBeenCalled();
  });
});

describe('measureInWindow', () => {
  it('reports the client rect, asynchronously', () => {
    const element = laidOut({
      offsetLeft: 0,
      offsetTop: 0,
      offsetWidth: 0,
      offsetHeight: 0,
    });
    element.getBoundingClientRect = () =>
      ({ left: 12, top: 34, width: 56, height: 78 }) as DOMRect;
    const onMeasure = jest.fn();

    measureInWindow(element, onMeasure);
    expect(onMeasure).not.toHaveBeenCalled();

    jest.runAllTimers();
    expect(onMeasure).toHaveBeenCalledWith(12, 34, 56, 78);
  });

  it('skips a detached node', () => {
    const element = document.createElement('div');
    const onMeasure = jest.fn();

    measureInWindow(element, onMeasure);
    jest.runAllTimers();

    expect(onMeasure).not.toHaveBeenCalled();
  });
});

describe('measureLayout', () => {
  it('reports the offset between two elements', () => {
    const relativeTo = laidOut({
      offsetLeft: 10,
      offsetTop: 20,
      offsetWidth: 400,
      offsetHeight: 300,
    });
    const element = laidOut({
      offsetLeft: 60,
      offsetTop: 90,
      offsetWidth: 50,
      offsetHeight: 25,
    });
    const onSuccess = jest.fn();
    const onFail = jest.fn();

    measureLayout(element, relativeTo, onSuccess, onFail);
    jest.runAllTimers();

    expect(onSuccess).toHaveBeenCalledWith(50, 70, 50, 25);
    expect(onFail).not.toHaveBeenCalled();
  });

  // RN's signature allows a numeric view tag, which names a registry web does
  // not have: react-native-web's own `findNodeHandle` answers the DOM node.
  // A silent no-op here leaves a caller with no measurement, no callback and
  // no error, so it fails loudly instead.
  it('fails loudly for a numeric node handle', () => {
    const element = laidOut({
      offsetLeft: 0,
      offsetTop: 0,
      offsetWidth: 10,
      offsetHeight: 10,
    });
    const logged = jest.spyOn(console, 'error').mockImplementation(() => {});
    const onSuccess = jest.fn();
    const onFail = jest.fn();

    measureLayout(element, 42, onSuccess, onFail);
    jest.runAllTimers();

    expect(onFail).toHaveBeenCalled();
    expect(onSuccess).not.toHaveBeenCalled();
    expect(logged).toHaveBeenCalled();
  });

  it('survives a numeric node handle with no onFail supplied', () => {
    const element = laidOut({
      offsetLeft: 0,
      offsetTop: 0,
      offsetWidth: 10,
      offsetHeight: 10,
    });
    jest.spyOn(console, 'error').mockImplementation(() => {});
    const onSuccess = jest.fn();

    expect(() => measureLayout(element, 42, onSuccess)).not.toThrow();
    expect(onSuccess).not.toHaveBeenCalled();
  });

  it('fails when either node has left the document', () => {
    const relativeTo = laidOut({
      offsetLeft: 0,
      offsetTop: 0,
      offsetWidth: 400,
      offsetHeight: 300,
    });
    const element = laidOut({
      offsetLeft: 0,
      offsetTop: 0,
      offsetWidth: 10,
      offsetHeight: 10,
    });
    const onSuccess = jest.fn();
    const onFail = jest.fn();

    measureLayout(element, relativeTo, onSuccess, onFail);
    element.remove();
    jest.runAllTimers();

    expect(onSuccess).not.toHaveBeenCalled();
    expect(onFail).toHaveBeenCalled();
  });
});
