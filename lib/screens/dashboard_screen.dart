import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/platform_helper.dart';
import '../../models/strip_state.dart';
import '../../providers/ble_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/strip_state_provider.dart';
import '../../widgets/common/custom_slider.dart';
import '../../widgets/common/minimalist_card.dart';
import '../../widgets/common/status_pill.dart';
import '../../widgets/dashboard/audio_visualizer_card.dart';
import '../../widgets/dashboard/color_palette_picker.dart';
import '../../widgets/dashboard/effect_selector.dart';
import '../../widgets/dashboard/live_metrics_card.dart';
import '../../widgets/dashboard/power_banner.dart';

/// Main StripX Control Dashboard screen.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stripState = ref.watch(stripStateProvider);
    final stripNotifier = ref.read(stripStateProvider.notifier);
    final connection = ref.watch(connectionProvider);
    final bleState = ref.watch(bleProvider);

    final isDesktop = PlatformHelper.isDesktop;
    final horizontalPadding = isDesktop ? 20.0 : 12.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header with Title and Connection Status Pill (Desktop only to prevent mobile duplication)
                if (isDesktop) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hardware Dashboard', style: AppTypography.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            'Real-time synchronized LED controller',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (bleState.isConnected) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withAlpha(25),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.accent),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bluetooth_connected, size: 12, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    bleState.connectedDeviceName ?? 'BLE Connected',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          StatusPill(
                            status: connection.status,
                            pingMs: connection.pingMs,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Master Power Banner (Tactile Button only, no redundant toggle)
                PowerBanner(
                  state: stripState,
                  onTogglePower: stripNotifier.togglePower,
                ),
                const SizedBox(height: 12),

                // Controls Grid / Sliders
                MinimalistCard(
                  title: 'LIGHTING CONTROLS',
                  child: Column(
                    children: [
                      // Brightness Slider
                      CustomSlider(
                        label: 'Master Brightness',
                        icon: Icons.brightness_6_outlined,
                        value: stripState.brightness,
                        min: 0.0,
                        max: 1.0,
                        valueDisplay: '${(stripState.brightness * 100).round()}%',
                        enabled: stripState.power,
                        onChanged: (val) => stripNotifier.setBrightness(val),
                      ),
                      const SizedBox(height: 14),

                      // Animation Speed Slider
                      CustomSlider(
                        label: 'Animation Speed',
                        icon: Icons.speed_outlined,
                        value: stripState.speed.toDouble(),
                        min: 1.0,
                        max: 100.0,
                        divisions: 99,
                        step: 1.0,
                        valueDisplay: '${stripState.speed}%',
                        enabled: stripState.power,
                        onChanged: (val) => stripNotifier.setSpeed(val.round()),
                      ),
                      const SizedBox(height: 14),

                      // Audio Reactive Sensitivity Slider
                      CustomSlider(
                        label: 'Audio Sensitivity',
                        icon: Icons.graphic_eq_outlined,
                        value: stripState.audioSensitivity,
                        min: 0.0,
                        max: 1.0,
                        valueDisplay: '${(stripState.audioSensitivity * 100).round()}%',
                        enabled: stripState.power,
                        onChanged: (val) => stripNotifier.setAudioSensitivity(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Live Audio Reactive Telemetry & Device Config (shown in Audio Sync mode)
                if (stripState.mode == StripMode.audio && stripState.power) ...[
                  AudioVisualizerCard(storage: ref.read(storageServiceProvider)),
                  const SizedBox(height: 12),
                ],

                // Animation Effects Selector
                MinimalistCard(
                  title: 'ANIMATION PATTERN',
                  child: EffectSelector(
                    currentMode: stripState.mode,
                    enabled: stripState.power,
                    onModeSelected: (mode) => stripNotifier.setMode(mode),
                  ),
                ),
                const SizedBox(height: 12),

                // Color Engine & Hue Palette
                MinimalistCard(
                  title: 'COLOR ENGINE',
                  child: ColorPalettePicker(
                    primaryColor: stripState.primaryColor,
                    secondaryColor: stripState.secondaryColor,
                    enabled: stripState.power,
                    onPrimaryColorChanged: (c) => stripNotifier.setPrimaryColor(c),
                    onSecondaryColorChanged: (c) => stripNotifier.setSecondaryColor(c),
                  ),
                ),
                const SizedBox(height: 12),

                // Real-time Telemetry & Performance
                LiveMetricsCard(connection: connection),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
