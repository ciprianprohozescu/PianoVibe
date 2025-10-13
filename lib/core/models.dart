/// Core data models for PianoVibe
library;

/// Represents a single note in a lesson
class Note {
  final int pitch; // MIDI pitch (0-127)
  final double t0; // Start time in seconds
  final double t1; // End time in seconds
  final int velocity; // MIDI velocity (0-127)
  final Hand hand; // Which hand plays this note
  final int bar; // Bar number
  final String sectionId; // Section identifier

  const Note({
    required this.pitch,
    required this.t0,
    required this.t1,
    required this.velocity,
    required this.hand,
    required this.bar,
    required this.sectionId,
  });

  @override
  String toString() => 'Note(pitch: $pitch, t0: $t0, t1: $t1, hand: $hand)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          runtimeType == other.runtimeType &&
          pitch == other.pitch &&
          t0 == other.t0 &&
          t1 == other.t1 &&
          velocity == other.velocity &&
          hand == other.hand &&
          bar == other.bar &&
          sectionId == other.sectionId;

  @override
  int get hashCode =>
      pitch.hashCode ^
      t0.hashCode ^
      t1.hashCode ^
      velocity.hashCode ^
      hand.hashCode ^
      bar.hashCode ^
      sectionId.hashCode;
}

/// Represents which hand plays a note
enum Hand { left, right, unknown }

/// Represents a tempo change point
class TempoMap {
  final double t; // Time in seconds
  final double bpm; // Beats per minute

  const TempoMap({required this.t, required this.bpm});

  @override
  String toString() => 'TempoMap(t: $t, bpm: $bpm)';
}

/// Represents a section of the lesson
class Section {
  final String id;
  final double start; // Start time in seconds
  final double end; // End time in seconds
  final (int, int) bars; // (startBar, endBar)

  const Section({
    required this.id,
    required this.start,
    required this.end,
    required this.bars,
  });

  @override
  String toString() => 'Section(id: $id, start: $start, end: $end, bars: $bars)';
}

/// Complete lesson data structure
class Lesson {
  final double bpm; // Default BPM
  final List<TempoMap> tempoMap; // Tempo changes over time
  final List<Note> notes; // All notes in the lesson
  final List<Section> sections; // Sections of the lesson
  final (int, int)? timeSignature; // (numerator, denominator)
  final String? keySignature; // Key signature

  const Lesson({
    required this.bpm,
    required this.tempoMap,
    required this.notes,
    required this.sections,
    this.timeSignature,
    this.keySignature,
  });

  @override
  String toString() => 'Lesson(bpm: $bpm, notes: ${notes.length}, sections: ${sections.length})';
}

/// MIDI device information
class MidiDevice {
  final String id;
  final String name;
  final bool isConnected;
  final bool isBluetooth;

  const MidiDevice({
    required this.id,
    required this.name,
    required this.isConnected,
    required this.isBluetooth,
  });

  @override
  String toString() => 'MidiDevice(id: $id, name: $name, connected: $isConnected)';
}

/// MIDI input event
class MidiInput {
  final int pitch;
  final int velocity;
  final bool isNoteOn;
  final DateTime timestamp;

  const MidiInput({
    required this.pitch,
    required this.velocity,
    required this.isNoteOn,
    required this.timestamp,
  });

  @override
  String toString() => 'MidiInput(pitch: $pitch, velocity: $velocity, on: $isNoteOn)';
}

/// Practice session configuration
class PracticeConfig {
  final double latencyMs; // Latency compensation in milliseconds
  final int hitWindowMs; // Hit detection window in milliseconds
  final bool metronomeEnabled; // Whether metronome is enabled
  final double metronomeVolume; // Metronome volume (0.0-1.0)

  const PracticeConfig({
    this.latencyMs = 50.0,
    this.hitWindowMs = 80,
    this.metronomeEnabled = true,
    this.metronomeVolume = 0.5,
  });

  PracticeConfig copyWith({
    double? latencyMs,
    int? hitWindowMs,
    bool? metronomeEnabled,
    double? metronomeVolume,
  }) {
    return PracticeConfig(
      latencyMs: latencyMs ?? this.latencyMs,
      hitWindowMs: hitWindowMs ?? this.hitWindowMs,
      metronomeEnabled: metronomeEnabled ?? this.metronomeEnabled,
      metronomeVolume: metronomeVolume ?? this.metronomeVolume,
    );
  }
}

/// Practice session state
enum PracticeState {
  stopped,
  playing,
  paused,
  learning,
}

/// Hit/miss result for scoring
class HitResult {
  final bool isHit;
  final double timingError; // Error in milliseconds (positive = late, negative = early)
  final Note expectedNote;
  final MidiInput? actualInput;

  const HitResult({
    required this.isHit,
    required this.timingError,
    required this.expectedNote,
    this.actualInput,
  });

  @override
  String toString() => 'HitResult(hit: $isHit, error: ${timingError}ms)';
}
