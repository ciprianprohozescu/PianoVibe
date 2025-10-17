// play/pause/tempo/mode/metronome
import * as Tone from "tone";
import useLessonStore from "../../store/useLessonStore";
import { schedulePlay } from "../../lib/midi/modeLogic";

export default function Transport() {
    const bpm = useLessonStore(s => s.bpm);
    const setBpm = useLessonStore(s => s.setBpm);
    const mode = useLessonStore(s => s.mode);
    const setMode = useLessonStore(s => s.setMode);
    const lesson = useLessonStore(s => s.lesson);

    const toggle = async () => {
        await Tone.start();
        if (Tone.Transport.state === "started") {
            Tone.Transport.pause();
        } else {
            if (lesson) schedulePlay(lesson);   // <-- add this line
            Tone.Transport.bpm.value = bpm;
            Tone.Transport.start();
        }
    };

    return (
        <div className="flex items-center gap-3">
            <button onClick={toggle} className="px-4 py-2 bg-blue-600 text-white rounded">Play/Pause</button>
            <label className="flex items-center gap-2">
                <span>BPM</span>
                <input type="number" value={bpm} onChange={(e)=>setBpm(+e.target.value || 120)} className="w-20 px-2 py-1 rounded bg-neutral-900 text-white"/>
            </label>
            <select value={mode} onChange={(e)=>setMode(e.target.value as any)} className="px-2 py-1 rounded bg-neutral-900 text-white">
                <option value="LEARN">Learn</option>
                <option value="PLAY">Play</option>
            </select>
        </div>
    );
}
