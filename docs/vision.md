You are the composer for this Flutter repo. Goal: a piano-learning MVP that loads a .mid file, normalizes it to a Lesson model (notes with absolute seconds + tempo map), shows falling bars over a keyboard, and supports two modes:

Learn: waits for correct chord/step before advancing.

Play: runs on fixed tempo, scores hits/misses in ±80ms window.

Architecture

State: Riverpod.

Packages: dart_midi (parse), flutter_midi_command (BLE/USB MIDI), file_picker, collection, path.

Modules:

features/midi/ – device discovery, connect, input stream (NoteOn/Off + sustain).

features/lesson/ – MIDI→Lesson normalization, tempo map (ticks→seconds), sections (by bars).

features/render/ – CustomPainter falling bars + static keyboard, driven by a ticker.

features/practice/ – Learn/Play controllers (scheduler + matcher + scoring).

UI: single Home screen with tabs: Import, Connect, Practice.

Latency: single latencyMs setting applied to matching windows (we’ll calibrate later).

Deliverables (MVP)

Replace the default counter app with: tabs (Import / Devices / Practice).

Import: pick a .mid, parse with dart_midi, create Lesson:

type Note = { pitch:int; t0:double; t1:double; velocity:int; hand:'L'|'R'|'U'; bar:int; sectionId:String; };
type Lesson = {
  bpm: double;
  tempoMap: List<{t:double; bpm:double}>;
  notes: List<Note>;
  sections: List<{id:String; start:double; end:double; bars:(int,int);}>;
  timeSig:(int,int)?;
  keySig:String?;
};


Sustain (CC64) extends note offs in normalization.

Simple hands heuristic by pitch threshold (configurable).

Devices: list BLE/USB MIDI devices, connect/disconnect, log NoteOn/Off.

Practice:

Renderer: falling bars with CustomPainter; y= time to hit (0 at keyboard line). Visible window [t, t+5s]. Color by hand.

Play mode: transport (play/pause), metronome click (simple Ticker first), scoring overlays (hit/miss).

Learn mode: step through simultaneities (same start time), advance when all expected pitches are pressed.

Riverpod providers for: lessonProvider, practiceClockProvider, midiInputProvider, deviceConnectionProvider, latencyProvider.

Tests: tempo map conversion and stepper logic.

Constraints

Keep paint() allocations zero or minimal (no TextPainter per frame).

Convert MIDI ticks→seconds once at load (cache in Lesson).

Don’t block UI thread; use Ticker for frame time.

Small, well-named files; no god widgets.

Start by generating files and implementations. Show a diff plan first, then apply.