import { useEffect, useMemo, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated from 'react-native-reanimated';
import { useNavigation, type ParamListBase } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useHinge } from '../shared/hinge';
import { Cover } from './duo/Cover';
import { Spread } from './duo/DuoJournal';
import { DotGrid, Journal, Prompt, useJournal } from './JournalScreen';
import { SourceSwitch, sourceRenderers } from './source/SourceSwitch';
import { PAPER } from './theme';

// The Kyoto Journal, written, with a switch between the components its blocks
// render as and the markdown they are written in.
export default function JournalSourceScreen() {
  const hinge = useHinge();
  const [readFolded, setReadFolded] = useState(false);
  useEffect(() => {
    if (!hinge.closed) setReadFolded(false);
  }, [hinge.closed]);

  const navigation = useNavigation<NativeStackNavigationProp<ParamListBase>>();
  useEffect(() => {
    if (hinge.available) navigation.setOptions({ statusBarHidden: true });
  }, [navigation, hinge.available]);

  if (!hinge.known) return <View style={styles.root} />;
  // Folded, the Duo is the journal's cover until it is opened or read.
  if (hinge.available && hinge.closed && !readFolded) {
    return <Cover onRead={() => setReadFolded(true)} />;
  }
  const book = hinge.available && !hinge.closed;
  return (
    <View style={styles.root}>
      <SourceSwitch>
        {book ? (
          <Spread open={hinge.open} renderers={sourceRenderers} written />
        ) : (
          <Column clearCutout={hinge.available} />
        )}
      </SourceSwitch>
    </View>
  );
}

// How far down the folded Duo's camera reaches with the status bar hidden.
const CUTOUT = 60;

function Column({ clearCutout }: { clearCutout: boolean }) {
  const insets = useSafeAreaInsets();
  const stream = useJournal(undefined, true);
  const top = clearCutout ? Math.max(insets.top, CUTOUT) : insets.top;
  const contentStyle = useMemo(
    () => [
      styles.content,
      { paddingTop: top + 16, paddingBottom: insets.bottom + 110 },
    ],
    [top, insets.bottom]
  );
  return (
    <>
      <DotGrid />
      <Animated.ScrollView
        {...stream.scrollProps}
        contentContainerStyle={contentStyle}
      >
        <Prompt />
        <Journal
          markdown={stream.markdown}
          run={stream.run}
          streaming={stream.streaming}
          signed={!stream.streaming}
          renderers={sourceRenderers}
        />
      </Animated.ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: PAPER,
  },
  content: {
    paddingHorizontal: 22,
  },
});
