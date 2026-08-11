import { AppRegistry, LogBox } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import App from './src/App';
import { name as appName } from './app.json';
import e2eConfig from './e2e-config.json';

if (e2eConfig.disableLogBox) {
  LogBox.ignoreAllLogs();
}

const Root = () => (
  <SafeAreaProvider>
    <App />
  </SafeAreaProvider>
);

AppRegistry.registerComponent(appName, () => Root);
