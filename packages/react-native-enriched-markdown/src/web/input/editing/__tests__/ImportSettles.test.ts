/**
 * @jest-environment jsdom
 */
import { caretAt, mount, typeText } from './inputHostKit';

function nextTask(): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

// A keystroke is a task of its own. The parser loads synchronously, so an
// import lands in microtasks, before the next keystroke, even the first one.
it('lets an import settle before the next keystroke', async () => {
  const { root, host } = mount();
  root.focus();
  const importing = host.importValue('**bold**');

  await nextTask();
  expect(host.value).toBe('bold');
  caretAt(root, 4);
  typeText(root, '!');
  expect(host.value).toBe('bold!');
  await importing;
});
