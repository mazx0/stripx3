import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Real-time audio analysis service for audio-reactive LED lighting.
/// Captures microphone audio amplitude levels (dBFS) on Windows and Android,
/// supports input device selection (Mic, Stereo Mix, Virtual Audio Cable),
/// with automatic dynamic fallback to algorithmic beat tracking if mic is unavailable.
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _simulatedTimer;
  Timer? _beatResetTimer;

  bool _isListening = false;
  bool _isStarting = false;
  bool _isStopping = false;
  bool _hasLoggedUnavailable = false;
  double _currentLevel = 0.0; // 0.0 (silence) to 1.0 (peak loud)
  double _simPhase = 0.0;

  List<InputDevice> _availableDevices = [];
  InputDevice? _selectedDevice;

  // Live telemetry ValueNotifiers for reactive UI visualizer
  final ValueNotifier<double> audioLevelNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> audioDbNotifier = ValueNotifier<double>(-60.0);
  final ValueNotifier<bool> isBeatNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isRealMicNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<InputDevice>> devicesNotifier = ValueNotifier<List<InputDevice>>([]);

  bool get isListening => _isListening;
  double get currentLevel => _currentLevel;
  List<InputDevice> get availableDevices => _availableDevices;
  InputDevice? get selectedDevice => _selectedDevice;

  /// Load available input devices (Microphones, Stereo Mix, etc.)
  Future<List<InputDevice>> loadDevices([String? savedDeviceId]) async {
    try {
      if (await _recorder.hasPermission()) {
        final list = await _recorder.listInputDevices();
        _availableDevices = list;
        devicesNotifier.value = list;

        if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
          final match = list.where((d) => d.id == savedDeviceId);
          if (match.isNotEmpty) {
            _selectedDevice = match.first;
          }
        }
      }
    } catch (e) {
      debugPrint('AudioService loadDevices failed: $e');
    }
    return _availableDevices;
  }

  /// Change active audio input device
  Future<void> setInputDevice(InputDevice? device) async {
    _selectedDevice = device;
    if (_isListening) {
      await stopListening();
      await startListening();
    }
  }

  /// Start monitoring audio levels with concurrency locks and Windows WASAPI compatibility
  Future<void> startListening() async {
    if (_isListening || _isStarting) return;
    _isStarting = true;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (hasPermission) {
        final tempDir = await getTemporaryDirectory();
        final ext = Platform.isWindows ? 'wav' : 'm4a';
        final tempPath = p.join(tempDir.path, 'stripx_audio_probe.$ext');

        // Clean up any stale probe file before starting sink
        final probeFile = File(tempPath);
        if (await probeFile.exists()) {
          await probeFile.delete().catchError((_) => probeFile);
        }

        await _recorder.start(
          RecordConfig(
            encoder: Platform.isWindows ? AudioEncoder.wav : AudioEncoder.aacLc,
            bitRate: 64000,
            sampleRate: 44100,
            numChannels: 1,
            device: _selectedDevice,
          ),
          path: tempPath,
        );

        isRealMicNotifier.value = true;
        _hasLoggedUnavailable = false;
        _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 35)).listen((amp) {
          final db = amp.current.clamp(-55.0, -5.0);
          final normalized = (db + 55.0) / 50.0; // 0.0 to 1.0

          // Fast attack, smooth exponential decay for rhythmic lighting bounce
          if (normalized > _currentLevel) {
            _currentLevel = normalized;
          } else {
            _currentLevel = _currentLevel * 0.82 + normalized * 0.18;
          }

          audioDbNotifier.value = amp.current;
          audioLevelNotifier.value = _currentLevel;

          // Detect beat transients
          if (_currentLevel > 0.55 && normalized > 0.6) {
            isBeatNotifier.value = true;
            _beatResetTimer?.cancel();
            _beatResetTimer = Timer(const Duration(milliseconds: 100), () {
              isBeatNotifier.value = false;
            });
          }
        });

        _isListening = true;
        return;
      }
    } catch (e) {
      if (!_hasLoggedUnavailable) {
        _hasLoggedUnavailable = true;
        debugPrint('AudioService mic capture unavailable: $e. Falling back to dynamic beat synth.');
      }
    } finally {
      _isStarting = false;
    }

    // Fallback: energetic algorithmic beat generator if microphone is not accessible
    _startSimulatedAudio();
  }

  void _startSimulatedAudio() {
    _isListening = true;
    isRealMicNotifier.value = false;
    _simulatedTimer?.cancel();
    _simulatedTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _simPhase = (_simPhase + 0.12) % (2 * pi);
      final beat1 = (sin(_simPhase * 3) + 1.0) / 2.0;
      final beat2 = (cos(_simPhase * 1.5) + 1.0) / 2.0;
      final composite = (beat1 * 0.65 + beat2 * 0.35);
      _currentLevel = composite.clamp(0.0, 1.0);

      audioLevelNotifier.value = _currentLevel;
      audioDbNotifier.value = -35.0 + _currentLevel * 25.0;
      isBeatNotifier.value = _currentLevel > 0.72;
    });
  }

  /// Stop audio monitoring and release microphone resources
  Future<void> stopListening() async {
    if ((!_isListening && !_isStarting) || _isStopping) return;
    _isStopping = true;

    _simulatedTimer?.cancel();
    _simulatedTimer = null;
    _beatResetTimer?.cancel();
    _beatResetTimer = null;

    _isListening = false;
    _currentLevel = 0.0;
    audioLevelNotifier.value = 0.0;
    isBeatNotifier.value = false;

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
    } catch (_) {
    } finally {
      _isStopping = false;
    }
  }

  void dispose() {
    stopListening();
    _recorder.dispose();
  }
}
