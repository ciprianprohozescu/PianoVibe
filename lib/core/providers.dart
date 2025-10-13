/// Riverpod providers for PianoVibe state management
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';

/// Provider for the current lesson
final lessonProvider = StateProvider<Lesson?>((ref) => null);

/// Provider for MIDI device list
final midiDevicesProvider = StateProvider<List<MidiDevice>>((ref) => []);

/// Provider for currently connected MIDI device
final connectedDeviceProvider = StateProvider<MidiDevice?>((ref) => null);

/// Provider for MIDI input stream
final midiInputProvider = StreamProvider<List<MidiInput>>((ref) {
  // This will be implemented in the MIDI feature
  return Stream.value([]);
});

/// Provider for practice configuration
final practiceConfigProvider = StateProvider<PracticeConfig>((ref) => const PracticeConfig());

/// Provider for practice session state
final practiceStateProvider = StateProvider<PracticeState>((ref) => PracticeState.stopped);

/// Provider for current practice time (in seconds)
final practiceTimeProvider = StateProvider<double>((ref) => 0.0);

/// Provider for practice clock (ticker)
final practiceClockProvider = StateProvider<Ticker?>((ref) => null);

/// Provider for latency compensation
final latencyProvider = StateProvider<double>((ref) => 50.0);

/// Provider for hit/miss results during practice
final hitResultsProvider = StateProvider<List<HitResult>>((ref) => []);

/// Provider for current step in learn mode
final currentStepProvider = StateProvider<int>((ref) => 0);

/// Provider for learn mode steps (simultaneous notes)
final learnStepsProvider = StateProvider<List<List<Note>>>((ref) => []);

/// Simple ticker class for practice timing
class Ticker {
  final Duration interval;
  final void Function() onTick;
  bool _isRunning = false;

  Ticker({required this.interval, required this.onTick});

  void start() {
    _isRunning = true;
    _tick();
  }

  void stop() {
    _isRunning = false;
  }

  void _tick() {
    if (!_isRunning) return;
    
    onTick();
    Future.delayed(interval, _tick);
  }

  bool get isRunning => _isRunning;
}
