/// Widget for the practice view with falling bars
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'piano_renderer.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

/// Main practice view widget
class PracticeView extends ConsumerStatefulWidget {
  const PracticeView({super.key});

  @override
  ConsumerState<PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends ConsumerState<PracticeView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  Timer? _practiceTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _practiceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = ref.watch(lessonProvider);
    final practiceState = ref.watch(practiceStateProvider);
    final practiceTime = ref.watch(practiceTimeProvider);
    final practiceConfig = ref.watch(practiceConfigProvider);

    if (lesson == null) {
      return const Center(
        child: Text(
          'No lesson loaded. Import a MIDI file first.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return Column(
      children: [
        // Practice controls
        _buildPracticeControls(practiceState, practiceConfig),
        
        // Piano renderer
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
            ),
            child: CustomPaint(
              painter: PianoRenderer(
                visibleNotes: _getVisibleNotes(lesson, practiceTime),
                currentTime: practiceTime,
                windowDuration: 5.0,
                size: MediaQuery.of(context).size,
                keyHeight: 80.0,
              ),
              child: Container(), // Empty child for CustomPaint
            ),
          ),
        ),
        
        // Practice info
        _buildPracticeInfo(practiceTime, lesson),
      ],
    );
  }

  /// Build practice control buttons
  Widget _buildPracticeControls(PracticeState state, PracticeConfig config) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: state == PracticeState.stopped ? _startPractice : _stopPractice,
            icon: Icon(state == PracticeState.stopped ? Icons.play_arrow : Icons.stop),
            label: Text(state == PracticeState.stopped ? 'Start' : 'Stop'),
          ),
          
          if (state == PracticeState.playing)
            ElevatedButton.icon(
              onPressed: _pausePractice,
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
            ),
          
          if (state == PracticeState.paused)
            ElevatedButton.icon(
              onPressed: _resumePractice,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
            ),
          
          ElevatedButton.icon(
            onPressed: _toggleMode,
            icon: const Icon(Icons.school),
            label: Text(state == PracticeState.learning ? 'Learn Mode' : 'Play Mode'),
          ),
          
          // Metronome toggle
          IconButton(
            onPressed: _toggleMetronome,
            icon: Icon(config.metronomeEnabled ? Icons.volume_up : Icons.volume_off),
            tooltip: 'Toggle Metronome',
          ),
        ],
      ),
    );
  }

  /// Build practice information display
  Widget _buildPracticeInfo(double practiceTime, Lesson lesson) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('Time: ${practiceTime.toStringAsFixed(1)}s'),
          Text('Notes: ${lesson.notes.length}'),
          Text('BPM: ${lesson.bpm.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  /// Get notes visible in current time window
  List<Note> _getVisibleNotes(Lesson lesson, double currentTime) {
    const windowDuration = 5.0;
    final windowStart = currentTime - windowDuration;
    final windowEnd = currentTime + windowDuration;

    return lesson.notes.where((note) {
      return (note.t0 >= windowStart && note.t0 <= windowEnd) ||
             (note.t1 >= windowStart && note.t1 <= windowEnd) ||
             (note.t0 <= windowStart && note.t1 >= windowEnd);
    }).toList();
  }

  /// Start practice session
  void _startPractice() {
    ref.read(practiceStateProvider.notifier).state = PracticeState.playing;
    ref.read(practiceTimeProvider.notifier).state = 0.0;
    
    _startPracticeTimer();
    _animationController.repeat();
  }

  /// Stop practice session
  void _stopPractice() {
    ref.read(practiceStateProvider.notifier).state = PracticeState.stopped;
    ref.read(practiceTimeProvider.notifier).state = 0.0;
    
    _stopPracticeTimer();
    _animationController.stop();
  }

  /// Pause practice session
  void _pausePractice() {
    ref.read(practiceStateProvider.notifier).state = PracticeState.paused;
    _stopPracticeTimer();
    _animationController.stop();
  }

  /// Resume practice session
  void _resumePractice() {
    ref.read(practiceStateProvider.notifier).state = PracticeState.playing;
    _startPracticeTimer();
    _animationController.repeat();
  }

  /// Toggle between learn and play mode
  void _toggleMode() {
    final currentState = ref.read(practiceStateProvider);
    if (currentState == PracticeState.learning) {
      ref.read(practiceStateProvider.notifier).state = PracticeState.playing;
    } else {
      ref.read(practiceStateProvider.notifier).state = PracticeState.learning;
    }
  }

  /// Toggle metronome
  void _toggleMetronome() {
    final currentConfig = ref.read(practiceConfigProvider);
    ref.read(practiceConfigProvider.notifier).state = currentConfig.copyWith(
      metronomeEnabled: !currentConfig.metronomeEnabled,
    );
  }

  /// Start the practice timer
  void _startPracticeTimer() {
    _practiceTimer?.cancel();
    _practiceTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (ref.read(practiceStateProvider) == PracticeState.playing) {
        final currentTime = ref.read(practiceTimeProvider);
        ref.read(practiceTimeProvider.notifier).state = currentTime + 0.016;
      }
    });
  }

  /// Stop the practice timer
  void _stopPracticeTimer() {
    _practiceTimer?.cancel();
    _practiceTimer = null;
  }
}
