/// Practice controllers for Learn and Play modes
library;

import 'dart:async';
import 'dart:math' as math;
import '../../core/models.dart';

/// Base class for practice controllers
abstract class PracticeController {
  void start();
  void pause();
  void stop();
  void updateTime(double currentTime);
  void processMidiInput(MidiInput input);
  void dispose();
}

/// Play mode controller - runs on fixed tempo with scoring
class PlayModeController implements PracticeController {
  final Lesson lesson;
  final PracticeConfig config;
  final void Function(List<HitResult>) onResultsUpdate;
  final void Function(double) onTimeUpdate;
  
  Timer? _timer;
  double _currentTime = 0.0;
  final List<HitResult> _results = [];
  final Map<int, Note> _activeNotes = {}; // pitch -> note
  final List<Note> _upcomingNotes = [];
  int _nextNoteIndex = 0;
  
  PlayModeController({
    required this.lesson,
    required this.config,
    required this.onResultsUpdate,
    required this.onTimeUpdate,
  }) {
    _upcomingNotes.addAll(lesson.notes);
    _upcomingNotes.sort((a, b) => a.t0.compareTo(b.t0));
  }

  @override
  void start() {
    _currentTime = 0.0;
    _results.clear();
    _activeNotes.clear();
    _nextNoteIndex = 0;
    
    // Start timer for fixed tempo playback
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _currentTime += 0.016;
      _updateActiveNotes();
      onTimeUpdate(_currentTime);
    });
  }

  @override
  void pause() {
    _timer?.cancel();
  }

  @override
  void stop() {
    _timer?.cancel();
    _currentTime = 0.0;
    _results.clear();
    _activeNotes.clear();
    _nextNoteIndex = 0;
  }

  @override
  void updateTime(double currentTime) {
    _currentTime = currentTime;
    _updateActiveNotes();
  }

  @override
  void processMidiInput(MidiInput input) {
    if (!input.isNoteOn) return;

    final hitWindow = config.hitWindowMs / 1000.0; // Convert to seconds
    final latency = config.latencyMs / 1000.0;
    final adjustedTime = _currentTime + latency;

    // Check if this input matches any active or imminent note within window
    final candidateNotes = [
      ..._activeNotes.values,
      ..._upcomingNotes.where((n) => n.t0 >= _currentTime && (n.t0 - adjustedTime).abs() <= hitWindow)
    ];
    for (final note in candidateNotes) {
      final timeError = (adjustedTime - note.t0).abs();
      
      if (timeError <= hitWindow) {
        // Hit!
        final result = HitResult(
          isHit: true,
          timingError: (adjustedTime - note.t0) * 1000, // Convert to ms
          expectedNote: note,
          actualInput: input,
        );
        
        _results.add(result);
        _activeNotes.remove(note.pitch);
        _upcomingNotes.remove(note);
        onResultsUpdate(List.from(_results));
        return;
      }
    }

    // Miss - no matching note found: report closest among active/upcoming
    final candidates = [
      ..._activeNotes.values,
      ..._upcomingNotes,
    ];
    if (candidates.isNotEmpty) {
      final closestNote = candidates
          .reduce((a, b) => (adjustedTime - a.t0).abs() < (adjustedTime - b.t0).abs() ? a : b);

      final result = HitResult(
        isHit: false,
        timingError: (adjustedTime - closestNote.t0) * 1000,
        expectedNote: closestNote,
        actualInput: input,
      );

      _results.add(result);
      onResultsUpdate(List.from(_results));
    }
  }

  void _updateActiveNotes() {
    // Add new notes that should be active
    while (_nextNoteIndex < _upcomingNotes.length) {
      final note = _upcomingNotes[_nextNoteIndex];
      if (note.t0 <= _currentTime) {
        _activeNotes[note.pitch] = note;
        _nextNoteIndex++;
      } else {
        break;
      }
    }

    // Remove notes that have passed their hit window
    final hitWindow = config.hitWindowMs / 1000.0;
    final expiredPitches = <int>[];
    
    for (final entry in _activeNotes.entries) {
      if (_currentTime - entry.value.t0 > hitWindow) {
        expiredPitches.add(entry.key);
        
        // Record as miss
        final result = HitResult(
          isHit: false,
          timingError: -hitWindow * 1000, // Late miss
          expectedNote: entry.value,
          actualInput: null,
        );
        _results.add(result);
      }
    }
    
    for (final pitch in expiredPitches) {
      _activeNotes.remove(pitch);
    }
    
    if (expiredPitches.isNotEmpty) {
      onResultsUpdate(List.from(_results));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
  }
}

