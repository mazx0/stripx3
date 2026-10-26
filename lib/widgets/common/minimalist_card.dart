import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// Minimalist container card with slate background, subtle border, and optional header.
/// Uses Material to ensure ink splashes and ListTile backgrounds render without assertion errors.
class MinimalistCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool isElevated;

  const MinimalistCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.isElevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isElevated ? AppColors.surfaceElevated : AppColors.surface;
    final borderColor = isElevated ? AppColors.borderHover : AppColors.border;

    return Material(
      color: bgColor,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || trailing != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: AppTypography.titleMedium,
                    ),
                  ?trailing,
                ],
              ),
            ),
            const Divider(),
          ],
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}
