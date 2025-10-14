// webmidi wrapper
import { WebMidi, Input, type NoteMessageEvent } from "webmidi";

export type MidiNoteHandler = (opts: { midi: number; on: boolean; velocity?: number; timestamp: number }) => void;

export async function enableMidi() {
    if (!WebMidi.enabled) {
        await WebMidi.enable();
    }
    return WebMidi.inputs;
}

export function bindInput(inputId: string, onNote: MidiNoteHandler) {
    const input: Input | undefined = WebMidi.inputs.find(i => i.id === inputId);
    if (!input) throw new Error("MIDI input not found");
    const noteOn = (e: NoteMessageEvent) => onNote({ midi: e.note.number, on: true, velocity: e.note.attack, timestamp: e.timestamp });
    const noteOff = (e: NoteMessageEvent) => onNote({ midi: e.note.number, on: false, timestamp: e.timestamp });
    input.addListener("noteon", noteOn);
    input.addListener("noteoff", noteOff);
    return () => {
        input.removeListener("noteon", noteOn);
        input.removeListener("noteoff", noteOff);
    };
}
