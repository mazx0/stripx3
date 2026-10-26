import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/connection_state.dart';

/// Real-time connection and telemetry diagnostic metrics.
class LiveMetricsCard extends StatelessWidget {
  final AppConnectionState connection;

  const LiveMetricsCard({
    super.key,
    required this.connection,
  });

  @override
  Widget build(BuildContext context) {
    final isHost = connection.role == AppRole.host;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE TELEMETRY & SYNC',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '60 FPS UI TARGET',
                style: AppTypography.caption.copyWith(
                  fontFamily: 'monospace',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricTile(
                label: 'Ping Latency',
                value: isHost ? '0ms (Host)' : '${connection.pingMs}ms',
                color: isHost || connection.pingMs < 15
                    ? AppColors.success
                    : (connection.pingMs < 40 ? AppColors.accent : AppColors.warning),
                icon: Icons.speed_outlined,
              ),
              const SizedBox(width: 8),
              _buildMetricTile(
                label: isHost ? 'Connected Clients' : 'Target Host',
                value: isHost
                    ? '${connection.connectedClientIps.length} active'
                    : (connection.activeIp ?? 'None'),
                color: AppColors.textPrimary,
                icon: isHost ? Icons.devices_outlined : Icons.router_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMetricTile(
                label: 'Packets Tx',
                value: '${connection.packetsSent} msgs',
                color: AppColors.textSecondary,
                icon: Icons.arrow_upward_outlined,
              ),
              const SizedBox(width: 8),
              _buildMetricTile(
                label: 'Packets Rx',
                value: '${connection.packetsReceived} msgs',
                color: AppColors.textSecondary,
                icon: Icons.arrow_downward_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: AppTypography.mono.copyWith(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
