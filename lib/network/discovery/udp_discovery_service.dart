import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../../models/device_info.dart';

/// Service managing zero-configuration UDP discovery between PC host and Android client.
class UdpDiscoveryService {
  RawDatagramSocket? _socket;
  Timer? _beaconTimer;
  final _discoveredController = StreamController<List<DiscoveredDevice>>.broadcast();
  final Map<String, DiscoveredDevice> _discoveredMap = {};

  Stream<List<DiscoveredDevice>> get discoveredHostsStream =>
      _discoveredController.stream;

  List<DiscoveredDevice> get currentDiscovered => _discoveredMap.values.toList();

  /// Start host beaconing on PC Desktop.
  /// Broadcasts beacon packet every [AppConstants.autoDiscoveryIntervalSec] seconds,
  /// and immediately responds to any client probe.
  Future<void> startHostBeacon({
    required String hostName,
    required int wsPort,
    required String localIp,
  }) async {
    await stop();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.defaultUdpPort,
        reuseAddress: true,
        reusePort: false,
      );
      _socket?.broadcastEnabled = true;

      _socket?.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket?.receive();
            if (datagram == null) return;

            try {
              final text = utf8.decode(datagram.data);
              final msg = jsonDecode(text) as Map<String, dynamic>;
              if (msg['type'] == 'PROBE') {
                // Immediately respond to the client's discovery probe
                _sendBeacon(
                  targetAddress: datagram.address,
                  targetPort: datagram.port,
                  hostName: hostName,
                  wsPort: wsPort,
                  localIp: localIp,
                );
              }
            } catch (_) {}
          }
        },
        onError: (error, stackTrace) {
          // Suppress Windows host unreachable (errno 1232) or disconnected interface socket errors
        },
        cancelOnError: false,
      );

      // Periodically broadcast beacon to whole local network subnet
      _beaconTimer = Timer.periodic(
        const Duration(seconds: AppConstants.autoDiscoveryIntervalSec),
        (_) {
          _sendBeacon(
            targetAddress: InternetAddress('255.255.255.255'),
            targetPort: AppConstants.defaultUdpPort,
            hostName: hostName,
            wsPort: wsPort,
            localIp: localIp,
          );
        },
      );

      // Send initial beacon immediately
      _sendBeacon(
        targetAddress: InternetAddress('255.255.255.255'),
        targetPort: AppConstants.defaultUdpPort,
        hostName: hostName,
        wsPort: wsPort,
        localIp: localIp,
      );
    } catch (_) {
      // In case another local process bound the port or network error
    }
  }

  void _sendBeacon({
    required InternetAddress targetAddress,
    required int targetPort,
    required String hostName,
    required int wsPort,
    required String localIp,
  }) {
    if (_socket == null) return;
    try {
      final payload = jsonEncode({
        'type': 'BEACON',
        'service': 'stripx3v',
        'id': 'pc-host-$wsPort',
        'name': hostName,
        'ip': localIp,
        'port': wsPort,
        'platform': Platform.operatingSystem,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      final bytes = utf8.encode(payload);
      _socket?.send(bytes, targetAddress, targetPort);
    } catch (_) {}
  }

  /// Start client discovery listener (e.g. on Android Mobile APK).
  /// Sends a discovery probe and listens for host beacons.
  Future<void> startClientDiscovery() async {
    await stop();
    _discoveredMap.clear();

    try {
      // Bind to an ephemeral port for client listening
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _socket?.broadcastEnabled = true;

      _socket?.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket?.receive();
            if (datagram == null) return;

            try {
              final text = utf8.decode(datagram.data);
              final msg = jsonDecode(text) as Map<String, dynamic>;

              if (msg['type'] == 'BEACON' && msg['service'] == 'stripx3v') {
                final senderIp = msg['ip'] as String? ?? datagram.address.address;
                final wsPort = (msg['port'] as num?)?.toInt() ?? AppConstants.defaultWsPort;
                final hostId = msg['id'] as String? ?? '$senderIp:$wsPort';
                final hostName = msg['name'] as String? ?? 'StripX PC Host';
                final platform = msg['platform'] as String? ?? 'Desktop';

                final device = DiscoveredDevice(
                  id: hostId,
                  name: hostName,
                  ip: senderIp,
                  port: wsPort,
                  platform: platform,
                  lastSeen: DateTime.now(),
                );

                _discoveredMap[hostId] = device;
                _pruneStaleDevices();
                _discoveredController.add(_discoveredMap.values.toList());
              }
            } catch (_) {}
          }
        },
        onError: (error, stackTrace) {
          // Suppress Windows host unreachable (errno 1232) or network interface socket errors
        },
        cancelOnError: false,
      );

      // Send periodic probe every 2 seconds
      _beaconTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        sendClientProbe();
        _pruneStaleDevices();
      });

      sendClientProbe();
    } catch (_) {}
  }

  /// Explicitly trigger a probe broadcast
  void sendClientProbe() {
    if (_socket == null) return;
    try {
      final probe = jsonEncode({
        'type': 'PROBE',
        'service': 'stripx3v',
        'client': Platform.operatingSystem,
      });
      final bytes = utf8.encode(probe);
      _socket?.send(
        bytes,
        InternetAddress('255.255.255.255'),
        AppConstants.defaultUdpPort,
      );
    } catch (_) {}
  }

  void _pruneStaleDevices() {
    final now = DateTime.now();
    bool changed = false;
    _discoveredMap.removeWhere((id, dev) {
      if (now.difference(dev.lastSeen).inSeconds > 10) {
        changed = true;
        return true;
      }
      return false;
    });
    if (changed) {
      _discoveredController.add(_discoveredMap.values.toList());
    }
  }

  Future<void> stop() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    stop();
    _discoveredController.close();
  }
}
