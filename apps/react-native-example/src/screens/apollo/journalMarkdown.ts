export const PROMPT =
  'Walk me through the Apollo 11 landing, the last twelve minutes.';

export const LANDED_URL =
  'https://www.nasa.gov/wp-content/uploads/2015/01/590333main_ringtone_eagleHasLanded_extended.mp3';
export const SMALL_STEP_URL =
  'https://www.nasa.gov/wp-content/uploads/2015/01/590331main_ringtone_smallStep.mp3';

// Times are Ground Elapsed Time from the Apollo Lunar Surface Journal.
export const JOURNAL_MARKDOWN = `# The Eagle has landed

### APOLLO 11 · POWERED DESCENT · JULY 20, 1969

Twelve and a half minutes from the descent engine's ignition to the footpads touching the Moon, flown with a guidance computer that had **2,048 words** of working memory.

## The last twelve minutes

\`\`\`timeline
102:33:05  IGNITION  The descent engine lights up
102:38:26  ALARM     1202, the computer is overloaded
102:38:53  GO        "We're Go on that alarm"
102:43     MANUAL    Armstrong flies past a boulder field
102:45:40  CONTACT   Contact light
\`\`\`

*"It's a 1202."* Nobody on board knew what that meant. In Houston, guidance officer Steve Bales checked it against the back room's list of alarm codes, and the landing went on.

## Why the computer kept flying

\`\`\`flowchart
radar[Radar data floods the computer] --> busy[Every core set is taken]
busy --> alarm{1202}
alarm --> restart[Software restarts]
restart --> guide[Landing guidance keeps running]
restart --> wait[Low-priority jobs wait]
\`\`\`

The software from the MIT Instrumentation Lab, where Margaret Hamilton led the flight software team, was built for exactly this: restart, drop the work that can wait, and keep flying.

## Down to the surface

\`\`\`chart
102:43:01  ALT 750  DOWN 23
102:43:11  ALT 600  DOWN 19
102:43:26  ALT 400  DOWN 9    FWD 58
102:43:46  ALT 300  DOWN 3.5  FWD 47
102:44:00  FUEL 8
102:44:07  ALT 250  DOWN 2.5  FWD 19
102:44:24  ALT 200  DOWN 4.5
102:44:45  ALT 100  DOWN 3.5  FWD 9   FUEL 5
102:45:02  CALL 60 SECONDS
102:45:08  ALT 60   DOWN 2.5  FWD 2
102:45:17  ALT 40   DOWN 2.5  DUST
102:45:25  ALT 20   DOWN 0.5  FWD 4
102:45:31  CALL 30 SECONDS
102:45:40  CONTACT LIGHT
\`\`\`

*"60 seconds"* was Charlie Duke counting down to bingo, the call that leaves twenty seconds to land or abort. The contact light came on with about twenty seconds to spare.

## 102:45 · Tranquility Base

Engine stop. Eighteen seconds later, on the air-to-ground loop:

[Tranquility Base here](${LANDED_URL} "102:45:58 · Armstrong, then Duke at CAPCOM")

The descent stage is still there, at 0.674° N, 23.473° E.
`;
