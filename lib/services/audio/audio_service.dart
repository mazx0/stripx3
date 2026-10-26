import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Real-time audio analysis service for audio-reactive LED lighting.
/// Captures microphone audio amplitude levels (dBFS) on Windows and Android,
/// with automatic dynamic fallback to algorithmic beat tracking if mic is unavailable.
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _simulatedTimer;

  bool _isListening = false;
  double _currentLevel = 0.0; // 0.0 (silence) to 1.0 (peak loud)
  double _simPhase = 0.0;

  bool get isListening => _isListening;
  double get currentLevel => _currentLevel;

  /// Start monitoring audio levels
  Future<void> startListening() async {
    if (_isListening) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (hasPermission) {
        final tempDir = await getTemporaryDirectory();
        final tempPath = p.join(tempDir.path, 'stripx_audio_probe.m4a');

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 32000,
            sampleRate: 16000,
          ),
          path: tempPath,
        );

        _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 35)).listen((amp) {
          // dBFS is typically -60.0 dB (ambient/silence) to 0.0 dB (peak loud)
          final db = amp.current.clamp(-55.0, -5.0);
          final normalized = (db + 55.0) / 50.0; // 0.0 to 1.0

          // Fast attack, smooth exponential decay for rhythmic lighting bounce
          if (normalized > _currentLevel) {
            _currentLevel = normalized;
          } else {
            _currentLevel = _currentLevel * 0.82 + normalized * 0.18;
          }
        });

        _isListening = true;
        return;
      }
    } catch (e) {
      debugPrint('AudioService mic capture unavailable ($e). Falling back to dynamic beat synth.');
    }

    // Fallback: energetic algorithmic beat generator if microphone is not accessible
    _startSimulatedAudio();
  }

  void _startSimulatedAudio() {
    _isListening = true;
    _simulatedTimer?.cancel();
    _simulatedTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _simPhase = (_simPhase + 0.12) % (2 * pi);
      final beat1 = (sin(_simPhase * 3) + 1.0) / 2.0;
      final beat2 = (cos(_simPhase * 1.5) + 1.0) / 2.0;
      final composite = (beat1 * 0.65 + beat2 * 0.35);
      _currentLevel = composite.clamp(0.0, 1.0);
    });
  }

  /// Stop audio monitoring and release microphone resources
  Future<void> stopListening() async {
    _simulatedTimer?.cancel();
    _simulatedTimer = null;

    if (_isListening) {
      _isListening = false;
      _currentLevel = 0.0;
      try {
        await _ampSub?.cancel();
        _ampSub = null;
        if (await _recorder.isRecording()) {
          final recordedPath = await _recorder.stop();
          if (recordedPath != null) {
            final file = File(recordedPath);
            if (await file.exists()) {
              await file.delete().catchError((_) => file);
            }
          }
        }
      } catch (_) {}
    }
  }

  void dispose() {
    stopListening();
    _recorder.dispose();
  }
}
