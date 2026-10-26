import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/platform_helper.dart';

/// Minimalist compact custom window title bar for Windows Desktop.
class DesktopTitleBar extends StatelessWidget {
  final bool showTrayButton;
  final VoidCallback? onMinimizeToTray;
  final VoidCallback? onClose;

  const DesktopTitleBar({
    super.key,
    this.showTrayButton = false,
    this.onMinimizeToTray,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!PlatformHelper.isDesktop) return const SizedBox.shrink();

    return DragToMoveArea(
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: Row(
          children: [
            // App Branding Icon & Name
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'STRIPX v3',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            // Minimize to System Tray Button (shown when minimize to tray on close is off)
            if (showTrayButton && onMinimizeToTray != null)
              _buildWindowButton(
                icon: Icons.vertical_align_bottom_outlined,
                tooltip: 'Minimize to Tray',
                onTap: onMinimizeToTray,
              ),
            // Standard Window Controls
            _buildWindowButton(
              icon: Icons.remove,
              tooltip: 'Minimize',
              onTap: () => windowManager.minimize(),
            ),
            _buildWindowButton(
              icon: Icons.crop_square_outlined,
              tooltip: 'Maximize / Restore',
              onTap: () async {
                final isMax = await windowManager.isMaximized();
                if (isMax) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _buildWindowButton(
              icon: Icons.close,
              tooltip: 'Close',
              isClose: true,
              onTap: onClose ?? () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool isClose = false,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: isClose ? AppColors.error.withAlpha(50) : AppColors.surfaceHighlight,
        child: SizedBox(
          width: 34,
          height: 28,
          child: Icon(
            icon,
            size: 14,
            color: isClose ? AppColors.error : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
