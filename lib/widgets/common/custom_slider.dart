import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// Minimalist slider component with live badge readout and fine-tune step buttons.
class CustomSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String valueDisplay;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double step;
  final bool enabled;

  const CustomSlider({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.valueDisplay,
    required this.onChanged,
    this.divisions,
    this.onChangeEnd,
    this.step = 0.05,
    this.enabled = true,
  });

  void _stepDown() {
    if (!enabled) return;
    final next = (value - step).clamp(min, max);
    onChanged(next);
    onChangeEnd?.call(next);
  }

  void _stepUp() {
    if (!enabled) return;
    final next = (value + step).clamp(min, max);
    onChanged(next);
    onChangeEnd?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = enabled ? AppColors.accent : AppColors.textMuted;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: activeColor),
                  const SizedBox(width: 8),
                  Text(label, style: AppTypography.body),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  valueDisplay,
                  style: AppTypography.mono.copyWith(
                    color: activeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
                color: AppColors.textSecondary,
                onPressed: enabled ? _stepDown : null,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: activeColor,
                    thumbColor: activeColor,
                    overlayColor: activeColor.withAlpha(30),
                  ),
                  child: ExcludeSemantics(
                    child: Slider(
                      value: value.clamp(min, max),
                      min: min,
                      max: max,
                      divisions: divisions,
                      onChanged: enabled ? onChanged : null,
                      onChangeEnd: enabled ? onChangeEnd : null,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
                color: AppColors.textSecondary,
                onPressed: enabled ? _stepUp : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
