import React from 'react';
import {
  StyleSheet,
  ScrollView,
  View,
  Text,
  Linking,
  Alert,
} from 'react-native-macos';
import {
  EnrichedMarkdownText,
  type LinkPressEvent,
  type ImagePressEvent,
} from 'react-native-enriched-markdown';
import { useMemo, useState } from 'react';
import { sampleMarkdown } from './sampleMarkdown';
import { customMarkdownStyle } from './markdownStyles';
import InputScreen from './InputScreen';

type Screen = 'text' | 'input';

export default function App() {
  const [screen, setScreen] = useState<Screen>('input');
  const markdownStyle = useMemo(() => customMarkdownStyle, []);
  const [lastLink, setLastLink] = useState<string | null>(null);

  const contextMenuItems = useMemo(
    () => [
      {
        text: 'Summarize with AI',
        icon: 'sparkles',
        onPress: ({ text }: { text: string }) => {
          Alert.alert('✦ Summarize with AI', `"${text}"`, [
            { text: 'Dismiss', style: 'cancel' },
          ]);
        },
      },
      {
        text: 'Translate',
        icon: 'globe',
        onPress: ({ text }: { text: string }) => {
          Alert.alert('Translate', `"${text}"`, [
            { text: 'Dismiss', style: 'cancel' },
          ]);
        },
      },
    ],
    []
  );

  const handleLinkPress = (event: LinkPressEvent) => {
    setLastLink(event.url);
    Linking.openURL(event.url);
  };

  const handleImagePress = (event: ImagePressEvent) => {
    Alert.alert('Image Pressed', `${event.altText || 'Image'}\n${event.url}`, [
      { text: 'Dismiss', style: 'cancel' },
    ]);
  };

  return (
    <View style={styles.root}>
      <View style={styles.tabs}>
        <Text
          style={[styles.tab, screen === 'input' && styles.tabActive]}
          onPress={() => setScreen('input')}
        >
          Input
        </Text>
        <Text
          style={[styles.tab, screen === 'text' && styles.tabActive]}
          onPress={() => setScreen('text')}
        >
          Text
        </Text>
      </View>

      {screen === 'input' ? (
        <InputScreen />
      ) : (
        <View style={styles.textScreen}>
          <ScrollView
            style={styles.scrollView}
            contentContainerStyle={styles.content}
            scrollIndicatorInsets={{ right: 1 }}
          >
            <EnrichedMarkdownText
              flavor="github"
              markdown={sampleMarkdown}
              onLinkPress={handleLinkPress}
              onImagePress={handleImagePress}
              markdownStyle={markdownStyle}
              contextMenuItems={contextMenuItems}
              selectionColor="#DCDDFE"
              selectionMenuConfig={{
                copyAsMarkdown: { enabled: true },
                copyImageUrl: { enabled: true },
              }}
              md4cFlags={{
                superscript: true,
                subscript: true,
              }}
            />
          </ScrollView>
          {lastLink != null && (
            <Text style={styles.linkBar}>Last tapped link: {lastLink}</Text>
          )}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    height: '100%',
    backgroundColor: '#ffffff',
  },
  tabs: {
    flexDirection: 'row',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D1D5DB',
  },
  tab: {
    flex: 1,
    textAlign: 'center',
    paddingVertical: 10,
    fontSize: 13,
    fontWeight: '500',
    color: '#6B7280',
  },
  tabActive: {
    color: '#2563EB',
    borderBottomWidth: 2,
    borderBottomColor: '#2563EB',
  },
  textScreen: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  content: {
    paddingHorizontal: 24,
    paddingVertical: 20,
  },
  linkBar: {
    padding: 8,
    backgroundColor: '#f0f0f0',
    fontSize: 12,
    color: '#333',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#ddd',
  },
});
