import FileLoader from "./components/Controls/FileLoader";
import Transport from "./components/Controls/Transport";
import MidiInputPicker from "./components/Controls/MidiInputPicker";
import PianoRoll from "./components/PianoRoll/PianoRoll";

export default function App() {
    return (
        <div className="min-h-screen bg-neutral-950 text-neutral-100 p-4 flex flex-col gap-4">
            <h1 className="text-2xl font-bold">Piano Vibe</h1>
            <div className="flex gap-3 items-center">
                <FileLoader />
                <MidiInputPicker />
                <Transport />
            </div>
            <div className="flex-1 border border-neutral-800 rounded-xl overflow-hidden">
                <PianoRoll />
            </div>
        </div>
    );
}
