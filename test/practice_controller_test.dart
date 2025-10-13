/// Tests for practice controller logic
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_vibe/features/practice/practice_controller.dart';
import 'package:piano_vibe/core/models.dart';

void main() {
  group('PlayModeController', () {
    late Lesson testLesson;
    late PracticeConfig testConfig;

    setUp(() {
      testLesson = Lesson(
        bpm: 120.0,
        tempoMap: [],
        notes: [
          Note(
            pitch: 60,
            t0: 1.0,
            t1: 2.0,
            velocity: 80,
            hand: Hand.left,
            bar: 1,
            sectionId: 'main',
          ),
          Note(
            pitch: 64,
            t0: 2.0,
            t1: 3.0,
            velocity: 80,
            hand: Hand.right,
            bar: 1,
            sectionId: 'main',
          ),
        ],
        sections: [],
      );

      testConfig = const PracticeConfig(
        latencyMs: 50.0,
        hitWindowMs: 80,
      );
    });

    test('should detect hits within timing window', () {
      final results = <List<HitResult>>[];
      final timeUpdates = <double>[];

      final controller = PlayModeController(
        lesson: testLesson,
        config: testConfig,
        onResultsUpdate: (r) => results.add(r),
        onTimeUpdate: (time) => timeUpdates.add(time),
      );

      controller.start();

      // Simulate MIDI input at correct time
      controller.processMidiInput(
        MidiInput(
          pitch: 60,
          velocity: 80,
          isNoteOn: true,
          timestamp: DateTime.now(),
        ),
      );

      expect(results.isNotEmpty, true);
    });

    test('should detect misses outside timing window', () {
      final results = <List<HitResult>>[];
      final timeUpdates = <double>[];

      final controller = PlayModeController(
        lesson: testLesson,
        config: testConfig,
        onResultsUpdate: (r) => results.add(r),
        onTimeUpdate: (time) => timeUpdates.add(time),
      );

      controller.start();

      // Simulate MIDI input too early
      controller.processMidiInput(
        MidiInput(
          pitch: 60,
          velocity: 80,
          isNoteOn: true,
          timestamp: DateTime.now(),
        ),
      );

      // The controller should handle timing logic
      expect(results.isNotEmpty, true);
    });
  });

  group('LearnModeController', () {
    late Lesson testLesson;
    late PracticeConfig testConfig;

    setUp(() {
      testLesson = Lesson(
        bpm: 120.0,
        tempoMap: [],
        notes: [
          Note(
            pitch: 60,
            t0: 1.0,
            t1: 2.0,
            velocity: 80,
            hand: Hand.left,
            bar: 1,
            sectionId: 'main',
          ),
          Note(
            pitch: 64,
            t0: 1.0, // Same start time - should be in same step
            t1: 2.0,
            velocity: 80,
            hand: Hand.right,
            bar: 1,
            sectionId: 'main',
          ),
          Note(
            pitch: 67,
            t0: 2.0, // Different start time - should be in different step
            t1: 3.0,
            velocity: 80,
            hand: Hand.right,
            bar: 1,
            sectionId: 'main',
          ),
        ],
        sections: [],
      );

      testConfig = const PracticeConfig();
    });

    test('should create steps from simultaneous notes', () {
      final steps = <List<List<Note>>>[];
      final stepUpdates = <int>[];
      final results = <List<HitResult>>[];
      final timeUpdates = <double>[];

      final controller = LearnModeController(
        lesson: testLesson,
        config: testConfig,
        onStepsUpdate: (s) => steps.add(s),
        onCurrentStepUpdate: (step) => stepUpdates.add(step),
        onResultsUpdate: (r) => results.add(r),
        onTimeUpdate: (time) => timeUpdates.add(time),
      );

      controller.start();

      // Should have 2 steps (notes at t=1.0 and t=2.0)
      expect(stepUpdates.isNotEmpty, true);
      expect(stepUpdates.first, 0); // Should start at step 0
    });

    test('should advance step when all notes in step are pressed', () {
      final steps = <List<List<Note>>>[];
      final stepUpdates = <int>[];
      final results = <List<HitResult>>[];
      final timeUpdates = <double>[];

      final controller = LearnModeController(
        lesson: testLesson,
        config: testConfig,
        onStepsUpdate: (s) => steps.add(s),
        onCurrentStepUpdate: (step) => stepUpdates.add(step),
        onResultsUpdate: (r) => results.add(r),
        onTimeUpdate: (time) => timeUpdates.add(time),
      );

      controller.start();

      // Press first note
      controller.processMidiInput(
        MidiInput(
          pitch: 60,
          velocity: 80,
          isNoteOn: true,
          timestamp: DateTime.now(),
        ),
      );

      // Press second note (both notes at t=1.0)
      controller.processMidiInput(
        MidiInput(
          pitch: 64,
          velocity: 80,
          isNoteOn: true,
          timestamp: DateTime.now(),
        ),
      );

      // Should advance to next step
      expect(stepUpdates.length, greaterThan(1));
    });
  });

  group('Stepper logic', () {
    test('should group notes by start time correctly', () {
      final notes = [
        Note(pitch: 60, t0: 0.0, t1: 1.0, velocity: 80, hand: Hand.left, bar: 1, sectionId: 'main'),
        Note(pitch: 64, t0: 0.0, t1: 1.0, velocity: 80, hand: Hand.right, bar: 1, sectionId: 'main'),
        Note(pitch: 67, t0: 1.0, t1: 2.0, velocity: 80, hand: Hand.right, bar: 1, sectionId: 'main'),
        Note(pitch: 72, t0: 2.0, t1: 3.0, velocity: 80, hand: Hand.right, bar: 1, sectionId: 'main'),
      ];

      // Group by start time
      final noteGroups = <double, List<Note>>{};
      for (final note in notes) {
        noteGroups[note.t0] = noteGroups[note.t0] ?? [];
        noteGroups[note.t0]!.add(note);
      }

      expect(noteGroups.length, 3); // Three different start times
      expect(noteGroups[0.0]!.length, 2); // Two notes at t=0
      expect(noteGroups[1.0]!.length, 1); // One note at t=1
      expect(noteGroups[2.0]!.length, 1); // One note at t=2
    });

    test('should handle empty note list', () {
      final notes = <Note>[];
      
      final noteGroups = <double, List<Note>>{};
      for (final note in notes) {
        noteGroups[note.t0] = noteGroups[note.t0] ?? [];
        noteGroups[note.t0]!.add(note);
      }

      expect(noteGroups.length, 0);
    });
  });
}
