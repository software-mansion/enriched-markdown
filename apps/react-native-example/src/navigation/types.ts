import type { NativeStackScreenProps } from '@react-navigation/native-stack';

export type RootStackParamList = {
  Home: undefined;
  Playground: undefined;
  Text: undefined;
  Input: { channel: string };
  Stream: undefined;
  Storybook: undefined;
  Journal: undefined;
  JournalSource: undefined;
  LinerNotes: undefined;
  FlightJournal: undefined;
  Solids: undefined;
  Blues: undefined;
  NeonPhone: undefined;
  Movement: undefined;
  MovementPart: { part: string; night?: boolean };
};

export type RootStackScreenProps<T extends keyof RootStackParamList> =
  NativeStackScreenProps<RootStackParamList, T>;

declare global {
  namespace ReactNavigation {
    interface RootParamList extends RootStackParamList {}
  }
}
