/// Practice-specific Riverpod providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import 'practice_controller.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

/// Provider for play mode controller
final playModeControllerProvider = StateNotifierProvider<PlayModeControllerNotifier, PlayModeController?>((ref) {
  final lesson = ref.watch(lessonProvider);
  return PlayModeControllerNotifier(
    lesson: lesson ?? const Lesson(bpm: 120.0, tempoMap: [], notes: [], sections: []),
    config: ref.watch(practiceConfigProvider),
  );
});

/// Provider for learn mode controller
final learnModeControllerProvider = StateNotifierProvider<LearnModeControllerNotifier, LearnModeController?>((ref) {
  final lesson = ref.watch(lessonProvider);
  return LearnModeControllerNotifier(
    lesson: lesson ?? const Lesson(bpm: 120.0, tempoMap: [], notes: [], sections: []),
    config: ref.watch(practiceConfigProvider),
  );
});

/// Notifier for play mode controller
class PlayModeControllerNotifier extends StateNotifier<PlayModeController?> {
  PlayModeControllerNotifier({
    required Lesson lesson,
    required PracticeConfig config,
  }) : super(null) {
    state = PlayModeController(
      lesson: lesson,
      config: config,
      onResultsUpdate: (results) {
        // Update hit results in global state
        // This would need to be connected to the global providers
      },
      onTimeUpdate: (time) {
        // Update practice time in global state
        // This would need to be connected to the global providers
      },
    );
  }

  void start() => state?.start();
  void pause() => state?.pause();
  void stop() => state?.stop();
  void processMidiInput(MidiInput input) => state?.processMidiInput(input);
}

/// Notifier for learn mode controller
class LearnModeControllerNotifier extends StateNotifier<LearnModeController?> {
  LearnModeControllerNotifier({
    required Lesson lesson,
    required PracticeConfig config,
  }) : super(null) {
    state = LearnModeController(
      lesson: lesson,
      config: config,
      onStepsUpdate: (steps) {
        // Update learn steps in global state
        // This would need to be connected to the global providers
      },
      onCurrentStepUpdate: (step) {
        // Update current step in global state
        // This would need to be connected to the global providers
      },
      onResultsUpdate: (results) {
        // Update hit results in global state
        // This would need to be connected to the global providers
      },
      onTimeUpdate: (time) {
        // Update practice time in global state
        // This would need to be connected to the global providers
      },
    );
  }

  void start() => state?.start();
  void pause() => state?.pause();
  void stop() => state?.stop();
  void processMidiInput(MidiInput input) => state?.processMidiInput(input);
  void advanceStep() => state?.advanceStep();
  void previousStep() => state?.previousStep();
}
