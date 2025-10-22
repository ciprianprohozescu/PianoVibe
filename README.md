# PianoVibe - Project Summary

## Purpose
PianoVibe (also called "Piano Learner" in the UI) is a web application designed to help users learn to play piano by providing an interactive MIDI playback and visualization system. The application allows users to upload MIDI files, connect their MIDI keyboards, and practice playing along with the music in different learning modes.

## Functionality

### Core Features
1. **MIDI File Upload**: Users can upload standard MIDI files (.mid/.midi) for playback and learning.
2. **MIDI Device Integration**: The app detects and connects to MIDI input devices (keyboards) using the Web MIDI API.
3. **Learning Modes**:
    - **Learn Mode**: Waits for the user to play the correct notes before advancing
    - **Play Mode**: Free-running playback regardless of user input
4. **Piano Roll Visualization**: A visual representation of upcoming notes that "fall" toward a keyboard at the bottom of the screen.
5. **Playback Controls**: Play/pause, seek to start, and tempo adjustment (50% to 150%).

### User Experience
- The interface is designed with a dark theme and clean, modern styling.
- The piano roll provides a clear visual guide for which notes to play and when.
- The application automatically detects connected MIDI devices and handles device connections/disconnections.

## Architecture

### Component Structure
1. **App Component** (`App.tsx`): The main application component that manages state and orchestrates the other components.
2. **Transport System** (`transport.ts`): Provides precise timing using the Web Audio API's AudioContext.
3. **Audio Engine**:
    - **SimpleSynth** (`SimpleSynth.ts`): A basic polyphonic synthesizer using Web Audio API.
    - **SongScheduler** (`SongScheduler.ts`): Schedules note events for playback with look-ahead buffering.
4. **MIDI Processing**:
    - **MIDI Parser** (`parseMidi.ts`): Parses Standard MIDI Files into a structured format.
5. **Visualization**:
    - **PianoRollCanvas** (`PianoRollCanvas.tsx`): Renders the piano roll visualization using HTML Canvas.

### Data Flow
1. User uploads a MIDI file
2. The file is parsed into a structured `Song` object
3. When playback starts:
    - The Transport provides timing information
    - The SongScheduler schedules notes to play at the appropriate times
    - The SimpleSynth generates audio for the scheduled notes
    - The PianoRollCanvas visualizes upcoming notes

## Tech Stack

### Core Technologies
- **Framework**: React (v19)
- **Language**: TypeScript
- **Build Tool**: Vite

### Web APIs
- **Web Audio API**: Used for audio synthesis and precise timing
- **Web MIDI API**: Used for MIDI device integration
- **Canvas API**: Used for piano roll visualization

### Development Tools
- ESLint for code quality
- TypeScript for type safety

## Implementation Details

### Audio System
- Uses a simple synthesizer with triangle wave oscillators and ADSR envelopes
- Implements look-ahead scheduling for precise timing
- Supports tempo changes and seeking

### MIDI Processing
- Parses Standard MIDI File format (SMF)
- Handles note on/off events, tempo changes, and track names
- Converts between tick-based timing and real-time (ms) timing

### Visualization
- Vertical time representation (future downward)
- Horizontal pitch representation
- Responsive design that adapts to container size
- Automatic calculation of visible pitch range

## Current Status
The application is described as a "prototype" in the UI, suggesting it's in early development. The minimal dependencies in package.json and the comment in SimpleSynth.ts about it being "not realistic piano — just clean tones to prove timing & scheduling" indicate that this is a functional proof of concept that could be expanded with more features and refinements.