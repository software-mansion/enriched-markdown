import { useSyncExternalStore } from 'react';
import {
  AudioContext,
  AudioManager,
  type AudioBuffer,
  type AudioBufferSourceNode,
} from 'react-native-audio-api';
import { LANDED_URL, SMALL_STEP_URL } from './journalMarkdown';

export const ENVELOPE_RATE = 30;
// Air-to-ground audio is quiet and compressed; this brings it up to the
// meters' range.
const METER_GAIN = 3.2;

// [seconds into the clip, word]; a word lights when its time comes.
type Word = [number, string];

export interface Line {
  who: 'ARMSTRONG' | 'DUKE';
  words: Word[];
}

export interface Loop {
  url: string;
  // The loop the transmission went out on, as Mission Control labelled it.
  loop: string;
  lines: Line[];
  // Only the landing call plays by itself, as its card lands.
  autoCue: boolean;
}

// NASA's public-domain clips. Words are timed by speech recognition against
// the clip; the text is the Apollo Lunar Surface Journal's transcript.
export const LOOPS: Loop[] = [
  {
    url: LANDED_URL,
    loop: 'AIR-TO-GROUND',
    autoCue: false,
    // prettier-ignore
    lines: [
      { who: 'ARMSTRONG', words: [[0.35, 'Houston,'], [2.75, 'Tranquility'], [3.74, 'Base'], [4.27, 'here.']] },
      { who: 'ARMSTRONG', words: [[4.91, 'The'], [5.11, 'Eagle'], [5.36, 'has'], [5.57, 'landed.']] },
      { who: 'DUKE', words: [[6.0, 'Roger,'], [7.0, 'Twan…'], [7.4, 'Tranquility.'], [8.35, 'We'], [8.48, 'copy'], [8.75, 'you'], [8.95, 'on'], [9.08, 'the'], [9.28, 'ground.']] },
      { who: 'DUKE', words: [[10.0, 'You'], [10.16, 'got'], [10.32, 'a'], [10.37, 'bunch'], [10.64, 'of'], [10.79, 'guys'], [10.97, 'about'], [11.24, 'to'], [11.35, 'turn'], [11.54, 'blue.']] },
      { who: 'DUKE', words: [[12.0, "We're"], [12.22, 'breathing'], [12.62, 'again.'], [13.0, 'Thanks'], [13.59, 'a'], [13.69, 'lot.']] },
    ],
  },
  {
    url: SMALL_STEP_URL,
    loop: 'EVA',
    autoCue: false,
    // prettier-ignore
    lines: [
      { who: 'ARMSTRONG', words: [[0.06, "I'm"], [0.25, 'going'], [0.45, 'to'], [0.62, 'step'], [0.97, 'off'], [1.21, 'the'], [1.41, 'LM'], [1.72, 'now.']] },
      { who: 'ARMSTRONG', words: [[4.0, "That's"], [4.03, 'one'], [4.06, 'small'], [4.22, 'step'], [4.65, 'for'], [4.9, '(a)'], [5.09, 'man;']] },
      { who: 'ARMSTRONG', words: [[9.0, 'one'], [9.05, 'giant'], [9.11, 'leap'], [9.34, 'for'], [10.07, 'mankind.']] },
    ],
  },
];

export function loopFor(url: string) {
  return LOOPS.find((loop) => loop.url === url);
}

// What the UI thread needs to follow a clip without asking JS.
export interface Timeline {
  url: string;
  // `Date.now()` when the first sample is heard.
  startedAt: number;
  length: number;
  envelope: number[];
}

interface Decoded {
  buffer: AudioBuffer;
  envelope: number[];
}

function loudness(buffer: AudioBuffer) {
  const data = buffer.getChannelData(0);
  const window = Math.floor(buffer.sampleRate / ENVELOPE_RATE);
  const envelope: number[] = [];
  for (let from = 0; from < data.length; from += window) {
    const to = Math.min(data.length, from + window);
    let sum = 0;
    for (let i = from; i < to; i++) sum += data[i]! * data[i]!;
    envelope.push(Math.min(1, Math.sqrt(sum / (to - from)) * METER_GAIN));
  }
  return envelope;
}

// One loop on the speaker at a time: starting one stops the one before it.
class LoopPlayer {
  private ctx: AudioContext | null = null;
  private decoded = new Map<string, Promise<Decoded>>();
  private source: AudioBufferSourceNode | null = null;
  // Bumped on every play and stop, so a clip that finishes decoding late does
  // not start over whatever was asked for since.
  private request = 0;
  private listeners = new Set<() => void>();
  timeline: Timeline | null = null;
  // While the journal is being written, a card that auto-cues plays as it
  // lands; once it has, it does not cue again until the next run.
  autoCue = false;
  cued = new Set<string>();

  private context() {
    if (this.ctx) return this.ctx;
    AudioManager.setAudioSessionOptions({
      iosCategory: 'playback',
      iosMode: 'spokenAudio',
      iosOptions: [],
    });
    this.ctx = new AudioContext();
    return this.ctx;
  }

  private clip(ctx: AudioContext, url: string) {
    let clip = this.decoded.get(url);
    if (!clip) {
      clip = ctx.decodeAudioData(url).then((buffer) => {
        if (!buffer) throw new Error(`Could not decode ${url}`);
        return { buffer, envelope: loudness(buffer) };
      });
      clip.catch(() => this.decoded.delete(url));
      this.decoded.set(url, clip);
    }
    return clip;
  }

  prefetch() {
    const ctx = this.context();
    for (const { url } of LOOPS) this.clip(ctx, url).catch(() => {});
  }

  async play(url: string) {
    this.stop();
    const request = this.request;
    const ctx = this.context();
    await ctx.resume();
    const { buffer, envelope } = await this.clip(ctx, url);
    if (request !== this.request) return;
    const source = ctx.createBufferSource();
    source.buffer = buffer;
    source.connect(ctx.destination);
    const start = ctx.currentTime + 0.05;
    source.start(start);
    source.onEnded = () => {
      if (this.source === source) this.stop();
    };
    this.source = source;
    this.timeline = {
      url,
      startedAt: Date.now() + (start - ctx.currentTime) * 1000,
      length: buffer.duration,
      envelope,
    };
    this.emit();
  }

  stop() {
    this.request++;
    const source = this.source;
    if (!source) return;
    this.source = null;
    this.timeline = null;
    source.stop();
    this.emit();
  }

  toggle(url: string) {
    if (this.timeline?.url === url) this.stop();
    else this.play(url);
  }

  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  private emit() {
    this.listeners.forEach((listener) => listener());
  }
}

export const loopPlayer = new LoopPlayer();

export function usePlaying() {
  return useSyncExternalStore(loopPlayer.subscribe, () => loopPlayer.timeline);
}
