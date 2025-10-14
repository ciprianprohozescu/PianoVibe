// parse @tonejs/midi → normalized notes
import { Midi } from "@tonejs/midi";
import type { Lesson, NoteEvent } from "../utils/types";

export async function fileToArrayBuffer(file: File) {
    return await file.arrayBuffer();
}

export async function parseMidiFile(file: File): Promise<Lesson> {
    const data = await fileToArrayBuffer(file);
    const midi = new Midi(data);

    // basic metadata
    const bpm = midi.header.tempos[0]?.bpm ?? 120;
    const timeSig: [number, number] = midi.header.timeSignatures[0]
        ? [midi.header.timeSignatures[0].timeSignature[0], midi.header.timeSignatures[0].timeSignature[1]]
        : [4, 4];

    const notes: NoteEvent[] = [];
    for (const [tIdx, track] of midi.tracks.entries()) {
        for (const n of track.notes) {
            notes.push({
                pitch: n.midi,
                start: n.time,         // seconds (Tone time)
                end: n.time + n.duration,
                velocity: n.velocity,
                track: tIdx,
                channel: track.channel,
            });
        }
    }

    const duration = Math.max(...notes.map(n => n.end), 0);
    return { bpm, timeSig, notes, duration };
}
