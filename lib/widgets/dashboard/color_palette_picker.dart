import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// Minimalist color palette selector and hue spectrum picker.
class ColorPalettePicker extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final ValueChanged<Color> onPrimaryColorChanged;
  final ValueChanged<Color>? onSecondaryColorChanged;
  final bool enabled;

  const ColorPalettePicker({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onPrimaryColorChanged,
    this.onSecondaryColorChanged,
    this.enabled = true,
  });

  @override
  State<ColorPalettePicker> createState() => _ColorPalettePickerState();
}

class _ColorPalettePickerState extends State<ColorPalettePicker> {
  bool _editingSecondary = false;

  @override
  Widget build(BuildContext context) {
    final activeTargetColor = _editingSecondary ? widget.secondaryColor : widget.primaryColor;
    final hsv = HSVColor.fromColor(activeTargetColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode Switch: Primary vs Secondary Accent Color
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildColorTargetTab(
                  label: 'Primary',
                  color: widget.primaryColor,
                  selected: !_editingSecondary,
                  onTap: () => setState(() => _editingSecondary = false),
                ),
                const SizedBox(width: 8),
                _buildColorTargetTab(
                  label: 'Accent 2',
                  color: widget.secondaryColor,
                  selected: _editingSecondary,
                  onTap: () => setState(() => _editingSecondary = true),
                ),
              ],
            ),
            // Hex display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '#${activeTargetColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                style: AppTypography.mono.copyWith(
                  color: activeTargetColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Curated Palette Chips
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppColors.presetColors.map((color) {
            final isCurrent = color.toARGB32() == activeTargetColor.toARGB32();

            return GestureDetector(
              onTap: widget.enabled
                  ? () {
                      if (_editingSecondary) {
                        widget.onSecondaryColorChanged?.call(color);
                      } else {
                        widget.onPrimaryColorChanged(color);
                      }
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrent ? Colors.white : AppColors.borderHover,
                    width: isCurrent ? 2.5 : 1,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: color.withAlpha(140),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Continuous Hue Spectrum Slider
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Continuous Hue Spectrum', style: AppTypography.caption),
                Text('${hsv.hue.round()}°', style: AppTypography.caption.copyWith(fontFamily: 'monospace')),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                ),
              ),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 20,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
                  overlayColor: Colors.white.withAlpha(40),
                ),
                child: ExcludeSemantics(
                  child: Slider(
                    value: hsv.hue,
                    min: 0,
                    max: 360,
                    onChanged: widget.enabled
                        ? (hue) {
                            final newColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
                            if (_editingSecondary) {
                              widget.onSecondaryColorChanged?.call(newColor);
                            } else {
                              widget.onPrimaryColorChanged(newColor);
                            }
                          }
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorTargetTab({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceHighlight : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
