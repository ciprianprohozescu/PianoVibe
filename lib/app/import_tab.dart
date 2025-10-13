/// Import tab for loading MIDI files
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/lesson/lesson_providers.dart';
import '../core/models.dart';

/// Import tab widget
class ImportTab extends ConsumerWidget {
  const ImportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(lessonImportProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Import MIDI File',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: importState.isLoading 
                ? null 
                : () => ref.read(lessonImportProvider.notifier).importFromFile(),
            icon: importState.isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: Text(importState.isLoading ? 'Loading...' : 'Select MIDI File'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          
          if (importState.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      importState.error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          if (importState.lesson != null) ...[
            const SizedBox(height: 24),
            _buildLessonInfo(importState.lesson!),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.read(lessonImportProvider.notifier).clearLesson(),
              icon: const Icon(Icons.clear),
              label: const Text('Clear Lesson'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build lesson information display
  Widget _buildLessonInfo(Lesson lesson) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lesson Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Notes', lesson.notes.length.toString()),
            _buildInfoRow('BPM', lesson.bpm.toStringAsFixed(0)),
            _buildInfoRow('Sections', lesson.sections.length.toString()),
            _buildInfoRow('Duration', '${_getLessonDuration(lesson).toStringAsFixed(1)}s'),
            if (lesson.timeSignature != null)
              _buildInfoRow('Time Signature', '${lesson.timeSignature!.$1}/${lesson.timeSignature!.$2}'),
            if (lesson.keySignature != null)
              _buildInfoRow('Key Signature', lesson.keySignature!),
          ],
        ),
      ),
    );
  }

  /// Build a single info row
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  /// Calculate lesson duration
  double _getLessonDuration(Lesson lesson) {
    if (lesson.notes.isEmpty) return 0.0;
    
    final lastNote = lesson.notes.reduce((a, b) => a.t1 > b.t1 ? a : b);
    return lastNote.t1;
  }
}
