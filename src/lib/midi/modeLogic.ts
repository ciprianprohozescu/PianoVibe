// LEARN vs PLAY logic
import * as Tone from "tone";
import type { Lesson, NoteEvent } from "../utils/types";
import { playNote } from "../audio/synth";

export function schedulePlay(lesson: Lesson) {
    // Clear old events
    Tone.Transport.cancel(0);
    // Schedule each note
    for (const n of lesson.notes) {
        Tone.Transport.schedule((time) => {
            playNote(n.pitch, n.end - n.start, n.velocity, time.toString());
        }, n.start);
    }
}

export function* learnIterator(lesson: Lesson) {
    // naive grouping by start time
    const groups = groupByStart(lesson.notes, 0.02);
    for (const g of groups) yield g; // each group is array<NoteEvent>
}

function groupByStart(notes: NoteEvent[], eps=0.02): NoteEvent[][] {
    const sorted = [...notes].sort((a,b)=>a.start-b.start);
    const out: NoteEvent[][] = [];
    let bucket: NoteEvent[] = [];
    let t0 = -1;
    for (const n of sorted) {
        if (t0 < 0 || Math.abs(n.start - t0) <= eps) {
            bucket.push(n); t0 = t0<0? n.start : t0;
        } else {
            out.push(bucket); bucket = [n]; t0 = n.start;
        }
    }
    if (bucket.length) out.push(bucket);
    return out;
}
