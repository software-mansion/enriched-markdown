import {
  DEFAULT_ACCESSIBILITY_LABELS,
  resolveAccessibilityLabels,
} from '../src/accessibilityLabelDefaults';

it('reads math as spoken English by default', () => {
  expect(resolveAccessibilityLabels(undefined).math.equation).toBe(
    'Math: {speech}'
  );
});

it('keeps the defaults for every field an override omits', () => {
  const labels = resolveAccessibilityLabels({
    math: { equation: 'Formel: {latex}' },
    list: { bulletPoint: 'Punkt' },
  });
  expect(labels.math.equation).toBe('Formel: {latex}');
  expect(labels.list.bulletPoint).toBe('Punkt');
  expect(labels.list.orderedItem).toBe('List item {n}');
  expect(labels.rotor).toEqual(DEFAULT_ACCESSIBILITY_LABELS.rotor);
});
