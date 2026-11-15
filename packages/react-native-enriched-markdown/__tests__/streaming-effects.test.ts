import { processColor } from 'react-native';
import { normalizeStreamingEffects } from '../src/streamingEffects';

it('defaults to a 200 ms fade', () => {
  expect(normalizeStreamingEffects(undefined)).toEqual({
    animation: 'fade',
    animationDuration: 200,
    animationLength: 20,
    animationStartColor: undefined,
    animationEndColor: undefined,
  });
});

it('takes a preset name with its defaults', () => {
  expect(normalizeStreamingEffects('gradient')).toMatchObject({
    animation: 'gradient',
    animationLength: 20,
  });
  expect(normalizeStreamingEffects('none').animation).toBe('none');
});

it('passes a preset object’s options', () => {
  expect(
    normalizeStreamingEffects({ type: 'fade', duration: 300 })
  ).toMatchObject({
    animation: 'fade',
    animationDuration: 300,
  });
  expect(
    normalizeStreamingEffects({
      type: 'gradient',
      length: 15,
      startColor: '#107ACA',
      endColor: 'transparent',
    })
  ).toMatchObject({
    animation: 'gradient',
    animationLength: 15,
    animationStartColor: processColor('#107ACA'),
    animationEndColor: processColor('transparent'),
  });
});

it('shows new content at once for an effect it does not know', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  expect(normalizeStreamingEffects('typewriter' as never).animation).toBe(
    'none'
  );
  expect(warn).toHaveBeenCalledTimes(1);
  warn.mockRestore();
});

it('treats a fade over no time or a gradient over no characters as none', () => {
  expect(
    normalizeStreamingEffects({ type: 'fade', duration: 0 }).animation
  ).toBe('none');
  expect(
    normalizeStreamingEffects({ type: 'gradient', length: 0 }).animation
  ).toBe('none');
});

it('sends a whole number of characters, and no animation for less than one', () => {
  const gradient = (length: number) =>
    normalizeStreamingEffects({ type: 'gradient', length });
  expect(gradient(12.5).animationLength).toBe(13);
  for (const length of [0.4, NaN, Infinity]) {
    expect(gradient(length)).toMatchObject({
      animation: 'none',
      animationLength: 20,
    });
  }
  expect(
    normalizeStreamingEffects({ type: 'fade', duration: NaN }).animation
  ).toBe('none');
});
