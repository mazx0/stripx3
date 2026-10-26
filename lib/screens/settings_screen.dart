import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/platform_helper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../services/tray/system_tray_service.dart';
import '../../widgets/common/minimalist_card.dart';

/// Application configuration and preferences screen.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _manifestUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _manifestUrlController.text = settings.updateManifestUrl;
  }

  @override
  void dispose() {
    _manifestUrlController.dispose();
    super.dispose();
  }

  Widget _buildSettingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.body),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final updateNotifier = ref.read(updateProvider.notifier);
    final updateState = ref.watch(updateProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text('System Preferences', style: AppTypography.titleLarge),
                const SizedBox(height: 2),
                Text(
                  'Network configuration, background services, and self-hosted auto-update',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 16),

                // Background & System Tray (Desktop Only)
                if (PlatformHelper.isDesktop) ...[
                  MinimalistCard(
                    title: 'WINDOWS BACKGROUND RUNNER',
                    child: Column(
                      children: [
                        _buildSettingSwitch(
                          title: 'Minimize to System Tray on Close',
                          subtitle: 'Clicking the window close button will hide StripX to the taskbar notification tray',
                          value: settings.minimizeToTray,
                          onChanged: (val) {
                            settingsNotifier.setMinimizeToTray(val);
                            SystemTrayService().updateMinimizeToTrayPreference(val);
                          },
                        ),
                        const Divider(),
                        _buildSettingSwitch(
                          title: 'Auto-Start Host on Launch',
                          subtitle: 'Automatically start the local WebSocket server when the Windows app starts',
                          value: settings.autoStartHost,
                          onChanged: (val) => settingsNotifier.setAutoStartHost(val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Auto-Updater Settings
                MinimalistCard(
                  title: 'AUTO-UPDATE SYSTEM',
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.sync, size: 14, color: Colors.black),
                    label: const Text(
                      'Check Now',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 0,
                    ),
                    onPressed: () => updateNotifier.checkForUpdates(quiet: false),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSettingSwitch(
                        title: 'Quiet Startup Update Check',
                        subtitle: 'Silently queries version manifest on launch and displays Discord banner if new version is found',
                        value: settings.autoUpdateCheck,
                        onChanged: (val) => settingsNotifier.setAutoUpdateCheck(val),
                      ),
                      const SizedBox(height: 10),
                      Text('SELF-HOSTED VERSION MANIFEST URL', style: AppTypography.caption),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manifestUrlController,
                              decoration: const InputDecoration(
                                hintText: 'https://...',
                                prefixIcon: Icon(Icons.cloud_outlined, size: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceElevated,
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                            onPressed: () {
                              settingsNotifier.setUpdateManifestUrl(_manifestUrlController.text.trim());
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Update URL saved')),
                              );
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                      if (updateState.statusMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          updateState.statusMessage!,
                          style: AppTypography.caption.copyWith(color: AppColors.accent),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Architecture and Performance Specs
                MinimalistCard(
                  title: 'SYSTEM SPECIFICATIONS',
                  child: Column(
                    children: [
                      _buildSpecRow('StripX Architecture', 'Dart 3 AOT / Asynchronous I/O'),
                      _buildSpecRow('Target Platforms', 'Windows Desktop (x64) & Android (APK)'),
                      _buildSpecRow('Bluetooth Support', 'Universal BLE (ELK-BLEDOM, Triones, Zengge, Govee)'),
                      _buildSpecRow('Idle RAM Footprint', '< 45 MB on PC / < 30 MB on Mobile'),
                      _buildSpecRow('Network Protocol', 'Native WebSocket + UDP Broadcast (sub-5ms)'),
                      _buildSpecRow('Frame Rate Target', '60.0 FPS locked'),
                      _buildSpecRow('Build Version', 'v${AppConstants.appVersion} (Production)'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTypography.mono.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
