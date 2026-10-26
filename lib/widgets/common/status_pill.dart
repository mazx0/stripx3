import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/connection_state.dart';

/// Minimalist pill badge showing connection status and real-time Ping latency.
class StatusPill extends StatelessWidget {
  final ConnectionStatus status;
  final int pingMs;
  final bool showPing;

  const StatusPill({
    super.key,
    required this.status,
    this.pingMs = 0,
    this.showPing = true,
  });

  Color _getStatusColor() {
    switch (status) {
      case ConnectionStatus.connected:
      case ConnectionStatus.hosting:
        return AppColors.success;
      case ConnectionStatus.connecting:
      case ConnectionStatus.discovering:
        return AppColors.warning;
      case ConnectionStatus.error:
        return AppColors.error;
      case ConnectionStatus.idle:
      case ConnectionStatus.disconnected:
        return AppColors.textTertiary;
    }
  }

  String _getStatusText() {
    switch (status) {
      case ConnectionStatus.hosting:
        return 'HOST ONLINE';
      case ConnectionStatus.connected:
        return 'CONNECTED';
      case ConnectionStatus.connecting:
        return 'CONNECTING';
      case ConnectionStatus.discovering:
        return 'SCANNING';
      case ConnectionStatus.error:
        return 'ERROR';
      case ConnectionStatus.idle:
        return 'IDLE';
      case ConnectionStatus.disconnected:
        return 'OFFLINE';
    }
  }

  Color _getPingColor() {
    if (pingMs <= 15) return AppColors.success;
    if (pingMs <= 40) return AppColors.accent;
    if (pingMs <= 80) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withAlpha(80), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withAlpha(150),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _getStatusText(),
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        if (showPing && (status == ConnectionStatus.connected || status == ConnectionStatus.hosting)) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt_outlined,
                  size: 13,
                  color: _getPingColor(),
                ),
                const SizedBox(width: 3),
                Text(
                  status == ConnectionStatus.hosting ? 'Local' : '${pingMs}ms',
                  style: AppTypography.caption.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: _getPingColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
