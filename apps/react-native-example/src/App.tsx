import { NavigationContainer } from '@react-navigation/native';
import { ReanimatedScreenProvider } from 'react-native-screens/reanimated';
import { Stack } from './navigation/Stack';
import HomeScreen from './screens/home/HomeScreen';
import PlaygroundScreen from './screens/playground/PlaygroundScreen';
import TextScreen from './screens/text/TextScreen';
import InputScreen from './screens/input/InputScreen';
import StreamingMarkdownSimulator from './screens/streaming/StreamingMarkdownSimulator';
import StorybookScreen from './screens/storybook/StorybookScreen';
import JournalScreen from './screens/journal/JournalScreen';
import JournalSourceScreen from './screens/journal/JournalSourceScreen';
import LinerNotesScreen from './screens/jazz/LinerNotesScreen';
import FlightJournalScreen from './screens/apollo/FlightJournalScreen';
import SolidsScreen from './screens/solids/SolidsScreen';
import BluesScreen from './screens/blues/BluesScreen';
import NeonPhoneScreen from './screens/neon/NeonPhoneScreen';
import MovementScreen from './screens/movement/MovementScreen';
import MovementPartScreen from './screens/movement/MovementPartScreen';

export default function App() {
  return (
    <ReanimatedScreenProvider>
      <NavigationContainer>
        <Stack.Navigator
          initialRouteName="Home"
          screenOptions={{
            headerStyle: {
              backgroundColor: '#BEEBD0',
            },
            headerTintColor: '#001A72',
            headerTitleStyle: {
              fontWeight: 'bold',
            },
            headerBackButtonDisplayMode: 'minimal',
          }}
        >
          <Stack.Screen
            name="Home"
            component={HomeScreen}
            options={{ title: 'Enriched Markdown Examples' }}
          />
          <Stack.Screen
            name="Playground"
            component={PlaygroundScreen}
            options={{ title: 'Playground' }}
          />
          <Stack.Screen
            name="Text"
            component={TextScreen}
            options={{ title: 'Text' }}
          />
          <Stack.Screen
            name="Input"
            component={InputScreen}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="Stream"
            component={StreamingMarkdownSimulator}
            options={{ title: 'Stream' }}
          />
          <Stack.Screen
            name="Storybook"
            component={StorybookScreen}
            options={{ title: 'Storybook' }}
          />
          <Stack.Screen
            name="Journal"
            component={JournalScreen}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="JournalSource"
            component={JournalSourceScreen}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="LinerNotes"
            component={LinerNotesScreen}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="FlightJournal"
            component={FlightJournalScreen}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="Solids"
            component={SolidsScreen}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="Blues"
            component={BluesScreen}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="NeonPhone"
            component={NeonPhoneScreen}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="Movement"
            component={MovementScreen}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="MovementPart"
            component={MovementPartScreen}
            options={{
              headerShown: false,
              animation: 'fade',
              animationDuration: 200,
              statusBarStyle: 'light',
            }}
          />
        </Stack.Navigator>
      </NavigationContainer>
    </ReanimatedScreenProvider>
  );
}
