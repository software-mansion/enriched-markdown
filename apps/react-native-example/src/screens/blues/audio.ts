import { useSyncExternalStore } from 'react';
import { makeMutable } from 'react-native-reanimated';
import {
  AudioContext,
  AudioManager,
  type AudioBuffer,
  type AnalyserNode,
  type GainNode,
  type OscillatorNode,
  type PeriodicWave,
} from 'react-native-audio-api';
import {
  hz,
  roomImpulse,
  softClipCurve,
  whiteNoise,
} from '../jazz/audio/synth';
import { PIANO_SAMPLES } from './piano';

// The lesson's band: a sampled grand piano, a synthesized bass and kit, behind
// one transport. A loop is a function asked for each swung eighth just ahead
// of time; the transport's clock is mirrored into a shared value so the cells
// can draw playheads on the UI thread without asking JS.

export const BPM = 92;
// A shuffle: the off-beat eighth lands two thirds of the way through the beat.
export const SWING = 2 / 3;
export const STEPS_PER_BAR = 8;
const BEAT = 60 / BPM;
// How far ahead the scheduler books notes, so a busy JS thread (the answer is
// still streaming) never makes the band stumble.
const LOOKAHEAD = 0.3;
const TICK_MS = 25;

export type Drum = 'kick' | 'snare' | 'hat';

export interface Loop {
  id: string;
  // Swung eighths before the loop comes round.
  steps: number;
  // Books step `step` (already wrapped) to sound at `at`, context seconds.
  onStep: (step: number, at: number) => void;
}

export interface Transport {
  id: string | null;
  // `Date.now()` of step 0.
  startedAt: number;
  beatMs: number;
  steps: number;
}

export const transport = makeMutable<Transport>({
  id: null,
  startedAt: 0,
  beatMs: BEAT * 1000,
  steps: 8,
});

/** The swung eighth sounding at `now` (ms), or -1 before the loop starts. */
export function stepAt(t: Transport, now: number) {
  'worklet';
  const elapsed = now - t.startedAt;
  if (t.id === null || elapsed < 0) return -1;
  const beat = Math.floor(elapsed / t.beatMs);
  const sub = (elapsed - beat * t.beatMs) / t.beatMs >= SWING ? 1 : 0;
  return (beat * 2 + sub) % t.steps;
}

/** Seconds from step 0 to swung eighth `step`. */
export function stepTime(step: number) {
  return Math.floor(step / 2) * BEAT + (step % 2) * SWING * BEAT;
}

// The partials of a felt-hammered string, as one periodic wave.
const PIANO_PARTIALS = [0, 1, 0.42, 0.24, 0.16, 0.08, 0.05, 0.03, 0.02];

export interface Held {
  setPitch: (voice: number, midi: number) => void;
  release: () => void;
}

class BluesEngine {
  private ctx: AudioContext | null = null;
  private input!: GainNode;
  private analyser!: AnalyserNode;
  private noise!: AudioBuffer;
  private wave!: PeriodicWave;
  // The piano's samples by root note, as they finish decoding.
  private samples = new Map<number, AudioBuffer>();

  private loop: Loop | null = null;
  private loopStart = 0;
  private nextStep = 0;
  private timer: ReturnType<typeof setInterval> | null = null;
  private listeners = new Set<() => void>();

