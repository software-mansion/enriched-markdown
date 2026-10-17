import { View, Text, StyleSheet } from 'react-native';
import { HomeScreenButton } from './HomeScreenButton';
import type {
  RootStackParamList,
  RootStackScreenProps,
} from '../../navigation/types';

type Props = RootStackScreenProps<'Home'>;

type ScreenItem = {
  route: Exclude<keyof RootStackParamList, 'Home'>;
  label: string;
  subtext: string;
  testID: string;
  color: string;
};

const SCREENS: ScreenItem[] = [
  {
    route: 'Playground',
    label: 'Playground',
    subtext: 'live editor with preview',
    testID: 'home-block-playground',
    color: '#007AFF',
  },
  {
    route: 'Text',
    label: 'Text',
    subtext: 'static markdown rendering',
    testID: 'home-block-text',
    color: '#34C759',
  },
  {
    route: 'Input',
    label: 'Input',
    subtext: 'chat-style rich text input',
    testID: 'home-block-input',
    color: '#FF9500',
  },
  {
    route: 'Stream',
    label: 'Stream',
    subtext: 'streaming markdown with tables',
    testID: 'home-block-stream',
    color: '#AF52DE',
  },
  {
    route: 'Storybook',
    label: 'Storybook',
    subtext: 'component stories',
    testID: 'home-block-storybook',
    color: '#FF2D55',
  },
];

export default function HomeScreen({ navigation }: Props) {
  return (
    <View style={styles.container} testID="home-screen">
      <Text style={styles.title}>Enriched Markdown Examples</Text>
      <Text style={styles.subtitle}>
        Explore different markdown rendering and input capabilities
      </Text>

      {SCREENS.map(({ route, label, subtext, testID, color }) => (
        <HomeScreenButton
          key={route}
          label={label}
          subtext={subtext}
          testID={testID}
          color={color}
          onPress={() =>
            route === 'Input'
              ? navigation.navigate('Input', { channel: 'random' })
              : navigation.navigate(route)
          }
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    marginBottom: 10,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    marginBottom: 40,
    textAlign: 'center',
  },
});
