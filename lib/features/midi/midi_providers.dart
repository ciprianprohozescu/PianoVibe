/// MIDI-specific Riverpod providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'midi_service.dart';
import '../../core/models.dart';

/// Provider for MIDI service
final midiServiceProvider = Provider<MidiService>((ref) {
  final service = MidiService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for MIDI devices list
final midiDevicesListProvider = StreamProvider<List<MidiDevice>>((ref) async* {
  final service = ref.watch(midiServiceProvider);
  await service.initialize();
  
  yield service.devices;
  
  // Listen for device changes
  await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
    await service.refreshDevices();
    yield service.devices;
  }
});

/// Provider for connected MIDI device
final connectedMidiDeviceProvider = StreamProvider<MidiDevice?>((ref) async* {
  final service = ref.watch(midiServiceProvider);
  yield service.connectedDevice;
  
  // Listen for connection changes
  await for (final _ in Stream.periodic(const Duration(seconds: 1))) {
    yield service.connectedDevice;
  }
});

/// Provider for MIDI input stream
final midiInputStreamProvider = StreamProvider<List<MidiInput>>((ref) {
  final service = ref.watch(midiServiceProvider);
  return service.inputStream;
});
