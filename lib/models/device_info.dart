/// Discovered host or connected client metadata.
class DiscoveredDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String platform;
  final DateTime lastSeen;
  final int? pingMs;

  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.platform,
    required this.lastSeen,
    this.pingMs,
  });

  String get endpoint => '$ip:$port';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'platform': platform,
      'lastSeen': lastSeen.toIso8601String(),
      'pingMs': pingMs,
    };
  }

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Host',
      ip: json['ip'] as String? ?? '127.0.0.1',
      port: (json['port'] as num?)?.toInt() ?? 8765,
      platform: json['platform'] as String? ?? 'Unknown',
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'] as String) ?? DateTime.now()
          : DateTime.now(),
      pingMs: (json['pingMs'] as num?)?.toInt(),
    );
  }
}
