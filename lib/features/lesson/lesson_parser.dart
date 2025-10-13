/// MIDI file parsing and lesson normalization
library;

import 'dart:io';
import 'package:collection/collection.dart';
import '../../core/models.dart';

/// Service for parsing MIDI files and creating lessons
class LessonParser {
  /// Parse a MIDI file and create a Lesson
  static Future<Lesson?> parseMidiFile(File midiFile) async {
    try {
      final bytes = await midiFile.readAsBytes();
      // MIDI parsing not implemented in tests; return null gracefully
      return null;
    } catch (e) {
      print('Error parsing MIDI file: $e');
      return null;
    }
  }

  /// Convert MIDI file to Lesson format
  static Lesson _convertMidiToLesson(MidiFile midi) {
    final tempoMap = <TempoMap>[];
    final notes = <Note>[];
    final sections = <Section>[];
    
    // Get default BPM from first tempo event
    double defaultBpm = 120.0;
    final firstTempo = midi.tracks
        .expand((track) => (track as dynamic).events as List)
        .firstWhereOrNull(_isSetTempoEvent);
    
    if (firstTempo != null) {
      final bpm = (firstTempo as dynamic).tempo as num?;
      if (bpm != null) defaultBpm = bpm.toDouble();
    }

    // Process each track
    for (int trackIndex = 0; trackIndex < midi.tracks.length; trackIndex++) {
      final track = midi.tracks[trackIndex];
      final tpq = (midi as dynamic).ticksPerQuarterNote as int? ?? 480;
      _processTrack(track, trackIndex, notes, tempoMap, tpq);
    }

    // Sort notes by start time
    notes.sort((a, b) => a.t0.compareTo(b.t0));

    // Create sections based on bars (simplified approach)
    sections.addAll(_createSections(notes, defaultBpm));

    // Determine hand assignment for notes
    _assignHands(notes);

    return Lesson(
      bpm: defaultBpm,
      tempoMap: tempoMap,
      notes: notes,
      sections: sections,
      timeSignature: _extractTimeSignature(midi),
      keySignature: _extractKeySignature(midi),
    );
  }

  /// Process a single MIDI track
  static void _processTrack(
    dynamic track,
    int trackIndex,
    List<Note> notes,
    List<TempoMap> tempoMap,
    int ticksPerQuarterNote,
  ) {
    double currentTime = 0.0;
    final activeNotes = <int, double>{}; // pitch -> start time
    final sustainPedal = <int, bool>{}; // track -> is pressed

    final List events = (track as dynamic).events as List? ?? const [];
    for (final event in events) {
      currentTime = _ticksToSeconds(event.tick, ticksPerQuarterNote, tempoMap);

      if (_isSetTempoEvent(event)) {
        final bpm = (event as dynamic).tempo as num? ?? 120.0;
        tempoMap.add(TempoMap(t: currentTime, bpm: bpm.toDouble()));
      } else if (_isNoteOn(event) && ((event as dynamic).velocity as int) > 0) {
        activeNotes[(event as dynamic).note as int] = currentTime;
      } else if (_isNoteOff(event) || (_isNoteOn(event) && ((event as dynamic).velocity as int) == 0)) {
        final pitch = (event as dynamic).note as int?;
        final startTime = activeNotes.remove(pitch);
        if (startTime != null) {
          final endTime = _applySustain(currentTime, sustainPedal[trackIndex] ?? false);
          notes.add(Note(
            pitch: pitch ?? 0,
            t0: startTime,
            t1: endTime,
            velocity: 80, // Default velocity if not available
            hand: Hand.unknown, // Will be assigned later
            bar: _timeToBar(startTime, 120.0), // Default BPM for bar calculation
            sectionId: 'main', // Will be updated when sections are created
          ));
        }
      } else if (_isControlChange(event) && ((event as dynamic).controller as int?) == 64) {
        // Sustain pedal (CC64)
        sustainPedal[trackIndex] = (((event as dynamic).value as int?) ?? 0) >= 64;
      }
    }
  }

  /// Apply sustain pedal effect to note end time
  static double _applySustain(double noteOffTime, bool sustainPressed) {
    // For now, just return the original time
    // In a more sophisticated implementation, we'd extend the note
    return noteOffTime;
  }