/// Learn mode controller - step through simultaneities
class LearnModeController implements PracticeController {
  final Lesson lesson;
  final PracticeConfig config;
  final void Function(List<List<Note>>) onStepsUpdate;
  final void Function(int) onCurrentStepUpdate;
  final void Function(List<HitResult>) onResultsUpdate;
  final void Function(double) onTimeUpdate;
  
  List<List<Note>> _steps = [];
  int _currentStepIndex = 0;
  final List<HitResult> _results = [];
  final Set<int> _pressedKeys = {};
  final Map<int, Note> _currentStepNotes = {};
  
  LearnModeController({
    required this.lesson,
    required this.config,
    required this.onStepsUpdate,
    required this.onCurrentStepUpdate,
    required this.onResultsUpdate,
    required this.onTimeUpdate,
  }) {
    _generateSteps();
  }

  @override
  void start() {
    _currentStepIndex = 0;
    _results.clear();
    _pressedKeys.clear();
    _updateCurrentStep();
    onStepsUpdate(_steps);
    onCurrentStepUpdate(_currentStepIndex);
  }

  @override
  void pause() {
    // Learn mode doesn't have a timer, just pause step advancement
  }

  @override
  void stop() {
    _currentStepIndex = 0;
    _results.clear();
    _pressedKeys.clear();
    _currentStepNotes.clear();
    onCurrentStepUpdate(_currentStepIndex);
  }

  @override
  void updateTime(double currentTime) {
    // Learn mode doesn't use time-based updates
  }

  @override
  void processMidiInput(MidiInput input) {
    if (input.isNoteOn) {
      _pressedKeys.add(input.pitch);
    } else {
      _pressedKeys.remove(input.pitch);
    }

    _checkStepCompletion();
  }

  /// Generate steps from lesson notes (group by simultaneous start times)
  void _generateSteps() {
    _steps.clear();
    
    // Group notes by start time
    final noteGroups = <double, List<Note>>{};
    
    for (final note in lesson.notes) {
      final startTime = note.t0;
      noteGroups[startTime] = noteGroups[startTime] ?? [];
      noteGroups[startTime]!.add(note);
    }
    
    // Convert to steps (sorted by time)
    final sortedTimes = noteGroups.keys.toList()..sort();
    for (final time in sortedTimes) {
      _steps.add(noteGroups[time]!);
    }
  }

  /// Update the current step
  void _updateCurrentStep() {
    if (_currentStepIndex < _steps.length) {
      _currentStepNotes.clear();
      for (final note in _steps[_currentStepIndex]) {
        _currentStepNotes[note.pitch] = note;
      }
    } else {
      _currentStepNotes.clear();
    }
  }

  /// Check if current step is completed
  void _checkStepCompletion() {
    if (_currentStepNotes.isEmpty) return;

    // Check if all required notes are pressed
    final requiredPitches = _currentStepNotes.keys.toSet();
    final allPressed = requiredPitches.every((pitch) => _pressedKeys.contains(pitch));

    if (allPressed) {
      // Step completed successfully
      for (final note in _currentStepNotes.values) {
        final result = HitResult(
          isHit: true,
          timingError: 0.0, // Perfect timing in learn mode
          expectedNote: note,
          actualInput: null,
        );
        _results.add(result);
      }

      // Move to next step
      _currentStepIndex++;
      _pressedKeys.clear();
      _updateCurrentStep();
      
      onResultsUpdate(List.from(_results));
      onCurrentStepUpdate(_currentStepIndex);
    }
  }

  /// Advance to next step manually
  void advanceStep() {
    if (_currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      _pressedKeys.clear();
      _updateCurrentStep();
      onCurrentStepUpdate(_currentStepIndex);
    }
  }

  /// Go back to previous step
  void previousStep() {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      _pressedKeys.clear();
      _updateCurrentStep();
      onCurrentStepUpdate(_currentStepIndex);
    }
  }

  @override
  void dispose() {
    // No resources to dispose
  }
}
