export type NoteEvent = {
    pitch: number;          // MIDI note number 0–127
    startTick: number;
    endTick: number;
    channel: number;
    velocity: number;       // on-velocity
    startMs?: number;       // filled after normalization
    endMs?: number;         // filled after normalization
};

export type Track = {
    name?: string;
    events: NoteEvent[];
};

export type TempoChange = {
    atTick: number;
    bpm: number;
};

export type Song = {
    format: number;         // 0, 1, or 2
    tracks: Track[];
    ppq: number;            // pulses per quarter note (ticks per quarter)
    tempoMap: TempoChange[];
    durationTicks: number;
    durationMs: number;
};