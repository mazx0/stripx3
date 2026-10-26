import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/strip_state.dart';
import '../../services/animation/animation_engine.dart';

/// Master power status banner with a dedicated tactile button.
/// Strictly uses only the power button for turning on and off (no redundant toggles).
class PowerBanner extends StatelessWidget {
  final StripState state;
  final VoidCallback onTogglePower;

  const PowerBanner({
    super.key,
    required this.state,
    required this.onTogglePower,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = state.power;
    final isAnimated = isOn && state.mode != StripMode.staticMode;

    return ValueListenableBuilder<Color>(
      valueListenable: AnimationEngine().liveColor,
      builder: (context, animColor, _) {
        final activeColor = !isOn
            ? AppColors.textMuted
            : (isAnimated ? animColor : state.primaryColor);

        return Material(
          color: AppColors.surface,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isOn ? activeColor.withAlpha(120) : AppColors.border,
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: onTogglePower,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  // Dedicated Tactile Power Button
                  AnimatedContainer(
                    duration: Duration(milliseconds: isAnimated ? 60 : 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOn ? activeColor.withAlpha(40) : AppColors.surfaceElevated,
                      border: Border.all(
                        color: isOn ? activeColor : AppColors.border,
                        width: 2,
                      ),
                      boxShadow: isOn
                          ? [
                              BoxShadow(
                                color: activeColor.withAlpha(80),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.power_settings_new,
                      color: isOn ? activeColor : AppColors.textMuted,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // State Readout
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isOn ? 'LED STRIP ACTIVE' : 'SYSTEM STANDBY',
                              style: AppTypography.titleMedium.copyWith(
                                color: isOn ? AppColors.textPrimary : AppColors.textTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOn ? activeColor : AppColors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isOn
                              ? '${state.mode.label} • ${(state.brightness * 100).round()}% Brightness • ${state.speed}% Speed'
                              : 'Strip is turned off. Click the button to turn on.',
                          style: AppTypography.bodyMuted.copyWith(
                            color: isOn ? AppColors.textSecondary : AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Explicit Power State Button Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isOn ? activeColor.withAlpha(30) : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOn ? activeColor : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      isOn ? 'ON' : 'OFF',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isOn ? activeColor : AppColors.textTertiary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
