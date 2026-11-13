import { processColor } from 'react-native';
import { normalizeStreamingAnimation } from '../src/streamingAnimation';

it('defaults to a 200 ms fade', () => {
  expect(normalizeStreamingAnimation(undefined)).toEqual({
    animation: 'fade',
    animationDuration: 200,
    animationLength: 20,
    animationStartColor: undefined,
    animationEndColor: undefined,
  });
});

it('takes a preset name with its defaults', () => {
  expect(normalizeStreamingAnimation('gradient')).toMatchObject({
    animation: 'gradient',
    animationLength: 20,
  });
  expect(normalizeStreamingAnimation('none').animation).toBe('none');
});

it('passes a preset object’s options', () => {
  expect(
    normalizeStreamingAnimation({ type: 'fade', duration: 300 })
  ).toMatchObject({
    animation: 'fade',
    animationDuration: 300,
  });
  expect(
    normalizeStreamingAnimation({
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
  expect(normalizeStreamingAnimation('typewriter' as never).animation).toBe(
    'none'
  );
  expect(warn).toHaveBeenCalledTimes(1);
  warn.mockRestore();
});

it('treats a fade over no time or a gradient over no characters as none', () => {
  expect(
    normalizeStreamingAnimation({ type: 'fade', duration: 0 }).animation
  ).toBe('none');
  expect(
    normalizeStreamingAnimation({ type: 'gradient', length: 0 }).animation
  ).toBe('none');
});
