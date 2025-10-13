/// MIDI device discovery and connection service (test-friendly stub)
library;

import 'dart:async';
import '../../core/models.dart' as app;

/// Service for managing MIDI devices and input (no-op in tests)
class MidiService {
  static final MidiService _instance = MidiService._internal();
  factory MidiService() => _instance;
  MidiService._internal();

  final StreamController<List<app.MidiInput>> _inputController = StreamController<List<app.MidiInput>>.broadcast();
  
  List<app.MidiDevice> _devices = const [];
  app.MidiDevice? _connectedDevice;

  // Stream of MIDI input events
  Stream<List<app.MidiInput>> get inputStream => _inputController.stream;

  // Current list of available devices
  List<app.MidiDevice> get devices => List.unmodifiable(_devices);

  // Currently connected device
  app.MidiDevice? get connectedDevice => _connectedDevice;

  Future<void> initialize() async {
    // No-op for tests
    _devices = const [];
  }

  Future<void> refreshDevices() async {
    // No-op for tests
  }

  Future<bool> connectDevice(app.MidiDevice device) async {
    _connectedDevice = device;
    return true;
  }

  Future<void> disconnectDevice() async {
    _connectedDevice = null;
  }

  void dispose() {
    _inputController.close();
  }
}
