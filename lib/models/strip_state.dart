import 'package:flutter/material.dart';

/// Supported LED strip visual animation modes.
enum StripMode {
  staticMode('Static', Icons.lightbulb_outline),
  breathing('Breathing', Icons.waves_outlined),
  wave('Rainbow Wave', Icons.water_drop_outlined),
  audio('Audio Sync', Icons.equalizer_outlined),
  strobe('Strobe', Icons.flash_on_outlined),
  firefly('Firefly', Icons.bubble_chart_outlined),
  ambient('Ambient Glow', Icons.blur_on_outlined);

  final String label;
  final IconData icon;
  const StripMode(this.label, this.icon);

  static StripMode fromString(String? val) {
    return StripMode.values.firstWhere(
      (m) => m.name.toLowerCase() == (val ?? '').toLowerCase() || m.label.toLowerCase() == (val ?? '').toLowerCase(),
      orElse: () => StripMode.staticMode,
    );
  }
}

/// Immutable state representation of the strip parameters.
class StripState {
  final bool power;
  final double brightness; // 0.0 - 1.0
  final int speed; // 1 - 100
  final Color primaryColor;
  final Color secondaryColor;
  final StripMode mode;
  final double audioSensitivity; // 0.0 - 1.0
  final bool smoothTransitions;
  final int targetFps;

  const StripState({
    this.power = true,
    this.brightness = 0.85,
    this.speed = 50,
    this.primaryColor = const Color(0xFF00E5FF), // Electric Cyan
    this.secondaryColor = const Color(0xFF8B5CF6), // Vapor Violet
    this.mode = StripMode.wave,
    this.audioSensitivity = 0.65,
    this.smoothTransitions = true,
    this.targetFps = 60,
  });

  StripState copyWith({
    bool? power,
    double? brightness,
    int? speed,
    Color? primaryColor,
    Color? secondaryColor,
    StripMode? mode,
    double? audioSensitivity,
    bool? smoothTransitions,
    int? targetFps,
  }) {
    return StripState(
      power: power ?? this.power,
      brightness: brightness ?? this.brightness,
      speed: speed ?? this.speed,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      mode: mode ?? this.mode,
      audioSensitivity: audioSensitivity ?? this.audioSensitivity,
      smoothTransitions: smoothTransitions ?? this.smoothTransitions,
      targetFps: targetFps ?? this.targetFps,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'power': power,
      'brightness': double.parse(brightness.toStringAsFixed(3)),
      'speed': speed,
      'primaryColor': primaryColor.toARGB32(),
      'secondaryColor': secondaryColor.toARGB32(),
      'mode': mode.name,
      'audioSensitivity': double.parse(audioSensitivity.toStringAsFixed(3)),
      'smoothTransitions': smoothTransitions,
      'targetFps': targetFps,
    };
  }

  factory StripState.fromJson(Map<String, dynamic> json) {
    return StripState(
      power: json['power'] as bool? ?? true,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0.85,
      speed: (json['speed'] as num?)?.toInt() ?? 50,
      primaryColor: json['primaryColor'] != null
          ? Color((json['primaryColor'] as num).toInt())
          : const Color(0xFF00E5FF),
      secondaryColor: json['secondaryColor'] != null
          ? Color((json['secondaryColor'] as num).toInt())
          : const Color(0xFF8B5CF6),
      mode: StripMode.fromString(json['mode'] as String?),
      audioSensitivity: (json['audioSensitivity'] as num?)?.toDouble() ?? 0.65,
      smoothTransitions: json['smoothTransitions'] as bool? ?? true,
      targetFps: (json['targetFps'] as num?)?.toInt() ?? 60,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StripState &&
          runtimeType == other.runtimeType &&
          power == other.power &&
          (brightness - other.brightness).abs() < 0.001 &&
          speed == other.speed &&
          primaryColor.toARGB32() == other.primaryColor.toARGB32() &&
          secondaryColor.toARGB32() == other.secondaryColor.toARGB32() &&
          mode == other.mode &&
          (audioSensitivity - other.audioSensitivity).abs() < 0.001 &&
          smoothTransitions == other.smoothTransitions &&
          targetFps == other.targetFps;

  @override
  int get hashCode =>
      power.hashCode ^
      brightness.hashCode ^
      speed.hashCode ^
      primaryColor.hashCode ^
      secondaryColor.hashCode ^
      mode.hashCode ^
      audioSensitivity.hashCode ^
      smoothTransitions.hashCode ^
      targetFps.hashCode;
}
