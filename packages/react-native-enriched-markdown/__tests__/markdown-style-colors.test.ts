import { normalizeMarkdownStyle } from '../src/normalizeMarkdownStyle';
import { normalizeColor } from '../src/styleUtils';

const defaultMarkerColor = normalizeColor('#6B7280');

it('keeps the default marker color when an invalid color string is passed', () => {
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});

  const result = normalizeMarkdownStyle({
    list: { markerColor: 'not-a-real-color' },
  });

  expect(result.list.markerColor).toBe(defaultMarkerColor);
  expect(result.list.markerColor).toBeDefined();
  expect(warn).toHaveBeenCalledWith(
    expect.stringContaining('not-a-real-color')
  );

  warn.mockRestore();
});

it('keeps the default marker color when the color is explicitly undefined', () => {
  const result = normalizeMarkdownStyle({
    list: { markerColor: undefined },
  });

  expect(result.list.markerColor).toBe(defaultMarkerColor);
});

it('keeps the default marker color when the color is explicitly null', () => {
  const result = normalizeMarkdownStyle({
    list: { markerColor: null as unknown as string },
  });

  expect(result.list.markerColor).toBe(defaultMarkerColor);
  expect(result.list.markerColor).not.toBeNull();
});

it('passes a valid marker color through unchanged', () => {
  const result = normalizeMarkdownStyle({
    list: { markerColor: '#123456' },
  });

  expect(result.list.markerColor).toBe(normalizeColor('#123456'));
});
