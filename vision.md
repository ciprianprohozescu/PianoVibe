# Piano Vibe — Vision & Guardrails

## Purpose
Web app that turns any uploaded MIDI file into an interactive piano lesson with two modes:
- **LEARN**: waits for correct notes before advancing.
- **PLAY**: plays at tempo and scores input.

## Tech decisions (do not change unless asked)
- React + Vite + TypeScript
- PixiJS for falling bars
- Tone.js for timing/audio
- @tonejs/midi for parsing
- webmidi for device input
- Zustand for state
- PWA + future Capacitor wrap
- Tailwind CSS

## File layout (contracts)
- `src/utils/types.ts` — canonical `NoteEvent`, `Lesson`
- `src/lib/` — pure logic (no React): midi parsing, mode logic, audio
- `src/components/` — UI + Pixi
- `src/store/useLessonStore.ts` — all app state
- Do not duplicate components. Edit-in-place.

## Non-negotiables
- Don’t rename `NoteEvent`/`Lesson`.
- Keep PixiJS (no SVG/Three switch).
- Keep Tone.Transport as the timing source.
