const path = require('path');
const { getConfig } = require('react-native-builder-bob/babel-config');
const pkg = require('../../packages/react-native-enriched-markdown/package.json');

const root = path.resolve(
  __dirname,
  '../../packages/react-native-enriched-markdown'
);

module.exports = getConfig(
  {
    presets: ['module:@react-native/babel-preset'],
  },
  { root, pkg }
);
