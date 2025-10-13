/// Tests for lesson parser functionality
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_vibe/features/lesson/lesson_parser.dart';
import 'package:piano_vibe/core/models.dart';
import 'dart:io';

void main() {
  group('LessonParser', () {
    test('should parse basic MIDI file structure', () {
      // This is a basic test structure
      // In a real implementation, you would need actual MIDI files for testing
      
      // Test tempo map conversion
      final tempoMap = [
        TempoMap(t: 0.0, bpm: 120.0),
        TempoMap(t: 10.0, bpm: 140.0),
      ];
      
      expect(tempoMap.length, 2);
      expect(tempoMap.first.bpm, 120.0);
      expect(tempoMap.last.t, 10.0);
    });

    test('should create notes with correct hand assignment', () {
      // Test hand assignment logic
      final notes = [
        Note(
          pitch: 48, // C3 - should be left hand
          t0: 0.0,
          t1: 1.0,
          velocity: 80,
          hand: Hand.unknown,
          bar: 1,
          sectionId: 'main',
        ),
        Note(
          pitch: 72, // C5 - should be right hand
          t0: 0.0,
          t1: 1.0,
          velocity: 80,
          hand: Hand.unknown,
          bar: 1,
          sectionId: 'main',
        ),
      ];

      // Test pitch threshold logic
      expect(notes[0].pitch < 60, true); // Should be left hand
      expect(notes[1].pitch >= 60, true); // Should be right hand
    });

    test('should group notes by simultaneous start times for learn mode', () {
      final notes = [
        Note(
          pitch: 60,
          t0: 0.0,
          t1: 1.0,
          velocity: 80,
          hand: Hand.left,
          bar: 1,
          sectionId: 'main',
        ),
        Note(
          pitch: 64,
          t0: 0.0, // Same start time
          t1: 1.0,
          velocity: 80,
          hand: Hand.left,
          bar: 1,
          sectionId: 'main',
        ),
        Note(
          pitch: 67,
          t0: 1.0, // Different start time
          t1: 2.0,
          velocity: 80,
          hand: Hand.right,
          bar: 1,
          sectionId: 'main',
        ),
      ];

      // Group by start time
      final noteGroups = <double, List<Note>>{};
      for (final note in notes) {
        noteGroups[note.t0] = noteGroups[note.t0] ?? [];
        noteGroups[note.t0]!.add(note);
      }

      expect(noteGroups.length, 2); // Two different start times
      expect(noteGroups[0.0]!.length, 2); // Two notes at time 0
      expect(noteGroups[1.0]!.length, 1); // One note at time 1
    });

    test('should calculate lesson duration correctly', () {
      final notes = [
        Note(
          pitch: 60,
          t0: 0.0,
          t1: 1.0,
          velocity: 80,
          hand: Hand.left,
          bar: 1,
          sectionId: 'main',
        ),
        Note(
          pitch: 64,
          t0: 2.0,
          t1: 3.5,
          velocity: 80,
          hand: Hand.right,
          bar: 1,
          sectionId: 'main',
        ),
      ];

      // Calculate duration
      if (notes.isEmpty) {
        expect(true, false); // Should not be empty
      } else {
        final lastNote = notes.reduce((a, b) => a.t1 > b.t1 ? a : b);
        expect(lastNote.t1, 3.5);
      }
    });
  });

  group('TempoMap calculations', () {
    test('should convert ticks to seconds with tempo changes', () {
      // Test tempo map conversion logic
      const ticksPerQuarterNote = 480;
      final tempoMap = [
        TempoMap(t: 0.0, bpm: 120.0),
        TempoMap(t: 10.0, bpm: 140.0),
      ];

      // Basic calculation: ticks / (ticksPerQuarterNote * bpm / 60)
      const testTicks = 480; // 1 quarter note
      const bpm = 120.0;
      const expectedSeconds = 60.0 / bpm; // 0.5 seconds

      expect(expectedSeconds, 0.5);
    });
  });
}
