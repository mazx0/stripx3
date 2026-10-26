import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/throttle.dart';
import '../../models/strip_state.dart';
import '../../services/animation/animation_engine.dart';
import '../../services/storage/storage_service.dart';

typedef OnNetworkBroadcastCallback = void Function(String key, dynamic value);

class StripStateNotifier extends Notifier<StripState> {
  StorageService? _storage;
  OnNetworkBroadcastCallback? onNetworkBroadcast;
  OnNetworkBroadcastCallback? onBleBroadcast;

  late final Throttler _brightnessThrottler;
  late final Throttler _speedThrottler;
  late final Throttler _sensitivityThrottler;
  final Debouncer _saveDebouncer = Debouncer(duration: const Duration(milliseconds: 500));

  @override
  StripState build() {
    _brightnessThrottler = Throttler(duration: const Duration(milliseconds: AppConstants.sliderThrottleMs));
    _speedThrottler = Throttler(duration: const Duration(milliseconds: AppConstants.sliderThrottleMs));
    _sensitivityThrottler = Throttler(duration: const Duration(milliseconds: AppConstants.sliderThrottleMs));

    return const StripState();
  }

  void initialize(StorageService storage) {
    _storage = storage;
    final saved = _storage?.getSavedStripState();
    if (saved != null) {
      state = saved;
    }
    AnimationEngine().updateState(state);
  }

  void setNetworkBroadcastCallback(OnNetworkBroadcastCallback callback) {
    onNetworkBroadcast = callback;
  }

  void setBleBroadcastCallback(OnNetworkBroadcastCallback callback) {
    onBleBroadcast = callback;
  }

  void togglePower() {
    setPower(!state.power);
  }

  void setPower(bool value) {
    state = state.copyWith(power: value);
    AnimationEngine().updateState(state);
    onNetworkBroadcast?.call('power', value);
    onBleBroadcast?.call('power', value);
    _persist();
  }

  void setBrightness(double value) {
    final clamped = value.clamp(0.0, 1.0);
    state = state.copyWith(brightness: clamped);
    AnimationEngine().updateState(state);
    _brightnessThrottler.run(() {
      onNetworkBroadcast?.call('brightness', clamped);
      onBleBroadcast?.call('brightness', clamped);
      _persist();
    });
  }

  void setSpeed(int value) {
    final clamped = value.clamp(1, 100);
    state = state.copyWith(speed: clamped);
    AnimationEngine().updateState(state);
    _speedThrottler.run(() {
      onNetworkBroadcast?.call('speed', clamped);
      onBleBroadcast?.call('speed', clamped);
      _persist();
    });
  }

  void setMode(StripMode mode) {
    state = state.copyWith(mode: mode);
    AnimationEngine().updateState(state);
    onNetworkBroadcast?.call('mode', mode.name);
    onBleBroadcast?.call('mode', mode.name);
    if (mode == StripMode.staticMode) {
      onBleBroadcast?.call('primaryColor', state.primaryColor.toARGB32());
    }
    _persist();
  }

  void setPrimaryColor(Color color) {
    state = state.copyWith(primaryColor: color);
    AnimationEngine().updateState(state);
    onNetworkBroadcast?.call('primaryColor', color.toARGB32());
    onBleBroadcast?.call('primaryColor', color.toARGB32());
    _persist();
  }

  void setSecondaryColor(Color color) {
    state = state.copyWith(secondaryColor: color);
    AnimationEngine().updateState(state);
    onNetworkBroadcast?.call('secondaryColor', color.toARGB32());
    _persist();
  }

  void setAudioSensitivity(double value) {
    final clamped = value.clamp(0.0, 1.0);
    state = state.copyWith(audioSensitivity: clamped);
    AnimationEngine().updateState(state);
    _sensitivityThrottler.run(() {
      onNetworkBroadcast?.call('audioSensitivity', clamped);
      _persist();
    });
  }

  void setSmoothTransitions(bool value) {
    state = state.copyWith(smoothTransitions: value);
    onNetworkBroadcast?.call('smoothTransitions', value);
    _persist();
  }

  /// Sync full state received from peer over network
  void syncFromNetwork(StripState newState) {
    state = newState;
    AnimationEngine().updateState(state);
    _persist();
  }

  /// Incremental parameter sync from peer
  void syncParamFromNetwork(String key, dynamic value) {
    switch (key) {
      case 'power':
        if (value is bool) state = state.copyWith(power: value);
        break;
      case 'brightness':
        if (value is num) state = state.copyWith(brightness: value.toDouble());
        break;
      case 'speed':
        if (value is num) state = state.copyWith(speed: value.toInt());
        break;
      case 'mode':
        if (value is String) state = state.copyWith(mode: StripMode.fromString(value));
        break;
      case 'primaryColor':
        if (value is num) state = state.copyWith(primaryColor: Color(value.toInt()));
        break;
      case 'secondaryColor':
        if (value is num) state = state.copyWith(secondaryColor: Color(value.toInt()));
        break;
      case 'audioSensitivity':
        if (value is num) state = state.copyWith(audioSensitivity: value.toDouble());
        break;
      case 'smoothTransitions':
        if (value is bool) state = state.copyWith(smoothTransitions: value);
        break;
    }
    AnimationEngine().updateState(state);
    _persist();
  }

  void _persist() {
    _saveDebouncer.run(() {
      _storage?.saveStripState(state);
    });
  }
}

final stripStateProvider = NotifierProvider<StripStateNotifier, StripState>(() {
  return StripStateNotifier();
});
