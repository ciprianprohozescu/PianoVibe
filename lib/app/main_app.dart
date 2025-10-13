/// Main application widget with tabbed interface
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'import_tab.dart';
import 'devices_tab.dart';
import 'practice_tab.dart';

/// Main application widget
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PianoVibe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PianoVibeHome(),
    );
  }
}

/// Home screen with tabbed interface
class PianoVibeHome extends StatefulWidget {
  const PianoVibeHome({super.key});

  @override
  State<PianoVibeHome> createState() => _PianoVibeHomeState();
}

class _PianoVibeHomeState extends State<PianoVibeHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('PianoVibe'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.upload), text: 'Import'),
            Tab(icon: Icon(Icons.bluetooth), text: 'Devices'),
            Tab(icon: Icon(Icons.piano), text: 'Practice'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ImportTab(),
          DevicesTab(),
          PracticeTab(),
        ],
      ),
    );
  }
}
