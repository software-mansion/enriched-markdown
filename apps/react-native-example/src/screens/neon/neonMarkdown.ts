// Everything on the phone is plain markdown: the chat, the job brief and the
// feed. Characters, places and brands are made up for this demo.

export type ChatMessage = { from: 'them' | 'me'; markdown: string };

export const CONTACT = 'Dre';

export const CHAT: ChatMessage[] = [
  {
    from: 'them',
    markdown: 'yo. you up? got **work** tonight 🌴',
  },
  { from: 'me', markdown: 'depends. how much' },
  {
    from: 'them',
    markdown: '$250k split three ways. the boat at **Pier 9**, *no questions*',
  },
  {
    from: 'them',
    markdown:
      'bring:\n- [x] the van\n- [ ] gloves\n- [ ] ~~Marco~~ someone who can actually drive',
  },
  { from: 'me', markdown: 'whos the third' },
  {
    from: 'them',
    markdown:
      '@nico — hes clean. gate code is ||0451|| — dont text it to anyone',
  },
  {
    from: 'them',
    markdown: 'full brief is in **Jobs**. meet at `02:00` 🔥 #marinajob',
  },
];

export const JOB_MARKDOWN = `# The Marina Job

Posted by @dre · tonight, \`02:00\` · Pier 9

> [!IMPORTANT]
> Get in, take the yacht, get out. **Keep the heat under two stars**, or the deal is off.

## Objectives

- [ ] Meet @nico at the bait shop
- [ ] Lift the keys from the harbor office
- [ ] Get the *Sea Fortune* out past the breakwater
- [ ] Lose the coast guard

## Crew

| Crew | Role | Cut |
| --- | --- | --- |
| @dre | Planner | $100k |
| @nico | Wheelman | $75k |
| You | Inside | $75k |

## Intel

1. The guard swaps at \`02:10\`. You get **four minutes**.
2. Office door code: ||0451||
3. The harbor cams loop every ==90s==.

> [!WARNING]
> Nico talks too much. Don't let him near the radio.

---

*Delete this message after reading.* #marinajob
`;

export type Post = {
  name: string;
  handle: string;
  time: string;
  color: string;
  markdown: string;
  likes: string;
};

export const FEED: Post[] = [
  {
    name: 'Coast Weather',
    handle: '@coastwx',
    time: '2m',
    color: '#2EE6D6',
    markdown:
      'Clear skies tonight, **84°F** at midnight. Perfect night for a ==boat ride==. #sunsetcoast',
    likes: '1.2k',
  },
  {
    name: 'Nico',
    handle: '@nico',
    time: '5m',
    color: '#FF9E3D',
    markdown: 'big night tonight 😎 cant say why. ||its a boat|| #marinajob',
    likes: '3',
  },
  {
    name: 'Harbor Police',
    handle: '@harborpd',
    time: '11m',
    color: '#5B8CFF',
    markdown:
      'Reminder: Pier 9 is **closed to the public** after midnight.\n- extra patrols\n- new cameras\n- *no exceptions*',
    likes: '48',
  },
  {
    name: 'Markdown Fan',
    handle: '@mdfan',
    time: '20m',
    color: '#FF4FA3',
    markdown:
      'every bubble, brief and post on this phone is **markdown**, rendered natively. `react-native-enriched-markdown` #reactnative',
    likes: '9.9k',
  },
];
