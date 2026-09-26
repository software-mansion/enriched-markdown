import {
  filterNativeOnlyProps,
  NATIVE_ONLY_PROP_NAMES,
} from '../src/web/nativeProps';

it('strips every native-only prop so none can reach the DOM', () => {
  const nativeProps = Object.fromEntries(
    Object.keys(NATIVE_ONLY_PROP_NAMES).map((name) => [name, 'value'])
  );

  const result = filterNativeOnlyProps(nativeProps);

  expect(Object.keys(result)).toEqual([]);
});

it('keeps props that are valid on a DOM element', () => {
  const onClick = () => {};

  const result = filterNativeOnlyProps({
    'id': 'root',
    'className': 'custom',
    'role': 'article',
    'aria-label': 'Release notes',
    'data-testid': 'markdown',
    onClick,
    'flavor': 'github',
    'numberOfLines': 3,
  });

  expect(result).toEqual({
    'id': 'root',
    'className': 'custom',
    'role': 'article',
    'aria-label': 'Release notes',
    'data-testid': 'markdown',
    onClick,
  });
});

it('leaves the input object untouched', () => {
  const props = { className: 'custom', flavor: 'github' };

  filterNativeOnlyProps(props);

  expect(props).toEqual({ className: 'custom', flavor: 'github' });
});
