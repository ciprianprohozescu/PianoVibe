export type NoteEvent = {
    pitch: number;           // MIDI number 21..108
    start: number;           // seconds
    end: number;             // seconds
    velocity: number;        // 0..1
    channel?: number;
    track?: number;
};

export type Lesson = {
    bpm: number;
    duration: number;
    notes: NoteEvent[];
    key?: string;
    timeSig?: [number, number];
};