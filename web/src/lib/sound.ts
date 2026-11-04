// Short, close table sounds synthesized at runtime (no audio files), ported
// from the deleted Godot table. Sound is never the only signal for anything:
// every cue matches something already visible on the table.
import { settings } from "./settings.svelte";

export type SoundKind = "deal" | "flip" | "chips" | "turn" | "pot" | "win";

const RATE = 22050;
let context: AudioContext | null = null;
const buffers = new Map<SoundKind, AudioBuffer>();

/** Browsers start audio suspended until a user gesture; call from one. */
export function unlockAudio(): void {
  if (!context) {
    const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctor) return;
    context = new Ctor();
  }
  if (context.state === "suspended") void context.resume();
}

/** Play `kind` after `delayMs`. Silently does nothing when muted or locked. */
export function play(kind: SoundKind, delayMs = 0): void {
  if (import.meta.env.DEV) {
    (window as unknown as { __soundLog?: string[] }).__soundLog?.push(kind);
  }
  if (!settings.soundOn || settings.volume <= 0 || !context || context.state !== "running") return;
  const source = context.createBufferSource();
  source.buffer = buffer(kind, context);
  const gain = context.createGain();
  // Squared slider feels even; 0.7 is about -18 dB, the old table's default.
  gain.gain.value = 0.25 * settings.volume * settings.volume;
  source.connect(gain).connect(context.destination);
  source.start(context.currentTime + delayMs / 1000);
}

function buffer(kind: SoundKind, ctx: AudioContext): AudioBuffer {
  let cached = buffers.get(kind);
  if (!cached) {
    const samples = synthesize(kind);
    cached = ctx.createBuffer(1, samples.length, RATE);
    cached.copyToChannel(samples, 0);
    buffers.set(kind, cached);
  }
  return cached;
}

const DURATION: Record<SoundKind, number> = {
  deal: 0.095,
  flip: 0.105,
  chips: 0.22,
  turn: 0.32,
  pot: 0.28,
  win: 0.42,
};
const PULSES: Record<SoundKind, number[]> = {
  deal: [],
  flip: [0, 0.038],
  chips: [0, 0.045, 0.091, 0.143],
  turn: [0, 0.16],
  pot: [0, 0.055, 0.115, 0.18],
  win: [0, 0.055, 0.115, 0.18],
};
const RESONANCE: Record<SoundKind, number> = {
  deal: 1250,
  flip: 1750,
  chips: 1480,
  turn: 760,
  pot: 1050,
  win: 1050,
};

/** Seeded so each cue sounds the same every time. */
function rng(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 0x100000000;
  };
}

function synthesize(kind: SoundKind): Float32Array<ArrayBuffer> {
  const duration = DURATION[kind];
  const total = Math.floor(RATE * duration);
  const out = new Float32Array(new ArrayBuffer(total * 4));
  const random = rng([...kind].reduce((h, c) => h * 31 + c.charCodeAt(0), 7));
  const decay = kind === "turn" ? 48 : 72;
  let lowpass = 0;
  for (let i = 0; i < total; i++) {
    const t = i / RATE;
    let transient = 0;
    for (const p of PULSES[kind]) if (t >= p) transient += Math.exp(-(t - p) * decay);
    const noise = random() * 2 - 1;
    lowpass += (noise - lowpass) * 0.32;
    let sample: number;
    if (kind === "deal") {
      const swish = Math.sin(Math.PI * Math.min(1, t / duration));
      sample = (noise * 0.72 + lowpass * 0.28) * Math.pow(swish, 0.55) * 0.34;
      sample += Math.sin(2 * Math.PI * RESONANCE.deal * t) * Math.exp(-t * 45) * 0.045;
    } else {
      sample = (noise * 0.62 + lowpass * 0.38) * transient * 0.27;
      sample += Math.sin(2 * Math.PI * RESONANCE[kind] * t) * transient * 0.11;
    }
    if (kind === "win" && t > 0.2) {
      // A small rising two-note chime after the chips settle.
      const a = t - 0.2;
      const tone = Math.sin(2 * Math.PI * 880 * a) * 0.6 + Math.sin(2 * Math.PI * 1320 * Math.max(0, a - 0.08)) * (a > 0.08 ? 0.5 : 0);
      sample += tone * Math.exp(-a * 14) * 0.12;
    }
    out[i] = Math.max(-1, Math.min(1, sample));
  }
  return out;
}
