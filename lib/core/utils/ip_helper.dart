import 'dart:io';

/// Helper to discover local LAN IPv4 network interfaces on the host PC / mobile client.
class IpHelper {
  IpHelper._();

  /// Retrieve all non-loopback IPv4 addresses on active network interfaces.
  static Future<List<String>> getLocalIpv4Addresses() async {
    final List<String> addresses = [];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            // Prioritize standard local subnets (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
            if (addr.address.startsWith('192.168.') ||
                addr.address.startsWith('10.') ||
                addr.address.startsWith('172.')) {
              addresses.insert(0, addr.address);
            } else {
              addresses.add(addr.address);
            }
          }
        }
      }
    } catch (_) {
      // In case of platform permission edge cases, fall back to empty list
    }
    return addresses.toSet().toList(); // Deduplicate
  }

  /// Get the primary local IPv4 address (e.g. 192.168.1.15).
  static Future<String> getPrimaryLocalIpv4() async {
    final list = await getLocalIpv4Addresses();
    if (list.isNotEmpty) {
      return list.first;
    }
    return '127.0.0.1';
  }

  /// Validate if a string is a valid IPv4 address.
  static bool isValidIpv4(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final val = int.tryParse(part);
      if (val == null || val < 0 || val > 255) return false;
    }
    return true;
  }
}
