// select input device
import { useEffect, useState } from "react";
import { enableMidi, bindInput } from "../../lib/midi/input";
import useLessonStore from "../../store/useLessonStore";

export default function MidiInputPicker() {
    const [devices, setDevices] = useState<{ id: string; name: string }[]>([]);
    const setIncomingNote = useLessonStore(s => s.handleIncomingNote);

    useEffect(() => {
        (async () => {
            try {
                const inputs = await enableMidi();
                setDevices(inputs.map(i => ({ id: i.id, name: i.name || "MIDI Device" })));
            } catch {
                setDevices([]);
            }
        })();
    }, []);

    const onSelect = (e: React.ChangeEvent<HTMLSelectElement>) => {
        const id = e.target.value;
        const unbind = bindInput(id, ({ midi, on, velocity }) => {
            setIncomingNote({ midi, on, velocity });
        });
        // optional: store unbind for cleanup
    };

    return (
        <select onChange={onSelect} className="px-2 py-1 rounded bg-neutral-900 text-white">
            <option value="">Select MIDI input…</option>
            {devices.map(d => <option key={d.id} value={d.id}>{d.name}</option>)}
        </select>
    );
}
