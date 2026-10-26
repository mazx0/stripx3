import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../providers/update_provider.dart';
import '../../services/updater/update_service.dart';

/// Discord-style quiet update notification banner displayed at top of app.
class UpdateBanner extends StatelessWidget {
  final UpdateState updateState;
  final VoidCallback onOpenModal;
  final VoidCallback onQuickAction;
  final VoidCallback onDismiss;

  const UpdateBanner({
    super.key,
    required this.updateState,
    required this.onOpenModal,
    required this.onQuickAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (!updateState.isBannerVisible || !updateState.hasUpdate) {
      return const SizedBox.shrink();
    }

    final isReady = updateState.status == UpdateStatus.readyToInstall;
    final isDownloading = updateState.status == UpdateStatus.downloading;
    final version = updateState.manifest?.version ?? 'New';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: const Border(
          bottom: BorderSide(color: AppColors.borderAccent, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.accentMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isReady ? Icons.check_circle_outline : Icons.system_update_alt,
              color: AppColors.accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isReady
                  ? 'Update v$version is ready. Restart to apply changes.'
                  : (isDownloading
                      ? 'Downloading v$version (${(updateState.progress.progress * 100).round()}%)...'
                      : 'StripX v$version is available.'),
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onOpenModal,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Changelog',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: onQuickAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              isReady
                  ? 'Restart Now'
                  : (isDownloading ? 'Downloading' : 'Update Now'),
              style: AppTypography.caption.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            color: AppColors.textTertiary,
            splashRadius: 14,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
