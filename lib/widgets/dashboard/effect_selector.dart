import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/strip_state.dart';

/// Minimalist effect/mode selector cards.
class EffectSelector extends StatelessWidget {
  final StripMode currentMode;
  final ValueChanged<StripMode> onModeSelected;
  final bool enabled;

  const EffectSelector({
    super.key,
    required this.currentMode,
    required this.onModeSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: StripMode.values.map((mode) {
        final isSelected = mode == currentMode;
        final activeColor = enabled ? AppColors.accent : AppColors.textMuted;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => onModeSelected(mode) : null,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withAlpha(25)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? activeColor : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mode.icon,
                    size: 15,
                    color: isSelected ? activeColor : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    mode.label,
                    style: AppTypography.caption.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
