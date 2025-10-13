/// Devices tab for MIDI device management
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/midi/midi_providers.dart';
import '../features/midi/midi_service.dart';
import '../core/models.dart';

/// Devices tab widget
class DevicesTab extends ConsumerWidget {
  const DevicesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(midiDevicesListProvider);
    final connectedDeviceAsync = ref.watch(connectedMidiDeviceProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'MIDI Devices',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Refresh button
          ElevatedButton.icon(
            onPressed: () async {
              final service = ref.read(midiServiceProvider);
              await service.refreshDevices();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Devices'),
          ),
          
          const SizedBox(height: 16),
          
          // Devices list
          Expanded(
            child: devicesAsync.when(
              data: (devices) => _buildDevicesList(devices, connectedDeviceAsync.value, ref),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading devices: $error'),
                  ],
                ),
              ),
            ),
          ),
          
          // Connected device info
          if (connectedDeviceAsync.value != null) ...[
            const SizedBox(height: 16),
            _buildConnectedDeviceInfo(connectedDeviceAsync.value!),
          ],
        ],
      ),
    );
  }

  /// Build devices list
  Widget _buildDevicesList(
    List<MidiDevice> devices,
    MidiDevice? connectedDevice,
    WidgetRef ref,
  ) {
    if (devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No MIDI devices found'),
            SizedBox(height: 8),
            Text('Connect a MIDI device or enable Bluetooth', 
                 style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        final isConnected = connectedDevice?.id == device.id;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(
              device.isBluetooth ? Icons.bluetooth : Icons.usb,
              color: isConnected ? Colors.green : Colors.grey,
            ),
            title: Text(device.name),
            subtitle: Text(
              '${device.isBluetooth ? "Bluetooth" : "USB"} - ${isConnected ? "Connected" : "Disconnected"}',
            ),
            trailing: isConnected
                ? IconButton(
                    onPressed: () async {
                      final service = ref.read(midiServiceProvider);
                      await service.disconnectDevice();
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Disconnect',
                  )
                : IconButton(
                    onPressed: () async {
                      final service = ref.read(midiServiceProvider);
                      await service.connectDevice(device);
                    },
                    icon: const Icon(Icons.link, color: Colors.green),
                    tooltip: 'Connect',
                  ),
            onTap: () async {
              final service = ref.read(midiServiceProvider);
              if (isConnected) {
                await service.disconnectDevice();
              } else {
                await service.connectDevice(device);
              }
            },
          ),
        );
      },
    );
  }

  /// Build connected device info
  Widget _buildConnectedDeviceInfo(MidiDevice device) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Connected Device',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Name: ${device.name}'),
            Text('Type: ${device.isBluetooth ? "Bluetooth" : "USB"}'),
            Text('ID: ${device.id}'),
          ],
        ),
      ),
    );
  }
}