  context() {
    if (this.ctx) return this.ctx;
    AudioManager.setAudioSessionOptions({
      iosCategory: 'playback',
      iosMode: 'default',
      iosOptions: [],
    });
    // One context for the app's life: in react-native-audio-api 0.13.6 a
    // context freed on the audio thread (a Fast Refresh orphans the old one)
    // deadlocks the engine, and every later call from JS hangs.
    const shared = globalThis as { __bluesContext?: AudioContext };
    shared.__bluesContext ??= new AudioContext();
    const ctx = shared.__bluesContext;
    this.input = ctx.createGain();
    this.input.gain.value = 0.8;
    // One chain, no splits: a node feeding two inputs only reaches the last
    // one in react-native-audio-api 0.13, so the room carries the dry sound.
    const room = ctx.createConvolver();
    room.normalize = false;
    room.buffer = roomImpulse(ctx, 0.22, 1.6);
    const tone = ctx.createBiquadFilter();
    tone.type = 'lowpass';
    tone.frequency.value = 9000;
    const shaper = ctx.createWaveShaper();
    shaper.curve = softClipCurve();
    this.input.connect(room);
    room.connect(tone);
    tone.connect(shaper);
    // The last link before the speaker, so the scope sees what you hear.
    this.analyser = ctx.createAnalyser();
    this.analyser.fftSize = 1024;
    shaper.connect(this.analyser);
    this.analyser.connect(ctx.destination);

    this.noise = whiteNoise(ctx);
    const real = new Float32Array(PIANO_PARTIALS.length);
    this.wave = ctx.createPeriodicWave(real, Float32Array.from(PIANO_PARTIALS));
    this.ctx = ctx;
    for (const [root, asset] of Object.entries(PIANO_SAMPLES)) {
      ctx
        .decodeAudioData(asset)
        .then((buffer) => this.samples.set(Number(root), buffer))
        .catch(() => {});
    }
    return ctx;
  }

  private ready() {
    const ctx = this.context();
    if (ctx.state !== 'running') ctx.resume();
    return ctx;
  }

  /** The output's latest waveform, -1 to 1, into `out`; false before sound. */
  readWaveform(out: Float32Array) {
    if (!this.ctx) return false;
    this.analyser.getFloatTimeDomainData(out);
    return true;
  }

  /** `Date.now()` at `at` on the audio clock. */
  wall(at: number) {
    const ctx = this.context();
    return Date.now() + (at - ctx.currentTime) * 1000;
  }

  now() {
    return this.ready().currentTime + 0.03;
  }

  // ── Voices ───────────────────────────────────────────────────────────────

  /** The decoded sample nearest `midi`, within a minor third. */
  private sample(midi: number) {
    let best: number | null = null;
    for (const root of this.samples.keys()) {
      if (best === null || Math.abs(root - midi) < Math.abs(best - midi)) {
        best = root;
      }
    }
    if (best === null || Math.abs(best - midi) > 3) return null;
    return { buffer: this.samples.get(best)!, root: best };
  }

  // A key struck at `vel`: louder and brighter the harder it's hit.
  private strike(midi: number, at: number, vel: number) {
    const ctx = this.ready();
    const found = this.sample(midi);
    if (!found) return null;
    const source = ctx.createBufferSource();
    source.buffer = found.buffer;
    source.playbackRate.value = 2 ** ((midi - found.root) / 12);
    const tone = ctx.createBiquadFilter();
    tone.type = 'lowpass';
    tone.frequency.value = 1800 + vel * vel * 9000;
    const amp = ctx.createGain();
    amp.gain.setValueAtTime(0.75 * vel, at);
    source.connect(tone);
    tone.connect(amp);
    amp.connect(this.input);
    source.start(at);
    return { source, amp, root: found.root };
  }

  /** A note on the grand, damped `len` seconds after it's struck. */
  piano(midi: number, at = this.now(), len = 0.9, vel = 0.8) {
    const key = this.strike(midi, at, vel);
    if (!key) {
      this.synthPiano(midi, at, len, vel);
      return;
    }
    key.amp.gain.setTargetAtTime(0, at + len, 0.12);
    key.source.stop(at + len + 1);
  }

  // The piano until its samples have decoded.
  private synthPiano(midi: number, at: number, len: number, vel: number) {
    const ctx = this.ready();
    const f = hz(midi);
    const tone = ctx.createBiquadFilter();
    tone.type = 'lowpass';
    tone.frequency.setValueAtTime(Math.min(f * 10 + 1500, 12000), at);
    tone.frequency.setTargetAtTime(f * 3 + 500, at + 0.01, 0.35);
    const amp = ctx.createGain();
    amp.gain.setValueAtTime(0, at);
    amp.gain.linearRampToValueAtTime(0.16 * vel, at + 0.004);
    amp.gain.setTargetAtTime(0.07 * vel, at + 0.004, 0.3);
    amp.gain.setTargetAtTime(0, at + len, 0.14);
    [0, 3.5].forEach((detune) => {
      const osc = ctx.createOscillator();
      osc.setPeriodicWave(this.wave);
      osc.frequency.value = f;
      osc.detune.value = detune;
      osc.connect(tone);
      osc.start(at);
      osc.stop(at + len + 1);
    });
    tone.connect(amp);
    amp.connect(this.input);
  }

