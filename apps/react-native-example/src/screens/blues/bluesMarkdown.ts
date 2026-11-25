export const PROMPT = "I've never played piano. Teach me the blues.";

export const BLUES_MARKDOWN = `# The blues in ten minutes

You don't need to read music for this. Every block below is something you can **hear** and **play**: tap the keys, tap the chords in the text, drag what moves. By the end you'll be jamming with a band.

## Find your way around

Every keyboard repeats the same pattern of twelve keys. Find the white key just left of the two black ones: that's **C**. The white keys up from it spell out the C major scale.

\`\`\`keys
// the C major scale, from middle C
C4
D4
E4
F4
G4
A4
B4
C5
\`\`\`

Play three of those at once, skipping one each time, and you have a chord. C, E and G make [C major](chord:C), and it sounds like sunshine.

## One note makes it blue

Now lower the middle note a half step, to the black key just below, and [C major](chord:C) becomes [C minor](chord:Cm). Drag the fader and hear the light go out.

\`\`\`flip
// slide E down to E♭
hold C4 E4 G4
move E4 -> Eb4
\`\`\`

The blues lives right on that edge. Blues players don't choose between major and minor: they bend notes into the space between them.

## Feel the shuffle

The blues doesn't march, it swings: each beat splits into a long note and a short one, *DAH-da DAH-da*. Here's the beat. It keeps going, so tap any pad to change it while it plays.

\`\`\`groove
// a slow shuffle, four beats to the bar
kick  x...x.x.
snare ..x...x.
hat   xoxoxoxo
\`\`\`

## Twelve bars

The whole form is three chords in twelve bars. [C7](chord:C7) is home, [F7](chord:F7) takes you away, and [G7](chord:G7) pulls you back. Listen: the band comes in as the chart fills.

\`\`\`progression
// the twelve-bar blues in C
C7 C7 C7 C7
F7 F7 C7 C7
G7 F7 C7 G7
\`\`\`

## Now you play

Six notes are all you need: the blues scale. One of them, [G♭](note:Gb4), is *the blue note*, wrong on its own and perfect in a blues. The keyboard below keeps only those six, so **every key you can press sounds right**, and the keys lit from beneath belong to the bar's chord.

\`\`\`jam
// your solo. no wrong notes.
scale C blues
lick G4 Bb4 C5 Eb5 - C5 Bb4 G4 Gb4 F4 Eb4 C4
\`\`\`

> Start slow. Play two notes and leave space; the band fills the rest. That's the blues.

*Piano: Salamander Grand Piano by Alexander Holm, CC BY 3.0.*
`;
