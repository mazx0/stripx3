import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_typography.dart';
import '../../providers/update_provider.dart';
import '../../services/updater/update_service.dart';

/// Sleek modal dialog displaying update details, changelog, and download progress.
class UpdateModal extends StatelessWidget {
  final UpdateState updateState;
  final VoidCallback onDownload;
  final VoidCallback onApply;
  final VoidCallback onClose;

  const UpdateModal({
    super.key,
    required this.updateState,
    required this.onDownload,
    required this.onApply,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final manifest = updateState.manifest;
    final isDownloading = updateState.status == UpdateStatus.downloading;
    final isReady = updateState.status == UpdateStatus.readyToInstall;
    final version = manifest?.version ?? 'New';
    final notes = manifest?.releaseNotes ?? 'Maintenance and performance improvements.';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderHover, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.accentMuted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.rocket_launch_outlined,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Update Available', style: AppTypography.titleMedium),
                        Text('StripX v$version', style: AppTypography.caption),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  color: AppColors.textTertiary,
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 14),

            // Version tags
            Row(
              children: [
                _buildVersionPill('Current: v${AppConstants.appVersion}', AppColors.textTertiary),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 12, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                _buildVersionPill('Latest: v$version', AppColors.accent),
              ],
            ),
            const SizedBox(height: 14),

            // Changelog Box
            Text(
              'RELEASE NOTES',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(
                  notes,
                  style: AppTypography.bodyMuted.copyWith(
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Download Progress Bar (When downloading)
            if (isDownloading) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Downloading update...',
                    style: AppTypography.caption,
                  ),
                  Text(
                    '${(updateState.progress.progress * 100).round()}% • ${updateState.progress.speedKbps.toStringAsFixed(1)} KB/s',
                    style: AppTypography.mono.copyWith(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: updateState.progress.progress,
                  backgroundColor: AppColors.surfaceHighlight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Later'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: isDownloading
                      ? null
                      : (isReady ? onApply : onDownload),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isReady
                        ? 'Restart & Apply'
                        : (isDownloading ? 'Downloading...' : 'Update Now'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
