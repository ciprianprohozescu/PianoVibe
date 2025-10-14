// global store
import create from "zustand";
import type { Lesson } from "../lib/utils/types";

type Mode = "LEARN" | "PLAY";

type Incoming = { midi: number; on: boolean; velocity?: number };

type LessonState = {
    lesson: Lesson | null;
    mode: Mode;
    bpm: number;
    setLesson: (l: Lesson) => void;
    setMode: (m: Mode) => void;
    setBpm: (b: number) => void;
    handleIncomingNote: (e: Incoming) => void;
};

const useLessonStore = create<LessonState>((set, get) => ({
    lesson: null,
    mode: "LEARN",
    bpm: 120,
    setLesson: (l) => set({ lesson: l, bpm: l.bpm || 120 }),
    setMode: (m) => set({ mode: m }),
    setBpm: (b) => set({ bpm: b }),
    handleIncomingNote: ({ midi, on }) => {
        if (!on) return;
        const { mode } = get();
        // TODO: update scoring/advance LEARN, highlight hit in PIXI, etc.
        console.log("MIDI IN", midi, mode);
    },
}));

export default useLessonStore;
