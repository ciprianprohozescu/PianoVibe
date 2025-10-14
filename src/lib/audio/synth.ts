// Tone.js synth/players + routing
import * as Tone from "tone";

let piano: Tone.PolySynth | null = null;

export async function ensureAudio() {
    // required on first user gesture
    await Tone.start();
    if (!piano) {
        piano = new Tone.PolySynth(Tone.Synth).toDestination();
    }
    return piano!;
}

export function playNote(midi: number, durSec = 0.5, vel = 0.8, when = "+0") {
    if (!piano) return;
    const freq = Tone.Frequency(midi, "midi").toFrequency();
    piano.triggerAttackRelease(freq, durSec, when, vel);
}
