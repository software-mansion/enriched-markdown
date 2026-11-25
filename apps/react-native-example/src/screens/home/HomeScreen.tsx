import { ScrollView, Text, StyleSheet } from 'react-native';
import { HomeScreenButton } from './HomeScreenButton';
import type {
  RootStackParamList,
  RootStackScreenProps,
} from '../../navigation/types';

type Props = RootStackScreenProps<'Home'>;

type ScreenItem = {
  route: Exclude<keyof RootStackParamList, 'Home' | 'MovementPart'>;
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
  {
    route: 'Journal',
    label: 'Kyoto Journal',
    subtext: 'custom block renderers',
    testID: 'home-block-journal',
    color: '#C8442C',
  },
  {
    route: 'JournalSource',
    label: 'Kyoto Journal',
    subtext: 'markdown ⇄ components',
    testID: 'home-block-journal-source',
    color: '#2A211B',
  },
  {
    route: 'LinerNotes',
    label: 'Coltrane Liner Notes',
    subtext: 'records that play',
    testID: 'home-block-liner-notes',
    color: '#D9A441',
  },
  {
    route: 'FlightJournal',
    label: 'Apollo 11 Flight Journal',
    subtext: 'the landing, card by card',
    testID: 'home-block-flight-journal',
    color: '#E5482F',
  },
  {
    route: 'Solids',
    label: 'Solids',
    subtext: 'TypeGPU code blocks, raymarched',
    testID: 'home-block-solids',
    color: '#7C5CFF',
  },
  {
    route: 'Blues',
    label: 'Blues Lesson',
    subtext: 'a lesson you can hear and play',
    testID: 'home-block-blues',
    color: '#E8B04B',
  },
  {
    route: 'NeonPhone',
    label: 'Neon Phone',
    subtext: 'a crime-game phone, all markdown',
    testID: 'home-block-neon-phone',
    color: '#FF4FA3',
  },
  {
    route: 'Movement',
    label: 'The Movement',
    subtext: 'shared element transitions, in markdown',
    testID: 'home-block-movement',
    color: '#2B4C9B',
  },
];

export default function HomeScreen({ navigation }: Props) {
  return (
    <ScrollView
      style={styles.scroll}
      contentContainerStyle={styles.container}
      testID="home-screen"
    >
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
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  container: {
    flexGrow: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
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
