// MIDI upload
import { parseMidiFile } from "../../lib/midi/parseMidi";
import useLessonStore from "../../store/useLessonStore";

export default function FileLoader() {
    const setLesson = useLessonStore(s => s.setLesson);
    return (
        <label className="cursor-pointer">
            <input
                type="file"
                accept=".mid,.midi"
                className="hidden"
                onChange={async (e) => {
                    const file = e.target.files?.[0];
                    if (!file) return;
                    const lesson = await parseMidiFile(file);
                    setLesson(lesson);
                }}
            />
            <span className="px-3 py-2 rounded bg-neutral-800 text-white">Upload MIDI</span>
        </label>
    );
}
