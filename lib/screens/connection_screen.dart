import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/platform_helper.dart';
import '../../models/connection_state.dart';
import '../../providers/ble_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/ble/ble_service.dart';
import '../../widgets/common/minimalist_card.dart';
import '../../widgets/common/status_pill.dart';

/// Connection Hub managing Bluetooth (BLE) LED devices and Wi-Fi Host/Client Sync.
class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  int _activeConnectionTab = 0; // 0 = Bluetooth (BLE), 1 = Wi-Fi Sync

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _ipController.text = settings.lastIp ?? '';
    _portController.text = settings.hostPort.toString();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _connectManual() {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? AppConstants.defaultWsPort;

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid IP address')),
      );
      return;
    }

    ref.read(connectionProvider.notifier).connectToHost(ip, port: port);
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionProvider);
    final connectionNotifier = ref.read(connectionProvider.notifier);
    final bleState = ref.watch(bleProvider);
    final bleNotifier = ref.read(bleProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final isDesktop = PlatformHelper.isDesktop;
    final horizontalPadding = isDesktop ? 20.0 : 12.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with Badges (Desktop only to prevent redundant status bars on mobile)
                if (isDesktop) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hardware Connection', style: AppTypography.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            'Direct Bluetooth (BLE) link & Wi-Fi local sync',
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
                                  const Icon(Icons.bluetooth_connected, size: 13, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'BLE: ${bleState.connectedDeviceName ?? "Connected"}',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          StatusPill(
                            status: connection.status,
                            pingMs: connection.pingMs,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Top Connection Hub Tabs (Bluetooth vs Wi-Fi)
                Row(
                  children: [
                    Expanded(
                      child: _buildConnectionModeTab(
                        title: 'Bluetooth (BLE)',
                        subtitle: bleState.isConnected ? 'Connected to LED Strip' : 'Direct hardware control',
                        icon: Icons.bluetooth,
                        isSelected: _activeConnectionTab == 0,
                        onTap: () => setState(() => _activeConnectionTab = 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildConnectionModeTab(
                        title: 'Local Wi-Fi Sync',
                        subtitle: connection.isConnected ? 'Host / Client Active' : 'PC & Mobile sync link',
                        icon: Icons.wifi_tethering,
                        isSelected: _activeConnectionTab == 1,
                        onTap: () => setState(() => _activeConnectionTab = 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Error Message if any
                if (bleState.errorMessage != null && _activeConnectionTab == 0) ...[
                  _buildErrorAlert(bleState.errorMessage!),
                  const SizedBox(height: 16),
                ],
                if (connection.errorMessage != null && _activeConnectionTab == 1) ...[
                  _buildErrorAlert(connection.errorMessage!),
                  const SizedBox(height: 16),
                ],

                // Active Tab Content
                if (_activeConnectionTab == 0)
                  _buildBleView(bleState, bleNotifier)
                else
                  _buildWifiSyncView(connection, connectionNotifier, settings),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorAlert(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionModeTab({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceHighlight : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent.withAlpha(25) : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppColors.accent : AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 14,
                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BLUETOOTH (BLE) VIEW
  // ===========================================================================

  Widget _buildBleView(BleState bleState, BleNotifier bleNotifier) {
    return Column(
      children: [
        // Connected BLE Device Card (if connected)
        if (bleState.isConnected) ...[
          MinimalistCard(
            title: 'CONNECTED BLUETOOTH STRIP',
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.bluetooth_disabled, size: 14),
              label: const Text('Disconnect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorMuted,
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 0,
              ),
              onPressed: () => bleNotifier.disconnect(),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successMuted,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.success),
                  ),
                  child: const Icon(Icons.lightbulb, color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bleState.connectedDeviceName ?? 'BLE Light Strip',
                        style: AppTypography.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Protocol: ${bleState.activeProtocol.label} • Device ID: ${bleState.connectedDeviceId ?? "Unknown"}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Saved Strips (Fast Connect)
        MinimalistCard(
          title: 'SAVED STRIPS (FAST CONNECT)',
          trailing: bleState.savedDevices.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accent.withAlpha(80)),
                  ),
                  child: Text(
                    '${bleState.savedDevices.length} saved',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Previously connected strips. Tap "Fast Connect" to instantly link without scanning.',
                style: AppTypography.bodyMuted,
              ),
              const SizedBox(height: 12),
              if (bleState.savedDevices.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.bookmark_border, size: 24, color: AppColors.textTertiary),
                      const SizedBox(height: 8),
                      Text('No saved strips yet', style: AppTypography.body),
                      const SizedBox(height: 2),
                      Text(
                        'Connect to any Bluetooth strip to save it here for 1-tap reconnect',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: bleState.savedDevices.map((device) {
                    final id = device['id'] ?? '';
                    final name = device['name'] ?? 'LED Strip';
                    final proto = device['protocol'] ?? 'bledom';
                    final isThisConnected = bleState.isConnected && bleState.connectedDeviceId == id;
                    final isConnecting = bleState.status == BleStatus.connecting && bleState.connectedDeviceId == id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isThisConnected ? AppColors.surfaceHighlight : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isThisConnected ? AppColors.accent : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isThisConnected ? Icons.lightbulb : Icons.lightbulb_outline,
                            color: isThisConnected ? AppColors.accent : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: AppTypography.titleMedium.copyWith(fontSize: 13),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withAlpha(20),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        proto.toUpperCase(),
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.accent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  id,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Fast Connect or Connected Status
                          if (isThisConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.successMuted,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.success),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check, size: 12, color: AppColors.success),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Active',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              icon: isConnecting
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.bolt, size: 14),
                              label: Text(
                                isConnecting ? 'Connecting...' : 'Fast Connect',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                elevation: 0,
                              ),
                              onPressed: isConnecting
                                  ? null
                                  : () => bleNotifier.connect(id, deviceName: name),
                            ),
                          const SizedBox(width: 8),
                          // Remove saved device
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            color: AppColors.textTertiary,
                            hoverColor: AppColors.errorMuted,
                            tooltip: 'Remove from saved strips',
                            onPressed: () => bleNotifier.removeSavedDevice(id),
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // BLE Scanner Card
        MinimalistCard(
          title: 'NEARBY BLUETOOTH CONTROLLERS',
          trailing: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Show all', style: AppTypography.caption),
                  const SizedBox(width: 4),
                  Switch(
                    value: bleState.showAllDevices,
                    onChanged: (val) => bleNotifier.toggleShowAll(val),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: Icon(
                  bleState.isScanning ? Icons.stop : Icons.search,
                  size: 15,
                  color: bleState.isScanning ? AppColors.error : Colors.black,
                ),
                label: Text(
                  bleState.isScanning ? 'Stop' : 'Scan BLE',
                  style: TextStyle(
                    color: bleState.isScanning ? AppColors.error : Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bleState.isScanning ? AppColors.errorMuted : AppColors.accent,
                  side: bleState.isScanning ? const BorderSide(color: AppColors.error) : null,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 0,
                ),
                onPressed: () {
                  if (bleState.isScanning) {
                    bleNotifier.stopScan();
                  } else {
                    bleNotifier.startScan();
                  }
                },
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scans for ELK-BLEDOM, Triones, Zengge, Govee, and Generic Bluetooth LED strip hardware.',
                style: AppTypography.bodyMuted,
              ),
              const SizedBox(height: 14),
              if (bleState.devices.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      if (bleState.isScanning) ...[
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Scanning for Bluetooth devices...', style: AppTypography.body),
                        const SizedBox(height: 4),
                        Text('Make sure your LED strip is powered on', style: AppTypography.caption),
                      ] else ...[
                        const Icon(Icons.bluetooth_searching, size: 28, color: AppColors.textTertiary),
                        const SizedBox(height: 10),
                        Text('No Bluetooth devices scanned yet', style: AppTypography.body),
                        const SizedBox(height: 4),
                        Text('Click "Scan BLE" above to search for nearby strips', style: AppTypography.caption),
                      ],
                    ],
                  ),
                )
              else
                Column(
                  children: bleState.devices.map((device) {
                    final isThisConnected = bleState.isConnected && bleState.connectedDeviceId == device.id;
                    final isConnecting = bleState.status == BleStatus.connecting && bleState.connectedDeviceId == device.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isThisConnected ? AppColors.surfaceHighlight : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isThisConnected ? AppColors.accent : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            device.isKnownLed ? Icons.lightbulb_outline : Icons.bluetooth,
                            color: device.isKnownLed ? AppColors.accent : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        device.name,
                                        style: AppTypography.titleMedium.copyWith(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (device.isKnownLed) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentMuted,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'LED STRIP',
                                          style: AppTypography.caption.copyWith(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: ${device.id} • Signal: ${device.rssi} dBm',
                                  style: AppTypography.mono.copyWith(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: isConnecting
                                ? null
                                : (isThisConnected
                                    ? () => bleNotifier.disconnect()
                                    : () => bleNotifier.connect(device.id, deviceName: device.name)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isThisConnected ? AppColors.errorMuted : AppColors.accent,
                              foregroundColor: isThisConnected ? AppColors.error : Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              elevation: 0,
                              minimumSize: Size.zero,
                            ),
                            child: Text(
                              isConnecting
                                  ? 'Linking...'
                                  : (isThisConnected ? 'Disconnect' : 'Connect'),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Bluetooth Troubleshooting Guide
        MinimalistCard(
          title: 'HOW TO CONNECT OVER BLE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGuideStep('1', 'Turn On Your Strip', 'Ensure the LED strip power adapter is plugged into the wall and glowing.'),
              _buildGuideStep('2', 'Enable Bluetooth', 'Ensure Bluetooth is turned on in your Windows / Android system settings.'),
              _buildGuideStep('3', 'Scan & Pair', 'Click "Scan BLE". When your strip appears (e.g. ELK-BLEDOM, Triones), click "Connect".'),
              _buildGuideStep('4', 'Control Dashboard', 'Once connected, adjusting colors, sliders, and power will immediately send packets over Bluetooth!'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuideStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentMuted,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 1),
            ),
            child: Text(
              number,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium.copyWith(fontSize: 13)),
                Text(description, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WI-FI SYNC VIEW (PC HOST / ANDROID CLIENT)
  // ===========================================================================

  Widget _buildWifiSyncView(
    AppConnectionState connection,
    ConnectionNotifier notifier,
    AppSettings settings,
  ) {
    final isHost = connection.role == AppRole.host;

    return Column(
      children: [
        // Role Toggle
        MinimalistCard(
          title: 'APPLICATION ROLE',
          child: Row(
            children: [
              Expanded(
                child: _buildRoleSelectorTab(
                  title: 'Windows Host (Server)',
                  subtitle: 'Runs local WebSocket host on PC',
                  icon: Icons.computer_outlined,
                  isSelected: isHost,
                  onTap: () => notifier.switchRole(AppRole.host),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRoleSelectorTab(
                  title: 'Android Client (Remote)',
                  subtitle: 'Controls the PC host over Wi-Fi',
                  icon: Icons.smartphone_outlined,
                  isSelected: !isHost,
                  onTap: () => notifier.switchRole(AppRole.client),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (isHost)
          _buildHostControls(connection, notifier)
        else
          _buildClientControls(connection, notifier, settings),
      ],
    );
  }

  Widget _buildRoleSelectorTab({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceHighlight : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(
                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHostControls(AppConnectionState connection, ConnectionNotifier notifier) {
    final isOnline = connection.status == ConnectionStatus.hosting;

    return MinimalistCard(
      title: 'LOCAL HOST SERVER STATUS',
      trailing: ElevatedButton.icon(
        icon: Icon(
          isOnline ? Icons.stop : Icons.play_arrow,
          size: 16,
          color: isOnline ? AppColors.error : Colors.black,
        ),
        label: Text(
          isOnline ? 'Stop Server' : 'Start Server',
          style: TextStyle(
            color: isOnline ? AppColors.error : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOnline ? AppColors.errorMuted : AppColors.accent,
          side: isOnline ? const BorderSide(color: AppColors.error) : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          elevation: 0,
        ),
        onPressed: () {
          if (isOnline) {
            notifier.stopHost();
          } else {
            notifier.startHost();
          }
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mobile devices on the same Wi-Fi network can connect to this PC using the local IP endpoint below or via UDP auto-discovery.',
            style: AppTypography.bodyMuted,
          ),
          const SizedBox(height: 14),

          // Local IP Readout Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering, size: 18, color: AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Host Endpoint', style: AppTypography.caption),
                      Text(
                        'ws://${connection.activeIp ?? "127.0.0.1"}:${connection.activePort}/ws',
                        style: AppTypography.mono.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy IP address',
                  color: AppColors.textSecondary,
                  onPressed: () {
                    final ip = connection.activeIp ?? '127.0.0.1';
                    Clipboard.setData(ClipboardData(text: ip));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied $ip to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Connected Clients
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CONNECTED CLIENT DEVICES', style: AppTypography.caption),
              Text(
                '${connection.connectedClientIps.length} active',
                style: AppTypography.mono.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (connection.connectedClientIps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                isOnline
                    ? 'Waiting for mobile devices to connect over Wi-Fi...'
                    : 'Server is currently stopped.',
                style: AppTypography.caption,
              ),
            )
          else
            Column(
              children: connection.connectedClientIps.map((client) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android, size: 14, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(client, style: AppTypography.caption),
                      const Spacer(),
                      const StatusPill(status: ConnectionStatus.connected, showPing: false),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildClientControls(
    AppConnectionState connection,
    ConnectionNotifier notifier,
    AppSettings settings,
  ) {
    final isConnected = connection.status == ConnectionStatus.connected;

    return Column(
      children: [
        // Discovered Hosts (Zero-Config UDP)
        MinimalistCard(
          title: 'AUTO-DISCOVERED HOSTS (UDP RADAR)',
          trailing: IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            tooltip: 'Rescan LAN',
            color: AppColors.accent,
            onPressed: () => notifier.startDiscovery(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Searching local Wi-Fi for PC hosts broadcasting StripX beacon...',
                style: AppTypography.bodyMuted,
              ),
              const SizedBox(height: 12),
              if (connection.discoveredHosts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Scanning Wi-Fi broadcast...', style: AppTypography.caption),
                    ],
                  ),
                )
              else
                Column(
                  children: connection.discoveredHosts.map((host) {
                    final isThisConnected = isConnected && connection.activeIp == host.ip;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isThisConnected ? AppColors.surfaceHighlight : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isThisConnected ? AppColors.accent : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.laptop_chromebook,
                            color: isThisConnected ? AppColors.accent : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(host.name, style: AppTypography.titleMedium.copyWith(fontSize: 13)),
                                Text('${host.ip}:${host.port}', style: AppTypography.mono.copyWith(fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: isThisConnected
                                ? () => notifier.disconnectClient()
                                : () => notifier.connectToHost(host.ip, port: host.port),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isThisConnected ? AppColors.errorMuted : AppColors.accent,
                              foregroundColor: isThisConnected ? AppColors.error : Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 0,
                              minimumSize: Size.zero,
                            ),
                            child: Text(
                              isThisConnected ? 'Disconnect' : 'Connect',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Manual Connection Card
        MinimalistCard(
          title: 'MANUAL IP CONNECTION',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'PC Host IP',
                        hintText: 'e.g. 192.168.1.15',
                        prefixIcon: Icon(Icons.lan_outlined, size: 16),
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '8765',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Recent IP addresses
              if (settings.recentIps.isNotEmpty) ...[
                Text('RECENT HOSTS', style: AppTypography.caption),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: settings.recentIps.map((ip) {
                    return ActionChip(
                      label: Text(ip, style: AppTypography.mono.copyWith(fontSize: 11)),
                      backgroundColor: AppColors.surfaceElevated,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      onPressed: () {
                        _ipController.text = ip;
                        notifier.connectToHost(ip);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // Connect / Disconnect Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(
                    isConnected ? Icons.link_off : Icons.link,
                    size: 16,
                  ),
                  label: Text(
                    isConnected ? 'Disconnect From Host' : 'Connect to PC Host',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? AppColors.errorMuted : AppColors.accent,
                    foregroundColor: isConnected ? AppColors.error : Colors.black,
                    side: isConnected ? const BorderSide(color: AppColors.error) : null,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: isConnected
                      ? () => notifier.disconnectClient()
                      : _connectManual,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
