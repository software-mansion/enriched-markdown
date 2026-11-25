export const PROMPT =
  'Plan me three slow days in Kyoto. Trains, temples, bamboo.';

export const JOURNAL_MARKDOWN = `# Three slow days in Kyoto

Go in autumn: maples turning red, mornings cold enough for a first matcha.

## Day 1 · Arrive by rail

Take the early Nozomi from Tokyo and sit on the **E side**. Mount Fuji shows up forty minutes in.

\`\`\`rail
07:33 Tokyo --> 09:47 Kyoto
08:14 ^ Mount Fuji
09:11 Nagoya
\`\`\`

Drop your bags in **Gion** and walk Shinbashi-dori as the lanterns come on.

## Day 2 · Ten thousand gates

Be at Fushimi Inari *before seven*. By nine the lower gates are a queue.

\`\`\`mermaid
xychart-beta
  title "Fushimi Inari, how busy by hour"
  x-axis [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
  bar [6, 14, 38, 58, 86, 100, 94, 88, 80, 74, 66, 52]
\`\`\`

<video src="https://journal.app/kyoto/fushimi-inari-gates.mp4"></video>

Walk down to Kiyomizu-dera for the maples and ask for a *goshuin*, the temple's ink seal.

[Kiyomizu-dera](https://www.kiyomizudera.or.jp/en/ "清水寺")

## Day 3 · Bamboo & gold

Arashiyama at dawn, when the grove still creaks in the wind. Cross town after lunch and finish at Kinkaku-ji in the late light.

\`\`\`mermaid
journey
  title Day 3, how it feels
  section Dawn
    Bamboo grove: 5: Me
    Tenryu-ji: 4: Me
  section Noon
    Togetsukyo: 2: Me
    Yudofu lunch: 5: Me
  section Late light
    Bus ride: 2: Me
    Kinkaku-ji: 5: Me
\`\`\`

![Kinkaku-ji, the golden pavilion](https://journal.app/kyoto/kinkaku.jpg)

## What it costs

\`\`\`mermaid
pie title Three days, in yen
  "Ryokan, two nights" : 42000
  "Shinkansen, both ways" : 28340
  "Food & matcha" : 17400
  "Temples & seals" : 3500
\`\`\`

Have a slow trip.
`;
