import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/platform_helper.dart';
import '../../providers/ble_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/update_provider.dart';
import '../../services/updater/update_service.dart';
import '../../widgets/common/status_pill.dart';
import '../../widgets/updater/update_banner.dart';
import '../../widgets/updater/update_modal.dart';
import 'connection_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

/// Responsive main application shell for Desktop and Android.
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    ConnectionScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformHelper.isDesktop;
    final updateState = ref.watch(updateProvider);
    final updateNotifier = ref.read(updateProvider.notifier);
    final connection = ref.watch(connectionProvider);
    final bleState = ref.watch(bleProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // Discord-Style Auto-Update Banner
              UpdateBanner(
                updateState: updateState,
                onOpenModal: () => updateNotifier.showModal(),
                onQuickAction: () {
                  if (updateState.status == UpdateStatus.readyToInstall) {
                    updateNotifier.applyUpdate();
                  } else {
                    updateNotifier.downloadUpdate();
                  }
                },
                onDismiss: () => updateNotifier.dismissBanner(),
              ),

              // Main Responsive Body
              Expanded(
                child: isDesktop
                    ? Row(
                        children: [
                          _buildDesktopSidebar(bleState.isConnected, connection.isConnected),
                          const VerticalDivider(width: 1, color: AppColors.border),
                          Expanded(
                            child: IndexedStack(
                              index: _selectedIndex,
                              children: _screens,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildMobileAppBar(connection.status, connection.pingMs, bleState.isConnected),
                          Expanded(
                            child: IndexedStack(
                              index: _selectedIndex,
                              children: _screens,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop ? null : _buildMobileBottomNav(bleState.isConnected),
        ),

        // Update Modal Dialog Overlay
        if (updateState.isModalVisible)
          UpdateModal(
            updateState: updateState,
            onDownload: () => updateNotifier.downloadUpdate(),
            onApply: () => updateNotifier.applyUpdate(),
            onClose: () => updateNotifier.hideModal(),
          ),
      ],
    );
  }

  Widget _buildDesktopSidebar(bool isBleConnected, bool isWifiConnected) {
    return Container(
      width: 200,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.accentMuted,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accent),
                  ),
                  child: const Icon(
                    Icons.tune,
                    color: AppColors.accent,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STRIPX v3', style: AppTypography.titleMedium.copyWith(fontSize: 14)),
                    Text(
                      isBleConnected ? 'BLE Connected' : (isWifiConnected ? 'Sync Active' : 'Standby'),
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: (isBleConnected || isWifiConnected) ? AppColors.accent : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Primary Navigation Items
          _buildSidebarNavItem(0, 'Dashboard', Icons.dashboard_outlined, Icons.dashboard),
          _buildSidebarNavItem(
            1,
            'Connection',
            isBleConnected ? Icons.bluetooth_connected : Icons.cable_outlined,
            isBleConnected ? Icons.bluetooth_connected : Icons.cable,
            badge: isBleConnected ? 'BLE' : (isWifiConnected ? 'Wi-Fi' : null),
          ),
          _buildSidebarNavItem(2, 'Settings', Icons.settings_outlined, Icons.settings),

          const Spacer(),

          // Desktop Tray Quick Tip
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'StripX keeps running in tray when closed',
                    style: AppTypography.caption.copyWith(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem(
    int index,
    String label,
    IconData icon,
    IconData activeIcon, {
    String? badge,
  }) {
    final isSelected = _selectedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.surfaceHighlight : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.borderHover : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 18,
                  color: isSelected ? AppColors.accent : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accentMuted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: AppTypography.caption.copyWith(
                        fontSize: 9,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileAppBar(dynamic status, int pingMs, bool isBleConnected) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.accentMuted,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.accent),
                    ),
                    child: const Icon(Icons.tune, color: AppColors.accent, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'StripX v3',
                    style: AppTypography.titleMedium,
                  ),
                ],
              ),
              Row(
                children: [
                  if (isBleConnected) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentMuted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bluetooth_connected, size: 12, color: AppColors.accent),
                          SizedBox(width: 3),
                          Text('BLE', style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  StatusPill(status: status, pingMs: pingMs),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomNav(bool isBleConnected) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textTertiary,
        selectedLabelStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTypography.caption,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(isBleConnected ? Icons.bluetooth_connected : Icons.cable_outlined),
            activeIcon: Icon(isBleConnected ? Icons.bluetooth_connected : Icons.cable),
            label: 'Connection',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