  bass(midi: number, at: number, len: number, vel = 0.8) {
    const ctx = this.ready();
    const osc = ctx.createOscillator();
    osc.type = 'triangle';
    osc.frequency.value = hz(midi);
    const tone = ctx.createBiquadFilter();
    tone.type = 'lowpass';
    tone.frequency.setValueAtTime(900, at);
    tone.frequency.setTargetAtTime(320, at, 0.08);
    const amp = ctx.createGain();
    amp.gain.setValueAtTime(0, at);
    amp.gain.linearRampToValueAtTime(0.5 * vel, at + 0.008);
    amp.gain.setTargetAtTime(0.28 * vel, at + 0.008, 0.15);
    amp.gain.setTargetAtTime(0, at + len, 0.04);
    osc.connect(tone);
    tone.connect(amp);
    amp.connect(this.input);
    osc.start(at);
    osc.stop(at + len + 0.4);
  }

  drum(drum: Drum, at = this.now(), vel = 1) {
    const ctx = this.ready();
    const hit = (
      type: 'highpass' | 'bandpass',
      frequency: number,
      peak: number,
      decay: number
    ) => {
      const source = ctx.createBufferSource();
      source.buffer = this.noise;
      const filter = ctx.createBiquadFilter();
      filter.type = type;
      filter.frequency.value = frequency;
      filter.Q.value = 0.8;
      const gain = ctx.createGain();
      gain.gain.setValueAtTime(peak * vel, at);
      gain.gain.setTargetAtTime(0, at + 0.002, decay);
      source.connect(filter);
      filter.connect(gain);
      gain.connect(this.input);
      source.start(at, Math.random() * 1.5);
      source.stop(at + decay * 7);
    };
    const thump = (from: number, to: number, peak: number, decay: number) => {
      const osc = ctx.createOscillator();
      osc.frequency.setValueAtTime(from, at);
      osc.frequency.exponentialRampToValueAtTime(to, at + 0.09);
      const gain = ctx.createGain();
      gain.gain.setValueAtTime(peak * vel, at);
      gain.gain.setTargetAtTime(0, at + 0.004, decay);
      osc.connect(gain);
      gain.connect(this.input);
      osc.start(at);
      osc.stop(at + decay * 7);
    };
    if (drum === 'kick') thump(150, 46, 0.9, 0.11);
    if (drum === 'snare') {
      hit('bandpass', 1900, 0.5, 0.06);
      thump(230, 170, 0.25, 0.04);
    }
    if (drum === 'hat') hit('highpass', 7500, 0.22, 0.018);
  }

  /** A chord that sounds until released, its voices free to slide. */
  hold(midis: number[]): Held {
    const ctx = this.ready();
    const at = ctx.currentTime + 0.02;
    const keys = midis.map((midi) => this.strike(midi, at, 0.7));
    if (keys.every((key) => key !== null)) {
      // A voice slides by playing its sample faster or slower.
      return {
        setPitch: (voice, midi) => {
          const key = keys[voice];
          key?.source.playbackRate.setTargetAtTime(
            2 ** ((midi - key.root) / 12),
            ctx.currentTime,
            0.015
          );
        },
        release: () => {
          const now = ctx.currentTime;
          for (const key of keys) {
            key.amp.gain.cancelScheduledValues(now);
            key.amp.gain.setTargetAtTime(0, now, 0.12);
            key.source.stop(now + 1);
          }
        },
      };
    }
    for (const key of keys) key?.source.stop(at);
    const amp = ctx.createGain();
    amp.gain.setValueAtTime(0, at);
    amp.gain.linearRampToValueAtTime(0.13, at + 0.01);
    amp.gain.setTargetAtTime(0.07, at + 0.01, 0.5);
    const tone = ctx.createBiquadFilter();
    tone.type = 'lowpass';
    tone.frequency.value = 2600;
    tone.connect(amp);
    amp.connect(this.input);
    const voices: OscillatorNode[][] = midis.map((midi) =>
      [0, 4].map((detune) => {
        const osc = ctx.createOscillator();
        osc.setPeriodicWave(this.wave);
        osc.frequency.value = hz(midi);
        osc.detune.value = detune;
        osc.connect(tone);
        osc.start(at);
        return osc;
      })
    );
    return {
      setPitch: (voice, midi) => {
        const now = ctx.currentTime;
        for (const osc of voices[voice] ?? []) {
          osc.frequency.setTargetAtTime(hz(midi), now, 0.015);
        }
      },
      release: () => {
        const now = ctx.currentTime;
        amp.gain.cancelScheduledValues(now);
        amp.gain.setTargetAtTime(0, now, 0.12);
        for (const osc of voices.flat()) osc.stop(now + 1);
      },
    };
  }

