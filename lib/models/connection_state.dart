import 'device_info.dart';

/// Connection role: Primary Host (usually PC) or Remote Client (usually Mobile APK).
enum AppRole {
  host,
  client,
}

/// Dynamic connection lifecycle status.
enum ConnectionStatus {
  idle,
  discovering,
  connecting,
  connected,
  disconnected,
  hosting,
  error,
}

/// Model encapsulating real-time local network status, ping, and peer information.
class AppConnectionState {
  final AppRole role;
  final ConnectionStatus status;
  final String? activeIp;
  final int activePort;
  final int pingMs;
  final List<DiscoveredDevice> discoveredHosts;
  final List<String> connectedClientIps;
  final int packetsSent;
  final int packetsReceived;
  final String? errorMessage;

  const AppConnectionState({
    required this.role,
    this.status = ConnectionStatus.idle,
    this.activeIp,
    this.activePort = 8765,
    this.pingMs = 0,
    this.discoveredHosts = const [],
    this.connectedClientIps = const [],
    this.packetsSent = 0,
    this.packetsReceived = 0,
    this.errorMessage,
  });

  bool get isConnected =>
      status == ConnectionStatus.connected || status == ConnectionStatus.hosting;

  AppConnectionState copyWith({
    AppRole? role,
    ConnectionStatus? status,
    String? activeIp,
    int? activePort,
    int? pingMs,
    List<DiscoveredDevice>? discoveredHosts,
    List<String>? connectedClientIps,
    int? packetsSent,
    int? packetsReceived,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AppConnectionState(
      role: role ?? this.role,
      status: status ?? this.status,
      activeIp: activeIp ?? this.activeIp,
      activePort: activePort ?? this.activePort,
      pingMs: pingMs ?? this.pingMs,
      discoveredHosts: discoveredHosts ?? this.discoveredHosts,
      connectedClientIps: connectedClientIps ?? this.connectedClientIps,
      packetsSent: packetsSent ?? this.packetsSent,
      packetsReceived: packetsReceived ?? this.packetsReceived,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
