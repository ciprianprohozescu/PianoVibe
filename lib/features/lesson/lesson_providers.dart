/// Lesson-specific Riverpod providers
library;

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import 'package:file_picker/file_picker.dart';
import 'lesson_parser.dart';
import '../../core/models.dart';

/// Provider for lesson import service
final lessonImportProvider = StateNotifierProvider<LessonImportNotifier, LessonImportState>((ref) {
  return LessonImportNotifier();
});

/// State for lesson import
class LessonImportState {
  final Lesson? lesson;
  final bool isLoading;
  final String? error;

  const LessonImportState({
    this.lesson,
    this.isLoading = false,
    this.error,
  });

  LessonImportState copyWith({
    Lesson? lesson,
    bool? isLoading,
    String? error,
  }) {
    return LessonImportState(
      lesson: lesson ?? this.lesson,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Notifier for lesson import operations
class LessonImportNotifier extends StateNotifier<LessonImportState> {
  LessonImportNotifier() : super(const LessonImportState());

  /// Import a lesson from a MIDI file
  Future<void> importFromFile() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mid', 'midi'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final lesson = await LessonParser.parseMidiFile(file);
        
        if (lesson != null) {
          state = state.copyWith(lesson: lesson, isLoading: false);
        } else {
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to parse MIDI file',
          );
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error importing file: $e',
      );
    }
  }

  /// Clear the current lesson
  void clearLesson() {
    state = const LessonImportState();
  }

  /// Set lesson directly (for testing)
  void setLesson(Lesson lesson) {
    state = state.copyWith(lesson: lesson);
  }
}