  // ── Transport ────────────────────────────────────────────────────────────

  get playing() {
    return this.loop?.id ?? null;
  }

  /** Context time of the next downbeat, or right away when nothing plays. */
  nextBar() {
    const ctx = this.ready();
    if (!this.loop) return ctx.currentTime + 0.06;
    const bar = Math.ceil(this.nextStep / STEPS_PER_BAR) * STEPS_PER_BAR;
    return this.loopStart + this.stepOffset(bar);
  }

  /** Context time of the next beat, or right away when nothing plays. */
  nextBeat() {
    return this.nextPulse(BEAT);
  }

  /** Milliseconds to the next downbeat while the band plays, else 0. */
  msToNextBar() {
    if (!this.loop || !this.ctx) return 0;
    return (this.nextPulse(BEAT * 4) - this.ctx.currentTime) * 1000;
  }

  // By the clock rather than the scheduler, which books 0.3 s ahead.
  private nextPulse(period: number) {
    const ctx = this.ready();
    if (!this.loop) return ctx.currentTime + 0.03;
    const elapsed = ctx.currentTime + 0.02 - this.loopStart;
    return this.loopStart + Math.max(0, Math.ceil(elapsed / period)) * period;
  }

  // Seconds from the loop's start to absolute step `step`, across bars.
  private stepOffset(step: number) {
    return stepTime(step);
  }

  /**
   * Starts `loop`. A loop already playing hands over on its next downbeat, so
   * the band comes in on the one rather than mid-bar.
   */
  play(loop: Loop) {
    const start = this.nextBar();
    this.loop = loop;
    this.loopStart = start;
    this.nextStep = 0;
    transport.value = {
      id: loop.id,
      startedAt: this.wall(start),
      beatMs: BEAT * 1000,
      steps: loop.steps,
    };
    if (!this.timer) {
      this.timer = setInterval(() => this.schedule(), TICK_MS);
    }
    this.schedule();
    this.emit();
  }

  stop(id?: string) {
    if (id !== undefined && this.loop?.id !== id) return;
    this.loop = null;
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    transport.value = { ...transport.value, id: null };
    this.emit();
  }

  private schedule() {
    const loop = this.loop;
    const ctx = this.ctx;
    if (!loop || !ctx) return;
    const horizon = ctx.currentTime + LOOKAHEAD;
    for (;;) {
      const at = this.loopStart + this.stepOffset(this.nextStep);
      if (at >= horizon) break;
      if (at > ctx.currentTime - 0.02) {
        loop.onStep(this.nextStep % loop.steps, at);
      }
      this.nextStep++;
    }
  }

  // A drum part the reader wrote (or edited) in the groove, for the band.
  groove: Record<Drum, string> = {
    kick: 'x...x...',
    snare: '..x...x.',
    hat: 'xoxoxoxo',
  };

  playGrooveStep(step: number, at: number, rows = this.groove) {
    for (const drum of ['kick', 'snare', 'hat'] as Drum[]) {
      const cell = rows[drum][step % STEPS_PER_BAR];
      if (cell === 'x') this.drum(drum, at, 1);
      if (cell === 'o') this.drum(drum, at, 0.45);
    }
  }

  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  private emit() {
    for (const listener of this.listeners) listener();
  }
}

export const engine = new BluesEngine();

/** The id of the loop playing, as React state. */
export function usePlaying() {
  return useSyncExternalStore(engine.subscribe, () => engine.playing);
}

export const STEP_SECONDS = BEAT / 2;
