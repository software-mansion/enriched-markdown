export type PartId =
  | 'barrel'
  | 'train'
  | 'escapement'
  | 'balance'
  | 'rate'
  | 'seconds';

export const PART_IDS: PartId[] = [
  'barrel',
  'train',
  'escapement',
  'balance',
  'rate',
  'seconds',
];

export const PART_NAMES: Record<PartId, string> = {
  barrel: 'Mainspring',
  train: 'Going train',
  escapement: 'Escapement',
  balance: 'Balance',
  rate: 'Rate trace',
  seconds: 'Small seconds',
};

export function isPartId(language: string): language is PartId {
  return (PART_IDS as string[]).includes(language);
}

// Every fenced block names an assembly; its lines are the figures engraved on
// the card. The renderer draws the works, the markdown says what they are.
export const MOVEMENT_MARKDOWN = `# The Movement

*Bench notes on a mechanical watch: six assemblies, in the order the power flows.*

A watch is a wound spring and a long argument about how slowly it may let go. Everything on this page is running while you read it.

> Oil it sparingly, and never trust a watch that agrees with you.

## I · POWER

Half a metre of alloy ribbon, coiled inside a toothed drum. Wound tight, it would gladly spin the barrel flat in a second and a half. The rest of the watch exists to say *not yet*.

\`\`\`barrel
Reserve: 41 hours
Ribbon: 480 mm
\`\`\`

## II · GEARING

Three wheels trade the barrel's slow torque for speed. Each mesh multiplies, and by the fourth wheel **one turn takes exactly a minute**.

\`\`\`train
Teeth: 36 · 24 · 15
Ratio: 1 to 60
\`\`\`

## III · THE GATE

The escape wheel is where the argument happens. Two ruby pallets let it pass one tooth at a time, and take a small push in return. That push is the tick.

\`\`\`escapement
Teeth: 15, club
Pallets: ruby
\`\`\`

## IV · THE BEAT

The balance swings, the hairspring breathes, and five times a second the pallets unlock: \`18,000\` beats an hour. It is drawn here at quarter speed so the eye can follow.

\`\`\`balance
Rate: 18,000 vph
Swing: 280°
\`\`\`

## V · THE PROOF

A timing machine listens to those ticks and plots them. A level trace means the watch neither gains nor loses. This one climbs by a hair.

\`\`\`rate
Gain: +3 s a day
Beat error: 0.2 ms
\`\`\`

| Position | Rate |
| :-- | --: |
| Dial up | +2 s/d |
| Crown down | +5 s/d |
| Crown left | +3 s/d |

## VI · THE SECOND

All of it resolves into one small hand. This is not a drawing of a clock: it is this phone's clock, stepped five times a second.

\`\`\`seconds
Step: a fifth
Hand: blued steel
\`\`\`

## SERVICE

1. Let the mainspring down.
2. Clean, oil, **check the endshake**.
3. Regulate in three positions.

Now lay the parts out on the bench. Nothing stops on the way.

---

*Rendered from Markdown by*\\
\`react-native-enriched-markdown\`
`;

export const PART_NOTES: Record<PartId, string> = {
  barrel: `The barrel turns about once every ~~six~~ seven hours, so slowly that you will never catch it moving on a real watch. Here it is hurried along.

The spring is *S-shaped* before it goes in. Forced into a coil it pushes back almost evenly from fully wound to nearly flat, which is why a good watch keeps the same rate on **Monday morning and Tuesday night**.`,
  train: `Count the teeth and you can read the watch like a sum. Each wheel carries a small *pinion* on the same arbor; big wheel drives small pinion, and the speed climbs **sixty-fold in two steps**.

The wheels are brass because the pinions are steel. Unlike metals wear each other slowly, and ***slowly* is the whole point**. A train that is ~~silent~~ merely *quiet* is a well-made one.`,
  escapement: `The *Swiss lever* has barely changed since the 1750s. The fork **locks** a tooth, the balance comes back and knocks it free, the tooth slides down the pallet and gives the balance a shove on its way out.

*Lock, unlock, impulse, drop.* **Five times a second**, about four hundred and thirty thousand times a day, and every one of them is ***a collision***.`,
  balance: `A balance is a pendulum that does not care which way is down. The **hairspring**, thinner than a hair, pulls it back to centre from either side.

Its swing takes the same time whether it is wide or narrow. That stubbornness, *isochronism*, is what makes it **a clock**. Lose it, and you have only a ***very expensive bracelet***.`,
  rate: `Watchmakers used to check a movement against a *master clock* over a week. A timing machine does it in **thirty seconds**, by ear.

Two rows of dots mean the tick and the tock are not quite symmetrical. **Rising rows mean the watch is fast.** *Parallel and level* is what everyone at the bench is after, and a ***flat line*** is the best news a trace can give.`,
  seconds: `The small seconds hand rides directly on the **fourth wheel**. No extra gearing, nothing to add *play*: it is the most honest hand on the dial.

Watch it closely and you will see it does not sweep. It advances in **five small steps a second**, one for every tooth the escapement lets through. ~~Smooth~~ *Stepped* is how a mechanical watch tells the truth.`,
};

// The lines of a fenced block: `Key: value` pairs, in order.
export function parseSpecs(
  code: string
): Array<{ key: string; value: string }> {
  return code
    .split('\n')
    .map((line) => line.split(':'))
    .filter((pair) => pair.length >= 2)
    .map(([key, ...rest]) => ({
      key: (key ?? '').trim(),
      value: rest.join(':').trim(),
    }));
}

// The figures of one assembly, read back out of the document.
export function specsOf(id: PartId) {
  const fence = '```';
  const start = MOVEMENT_MARKDOWN.indexOf(`${fence}${id}\n`);
  if (start === -1) return [];
  const from = start + fence.length + id.length + 1;
  return parseSpecs(
    MOVEMENT_MARKDOWN.slice(from, MOVEMENT_MARKDOWN.indexOf(fence, from))
  );
}
