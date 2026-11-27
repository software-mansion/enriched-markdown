import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

const markdown =
  'Open [README.md](https://example.com/files/README.md) or ask [@gregory](user:gregory).';

export default function App() {
  return (
    <EnrichedMarkdownText
      markdown={markdown}
      // Keys are URL patterns, matched like `linkVariants`; the longest match
      // supplies the menu. Icons are SF Symbols. Needs iOS 17+.
      linkContextMenuItems={{
        '^https://example\\.com/files/': [
          {
            text: 'Copy path',
            icon: 'doc.on.doc',
            onPress: ({ url }) => console.log('copy', url),
          },
          {
            text: 'Delete',
            icon: 'trash',
            destructive: true,
            onPress: ({ url }) => console.log('delete', url),
          },
        ],
        '^user:': [
          {
            text: 'Mention',
            icon: 'at',
            onPress: ({ url }) => console.log('mention', url),
          },
        ],
      }}
      // Android, macOS and iOS 16 ignore the menus and call this instead.
      onLinkLongPress={({ url }) => console.log('long press', url)}
    />
  );
}
