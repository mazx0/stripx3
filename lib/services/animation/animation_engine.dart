import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/strip_state.dart';
import '../audio/audio_service.dart';

typedef OnAnimationFrame = void Function(Color animatedColor, double animatedBrightness);

/// Real-time 30 FPS animation engine driving dynamic lighting patterns.
/// Works universally across all Bluetooth controllers, the UI visualizer, and local sync clients.
class AnimationEngine {
  static final AnimationEngine _instance = AnimationEngine._internal();
  factory AnimationEngine() => _instance;
  AnimationEngine._internal();

  Timer? _loopTimer;
  double _phase = 0.0;
  StripState _state = const StripState();

  final ValueNotifier<Color> liveColor = ValueNotifier<Color>(const Color(0xFF00E5FF));
  final ValueNotifier<double> liveBrightness = ValueNotifier<double>(1.0);

  OnAnimationFrame? onFrame;

  bool get isRunning => _loopTimer != null;

  void updateState(StripState newState) {
    _state = newState;

    // Manage AudioService listener lifecycle strictly on mode/power state
    final shouldListenAudio = _state.power && _state.mode == StripMode.audio;
    if (shouldListenAudio) {
      if (!AudioService().isListening) {
        AudioService().startListening();
      }
    } else {
      if (AudioService().isListening) {
        AudioService().stopListening();
      }
    }

    if (!_state.power || _state.mode == StripMode.staticMode) {
      stop();
      liveColor.value = _state.primaryColor;
      liveBrightness.value = _state.brightness;
    } else {
      if (!isRunning) {
        start();
      }
    }
  }

  void start() {
    if (isRunning) return;
    if (!_state.power || _state.mode == StripMode.staticMode) {
      liveColor.value = _state.primaryColor;
      liveBrightness.value = _state.brightness;
      return;
    }

    if (_state.mode == StripMode.audio && !AudioService().isListening) {
      AudioService().startListening();
    }

    // Tick first frame immediately
    _tick();

    // ~30 fps calculation loop (33ms)
    _loopTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _tick();
    });
  }

  void stop() {
    _loopTimer?.cancel();
    _loopTimer = null;
    _phase = 0.0;
  }

  void _tick() {
    if (!_state.power || _state.mode == StripMode.staticMode) {
      stop();
      liveColor.value = _state.primaryColor;
      liveBrightness.value = _state.brightness;
      return;
    }

    // Step rate based on user speed (1 - 100)
    final step = (0.01 + (_state.speed / 100.0) * 0.06);
    _phase = (_phase + step) % (2 * pi);

    Color frameColor = _state.primaryColor;
    double frameBrightness = _state.brightness;

    switch (_state.mode) {
      case StripMode.staticMode:
        return;

      case StripMode.breathing:
        // Smooth sinusoidal fading using purely the user's primary color
        final sineVal = (sin(_phase) + 1.0) / 2.0; // 0.0 to 1.0
        final modulatedBrightness = (0.04 + sineVal * 0.96) * _state.brightness;
        frameBrightness = modulatedBrightness;
        frameColor = _state.primaryColor;
        break;

      case StripMode.wave:
        // Smooth 360-degree rainbow spectrum cycle
        final hue = (_phase / (2 * pi) * 360.0);
        frameColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
        frameBrightness = _state.brightness;
        break;

      case StripMode.strobe:
        // Sharp rhythmic flash pulses using primary color
        final flash = (sin(_phase * 3) > 0.25);
        frameBrightness = flash ? _state.brightness : 0.0;
        frameColor = _state.primaryColor;
        break;

      case StripMode.firefly:
        // Warm organic flickering between primary and secondary accent
        final sine1 = sin(_phase * 1.5);
        final sine2 = cos(_phase * 2.7);
        final t = ((sine1 + sine2 + 2.0) / 4.0).clamp(0.0, 1.0);
        frameColor = Color.lerp(_state.primaryColor, _state.secondaryColor, t) ?? _state.primaryColor;
        frameBrightness = (0.25 + 0.75 * t) * _state.brightness;
        break;

      case StripMode.ambient:
        // Gentle pastel gradient shifting between primary and secondary accent
        final t = (sin(_phase * 0.5) + 1.0) / 2.0;
        frameColor = Color.lerp(_state.primaryColor, _state.secondaryColor, t) ?? _state.primaryColor;
        frameBrightness = (0.45 + 0.55 * sin(_phase * 0.7).abs()) * _state.brightness;
        break;

      case StripMode.audio:
        // Live audio level from microphone (or dynamic beat fallback)
        final audioLevel = AudioService().currentLevel;
        final sensitivityFactor = (0.4 + _state.audioSensitivity * 1.6);
        final intensity = (audioLevel * sensitivityFactor).clamp(0.0, 1.0);

        // Dynamic audio bounce: drops to 10% on silence, flares up to 100% on bass/loud beats
        frameBrightness = (0.10 + intensity * 0.90) * _state.brightness;

        // Smooth transition from secondaryColor to primaryColor on audio peaks
        frameColor = Color.lerp(_state.secondaryColor, _state.primaryColor, intensity) ?? _state.primaryColor;
        break;
    }

    liveColor.value = frameColor;
    liveBrightness.value = frameBrightness;
    onFrame?.call(frameColor, frameBrightness);
  }
}
