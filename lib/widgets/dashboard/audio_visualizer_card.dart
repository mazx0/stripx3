import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../services/audio/audio_service.dart';
import '../../services/storage/storage_service.dart';

/// Live interactive Audio Sync telemetry meter and device configuration card.
/// Provides real-time VU-meter, dBFS feedback, beat detection, and audio input selector.
class AudioVisualizerCard extends StatefulWidget {
  final StorageService? storage;

  const AudioVisualizerCard({
    super.key,
    this.storage,
  });

  @override
  State<AudioVisualizerCard> createState() => _AudioVisualizerCardState();
}

class _AudioVisualizerCardState extends State<AudioVisualizerCard> {
  final AudioService _audioService = AudioService();
  bool _loadingDevices = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _loadingDevices = true);
    final savedId = widget.storage?.getSelectedAudioDeviceId();
    await _audioService.loadDevices(savedId);
    if (mounted) {
      setState(() => _loadingDevices = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Live Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.graphic_eq, color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'AUDIO SYNC TELEMETRY',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Mic vs Synth Mode Badge
                    ValueListenableBuilder<bool>(
                      valueListenable: _audioService.isRealMicNotifier,
                      builder: (context, isMic, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isMic ? AppColors.successMuted : AppColors.warningMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isMic ? AppColors.success : AppColors.warning,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isMic ? AppColors.success : AppColors.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isMic ? 'MIC ACTIVE' : 'SYNTH FALLBACK',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isMic ? AppColors.success : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Beat Pulse Indicator
                    ValueListenableBuilder<bool>(
                      valueListenable: _audioService.isBeatNotifier,
                      builder: (context, isBeat, _) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 90),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isBeat ? AppColors.accent : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isBeat ? AppColors.accent : AppColors.border,
                            ),
                            boxShadow: isBeat
                                ? [
                                    BoxShadow(
                                      color: AppColors.accent.withAlpha(120),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            'BEAT',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isBeat ? Colors.black : AppColors.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Live VU-Meter Bar
            ValueListenableBuilder<double>(
              valueListenable: _audioService.audioLevelNotifier,
              builder: (context, level, _) {
                final pct = (level * 100).round();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Live Input Level', style: AppTypography.bodyMuted),
                        Row(
                          children: [
                            Text(
                              '$pct%',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<double>(
                              valueListenable: _audioService.audioDbNotifier,
                              builder: (context, db, _) {
                                return Text(
                                  '${db.toStringAsFixed(1)} dBFS',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textTertiary,
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: level.clamp(0.01, 1.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accent,
                                  Color(0xFF8B5CF6),
                                  Color(0xFFEC4899),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // Device Configuration Section
            ValueListenableBuilder<List<InputDevice>>(
              valueListenable: _audioService.devicesNotifier,
              builder: (context, devices, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Input Device (Microphone / Stereo Mix)',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        IconButton(
                          icon: _loadingDevices
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent),
                                )
                              : const Icon(Icons.refresh, size: 16),
                          tooltip: 'Rescan Audio Devices',
                          color: AppColors.textTertiary,
                          onPressed: _loadingDevices ? null : _loadDevices,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _audioService.selectedDevice?.id,
                          hint: Text(
                            devices.isEmpty ? 'System Default Audio Input' : 'Select Audio Source...',
                            style: AppTypography.bodyMuted,
                          ),
                          isExpanded: true,
                          dropdownColor: AppColors.surfaceElevated,
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Default System Audio Input', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                            ),
                            ...devices.map((d) {
                              return DropdownMenuItem<String>(
                                value: d.id,
                                child: Text(
                                  d.label.isNotEmpty ? d.label : 'Device ${d.id}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: (selectedId) async {
                            InputDevice? selected;
                            if (selectedId != null) {
                              final matches = devices.where((d) => d.id == selectedId);
                              if (matches.isNotEmpty) selected = matches.first;
                            }
                            await _audioService.setInputDevice(selected);
                            if (selectedId != null) {
                              widget.storage?.setSelectedAudioDeviceId(selectedId);
                            }
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Helpful configuration tip
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighlight.withAlpha(80),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border.withAlpha(120)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'To sync with PC music (Spotify, YouTube, Games), select "Stereo Mix" or "Virtual Cable" as the input source above.',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
