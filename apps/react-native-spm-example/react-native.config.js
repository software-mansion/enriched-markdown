const path = require('path');
const pkg = require('../../packages/react-native-enriched-markdown/package.json');

module.exports = {
  dependencies: {
    [pkg.name]: {
      root: path.join(
        __dirname,
        '../../packages/react-native-enriched-markdown'
      ),
      platforms: {
        ios: {},
      },
    },
  },
};
