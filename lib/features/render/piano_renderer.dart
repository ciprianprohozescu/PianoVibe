/// Custom painter for piano keyboard and falling bars
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models.dart';

/// Custom painter for rendering piano keyboard and falling bars
class PianoRenderer extends CustomPainter {
  final List<Note> visibleNotes;
  final double currentTime;
  final double windowDuration; // Duration of visible window in seconds
  final Size size;
  final double keyHeight;
  final Map<Hand, Color> handColors;
  final bool showKeyboard;

  PianoRenderer({
    required this.visibleNotes,
    required this.currentTime,
    this.windowDuration = 5.0,
    required this.size,
    this.keyHeight = 80.0,
    this.handColors = const {
      Hand.left: Colors.blue,
      Hand.right: Colors.red,
      Hand.unknown: Colors.grey,
    },
    this.showKeyboard = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showKeyboard) {
      _drawKeyboard(canvas);
    }
    _drawFallingBars(canvas);
  }

  /// Draw the piano keyboard
  void _drawKeyboard(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.0;

    final whiteKeyWidth = size.width / 52.0; // 52 white keys (4 octaves)
    final blackKeyWidth = whiteKeyWidth * 0.6;
    
    // Draw white keys
    paint.color = Colors.white;
    for (int i = 0; i < 52; i++) {
      final rect = Rect.fromLTWH(
        i * whiteKeyWidth,
        size.height - keyHeight,
        whiteKeyWidth,
        keyHeight,
      );
      canvas.drawRect(rect, paint);
    }

    // Draw black keys
    paint.color = Colors.black;
    final blackKeyPositions = _getBlackKeyPositions(whiteKeyWidth);
    for (final pos in blackKeyPositions) {
      final rect = Rect.fromLTWH(
        pos - blackKeyWidth / 2,
        size.height - keyHeight,
        blackKeyWidth,
        keyHeight * 0.6,
      );
      canvas.drawRect(rect, paint);
    }

    // Draw keyboard outline
    paint.color = Colors.black;
    paint.style = PaintingStyle.stroke;
    final keyboardRect = Rect.fromLTWH(
      0,
      size.height - keyHeight,
      size.width,
      keyHeight,
    );
    canvas.drawRect(keyboardRect, paint);
  }

  /// Get positions of black keys
  List<double> _getBlackKeyPositions(double whiteKeyWidth) {
    final positions = <double>[];
    // Black keys pattern: C# D# F# G# A#
    final blackPattern = [1, 3, 6, 8, 10]; // Positions within each octave
    
    for (int octave = 0; octave < 4; octave++) {
      for (final pos in blackPattern) {
        positions.add((octave * 7 + pos) * whiteKeyWidth);
      }
    }
    
    return positions;
  }

  /// Draw falling bars for notes
  void _drawFallingBars(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    for (final note in visibleNotes) {
      final notePosition = _getNotePosition(note.pitch);
      final noteHeight = _getNoteHeight(note);
      final noteColor = handColors[note.hand] ?? Colors.grey;
      
      paint.color = noteColor.withOpacity(0.8);

      // Calculate note position based on time
      final timeUntilHit = note.t0 - currentTime;
      final yPosition = _timeToY(timeUntilHit);

      // Only draw if note is in visible window
      if (yPosition >= -noteHeight && yPosition <= size.height) {
        final rect = Rect.fromLTWH(
          notePosition - noteHeight / 2,
          yPosition,
          noteHeight,
          noteHeight,
        );
        
        canvas.drawRect(rect, paint);
        
        // Draw note outline
        paint.color = noteColor;
        paint.style = PaintingStyle.stroke;
        canvas.drawRect(rect, paint);
        paint.style = PaintingStyle.fill;
      }
    }
  }

  /// Convert MIDI pitch to horizontal position
  double _getNotePosition(int pitch) {
    // Map MIDI pitch to keyboard position
    // C4 (60) is in the middle
    final relativePitch = pitch - 36; // Start from C2 (36)
    final whiteKeyWidth = size.width / 52.0;
    
    // Calculate which white key this pitch corresponds to
    final octave = relativePitch ~/ 12;
    final noteInOctave = relativePitch % 12;
    
    // Map semitones to white key positions within octave
    final whiteKeyPositions = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6]; // C C# D D# E F F# G G# A A# B
    final whiteKeyOffset = whiteKeyPositions[noteInOctave];
    
    final totalWhiteKeyOffset = octave * 7 + whiteKeyOffset;
    
    // Adjust for black keys
    double blackKeyAdjustment = 0;
    if ([1, 3, 6, 8, 10].contains(noteInOctave)) {
      blackKeyAdjustment = whiteKeyWidth * 0.3; // Slight adjustment for black keys
    }
    
    return totalWhiteKeyOffset * whiteKeyWidth + blackKeyAdjustment;
  }

  /// Get note height based on velocity
  double _getNoteHeight(Note note) {
    // Scale note height based on velocity (0-127)
    final baseHeight = 20.0;
    final maxHeight = 40.0;
    return baseHeight + (note.velocity / 127.0) * (maxHeight - baseHeight);
  }

  /// Convert time until hit to Y position
  double _timeToY(double timeUntilHit) {
    // Time 0 = keyboard line (bottom)
    // Positive time = above keyboard (future notes)
    // Negative time = below keyboard (past notes)
    
    final keyboardY = size.height - keyHeight;
    final pixelsPerSecond = (size.height - keyHeight) / windowDuration;
    
    return keyboardY - (timeUntilHit * pixelsPerSecond);
  }

  @override
  bool shouldRepaint(covariant PianoRenderer oldDelegate) {
    return visibleNotes != oldDelegate.visibleNotes ||
           currentTime != oldDelegate.currentTime ||
           windowDuration != oldDelegate.windowDuration ||
           size != oldDelegate.size ||
           keyHeight != oldDelegate.keyHeight ||
           handColors != oldDelegate.handColors ||
           showKeyboard != oldDelegate.showKeyboard;
  }
}
