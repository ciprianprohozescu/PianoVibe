/// Practice tab widget
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/render/practice_view.dart';
import '../features/lesson/lesson_providers.dart';
import '../features/midi/midi_providers.dart';
import '../features/practice/practice_providers.dart';
import '../core/providers.dart';
import '../core/models.dart';

/// Practice tab widget
class PracticeTab extends ConsumerWidget {
  const PracticeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(lessonImportProvider).lesson;
    final connectedDevice = ref.watch(connectedMidiDeviceProvider).value;
    final midiInputs = ref.watch(midiInputStreamProvider);

    // Listen to MIDI inputs and process them
    ref.listen<AsyncValue<List<MidiInput>>>(midiInputStreamProvider, (previous, next) {
      next.whenData((inputs) {
        for (final input in inputs) {
          // Process MIDI input based on current practice mode
          final practiceState = ref.read(practiceStateProvider);
          if (practiceState == PracticeState.learning) {
            ref.read(learnModeControllerProvider.notifier).processMidiInput(input);
          } else if (practiceState == PracticeState.playing) {
            ref.read(playModeControllerProvider.notifier).processMidiInput(input);
          }
        }
      });
    });

    return Column(
      children: [
        // Device status
        if (connectedDevice != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.green.shade100,
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                const SizedBox(width: 8),
                Text('Connected: ${connectedDevice.name}'),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.orange.shade100,
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Text('No MIDI device connected'),
              ],
            ),
          ),
        
        // Practice view
        Expanded(
          child: lesson != null 
              ? const PracticeView()
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No lesson loaded',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Import a MIDI file to start practicing',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