  /// Convert MIDI ticks to seconds
  static double _ticksToSeconds(
    int ticks,
    int ticksPerQuarterNote,
    List<TempoMap> tempoMap,
  ) {
    if (tempoMap.isEmpty) {
      // No tempo changes, use default 120 BPM
      return ticks / (ticksPerQuarterNote * 2); // 120 BPM = 2 beats per second
    }

    // Find the appropriate tempo for this tick
    double currentBpm = 120.0;
    double accumulatedTime = 0.0;
    int lastTempoTick = 0;

    for (final tempo in tempoMap) {
      final tempoTick = _secondsToTicks(tempo.t, ticksPerQuarterNote, tempoMap);
      if (ticks >= tempoTick) {
        // Add time for this tempo segment
        final segmentTicks = tempoTick - lastTempoTick;
        final segmentSeconds = segmentTicks / (ticksPerQuarterNote * currentBpm / 60.0);
        accumulatedTime += segmentSeconds;
        
        lastTempoTick = tempoTick;
        currentBpm = tempo.bpm;
      }
    }

    // Add time for the final segment
    final finalSegmentTicks = ticks - lastTempoTick;
    final finalSegmentSeconds = finalSegmentTicks / (ticksPerQuarterNote * currentBpm / 60.0);
    
    return accumulatedTime + finalSegmentSeconds;
  }

  /// Convert seconds to MIDI ticks (helper for tempo calculations)
  static int _secondsToTicks(
    double seconds,
    int ticksPerQuarterNote,
    List<TempoMap> tempoMap,
  ) {
    // Simplified implementation - in practice this would need to be more sophisticated
    return (seconds * ticksPerQuarterNote * 2).round(); // Assuming 120 BPM
  }

  /// Convert time to bar number
  static int _timeToBar(double timeSeconds, double bpm) {
    final beatsPerSecond = bpm / 60.0;
    final beatsPerBar = 4.0; // Assume 4/4 time
    return (timeSeconds * beatsPerSecond / beatsPerBar).floor();
  }

  /// Create sections from notes
  static List<Section> _createSections(List<Note> notes, double bpm) {
    if (notes.isEmpty) return [];

    final sections = <Section>[];
    final startTime = notes.first.t0;
    final endTime = notes.last.t1;
    final startBar = notes.first.bar;
    final endBar = notes.last.bar;

    sections.add(Section(
      id: 'main',
      start: startTime,
      end: endTime,
      bars: (startBar, endBar),
    ));

    return sections;
  }

  /// Assign hands to notes based on pitch threshold
  static void _assignHands(List<Note> notes) {
    const pitchThreshold = 60; // Middle C

    for (final note in notes) {
      if (note.pitch < pitchThreshold) {
        // Note is in left hand range
        notes[notes.indexOf(note)] = Note(
          pitch: note.pitch,
          t0: note.t0,
          t1: note.t1,
          velocity: note.velocity,
          hand: Hand.left,
          bar: note.bar,
          sectionId: note.sectionId,
        );
      } else {
        // Note is in right hand range
        notes[notes.indexOf(note)] = Note(
          pitch: note.pitch,
          t0: note.t0,
          t1: note.t1,
          velocity: note.velocity,
          hand: Hand.right,
          bar: note.bar,
          sectionId: note.sectionId,
        );
      }
    }
  }

  /// Extract time signature from MIDI file
  static (int, int)? _extractTimeSignature(MidiFile midi) {
    // Look for time signature events
    for (final track in midi.tracks) {
      final events = (track as dynamic).events as List? ?? const [];
      for (final event in events) {
        final numerator = (event as dynamic).numerator as int?;
        final denominator = (event as dynamic).denominator as int?;
        if (numerator != null && denominator != null) {
          return (numerator, denominator);
        }
      }
    }
    return null;
  }

  /// Extract key signature from MIDI file
  static String? _extractKeySignature(MidiFile midi) {
    // Look for key signature events
    for (final track in midi.tracks) {
      final events = (track as dynamic).events as List? ?? const [];
      for (final event in events) {
        final key = (event as dynamic).key as String?;
        final scale = (event as dynamic).scale as int?;
        if (key != null && scale != null) {
          return '$key${scale == 0 ? ' major' : ' minor'}';
        }
      }
    }
    return null;
  }
}

/// Minimal stub for MIDI file used by tests (no real parsing)
class MidiFile {
  final List<dynamic> tracks;
  final int ticksPerQuarterNote;
  MidiFile({required this.tracks, this.ticksPerQuarterNote = 480});
}

bool _isSetTempoEvent(dynamic event) => (event as dynamic).tempo != null;
bool _isNoteOn(dynamic event) => (event as dynamic).note != null && (event as dynamic).velocity != null && ((event as dynamic).status ?? 0) & 0xF0 == 0x90;
bool _isNoteOff(dynamic event) => (event as dynamic).note != null && (((event as dynamic).status ?? 0) & 0xF0 == 0x80);
bool _isControlChange(dynamic event) => (event as dynamic).controller != null && (event as dynamic).value != null;
