import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/ip_helper.dart';
import '../../core/utils/platform_helper.dart';
import '../../models/connection_state.dart';
import '../../models/device_info.dart';
import '../../network/client/strip_client_service.dart';
import '../../network/discovery/udp_discovery_service.dart';
import '../../network/host/strip_host_server.dart';
import 'settings_provider.dart';
import 'strip_state_provider.dart';

class ConnectionNotifier extends Notifier<AppConnectionState> {
  final StripHostServer _hostServer = StripHostServer();
  final StripClientService _clientService = StripClientService();
  final UdpDiscoveryService _discoveryService = UdpDiscoveryService();

  StreamSubscription<List<DiscoveredDevice>>? _discoverySub;

  @override
  AppConnectionState build() {
    final defaultRole = PlatformHelper.defaultIsHost ? AppRole.host : AppRole.client;
    return AppConnectionState(role: defaultRole);
  }

  void initialize() async {
    // Connect state updates with stripStateProvider
    final stripNotifier = ref.read(stripStateProvider.notifier);
    final settings = ref.read(settingsProvider);

    stripNotifier.setNetworkBroadcastCallback((key, value) {
      if (state.role == AppRole.host) {
        _hostServer.broadcastParamChange(key, value);
      } else {
        _clientService.sendParam(key, value);
      }
      state = state.copyWith(packetsSent: state.packetsSent + 1);
    });

    // Configure Host server callbacks
    _hostServer.onStateChanged = (newState) {
      ref.read(stripStateProvider.notifier).syncFromNetwork(newState);
      state = state.copyWith(packetsReceived: state.packetsReceived + 1);
    };

    _hostServer.onClientsChanged = (clientIps) {
      state = state.copyWith(connectedClientIps: clientIps);
    };

    // Configure Client callbacks
    _clientService.onStateReceived = (newState) {
      ref.read(stripStateProvider.notifier).syncFromNetwork(newState);
      state = state.copyWith(packetsReceived: state.packetsReceived + 1);
    };

    _clientService.onParamReceived = (key, val) {
      ref.read(stripStateProvider.notifier).syncParamFromNetwork(key, val);
      state = state.copyWith(packetsReceived: state.packetsReceived + 1);
    };

    _clientService.onStatusChanged = (connected, error) {
      state = state.copyWith(
        status: connected ? ConnectionStatus.connected : ConnectionStatus.disconnected,
        errorMessage: error,
      );
    };

    _clientService.onPingUpdated = (ping) {
      state = state.copyWith(pingMs: ping);
    };

    // Listen to UDP discovery results
    _discoverySub = _discoveryService.discoveredHostsStream.listen((hosts) {
      state = state.copyWith(discoveredHosts: hosts);
    });

    // Start in appropriate mode
    if (state.role == AppRole.host) {
      if (settings.autoStartHost) {
        await startHost(port: settings.hostPort);
      }
    } else {
      if (settings.autoDiscover) {
        startDiscovery();
      }
      // If there's a last connected IP, attempt reconnect
      if (settings.lastIp != null && settings.lastIp!.isNotEmpty) {
        connectToHost(settings.lastIp!, port: settings.hostPort);
      }
    }
  }

  // --- Host Mode Controls ---

  Future<bool> startHost({int? port}) async {
    final hostPort = port ?? state.activePort;
    final localIp = await IpHelper.getPrimaryLocalIpv4();

    state = state.copyWith(
      status: ConnectionStatus.connecting,
      activeIp: localIp,
      activePort: hostPort,
      clearError: true,
    );

    final currentStripState = ref.read(stripStateProvider);
    final success = await _hostServer.start(
      port: hostPort,
      initialState: currentStripState,
    );

    if (success) {
      state = state.copyWith(
        status: ConnectionStatus.hosting,
        activeIp: localIp,
        activePort: hostPort,
      );

      // Start broadcasting UDP beacon
      await _discoveryService.startHostBeacon(
        hostName: 'StripX Host (${PlatformHelper.isWindows ? "PC" : "Device"})',
        wsPort: hostPort,
        localIp: localIp,
      );
      return true;
    } else {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Failed to bind host server on port $hostPort',
      );
      return false;
    }
  }

  Future<void> stopHost() async {
    await _discoveryService.stop();
    await _hostServer.stop();
    state = state.copyWith(
      status: ConnectionStatus.idle,
      connectedClientIps: const [],
    );
  }

  // --- Client Mode Controls ---

  Future<void> startDiscovery() async {
    state = state.copyWith(status: ConnectionStatus.discovering);
    await _discoveryService.startClientDiscovery();
  }

  Future<bool> connectToHost(String ip, {int? port}) async {
    final targetPort = port ?? AppConstants.defaultWsPort;

    state = state.copyWith(
      status: ConnectionStatus.connecting,
      activeIp: ip,
      activePort: targetPort,
      clearError: true,
    );

    final success = await _clientService.connect(ip, port: targetPort);
    if (success) {
      ref.read(settingsProvider.notifier).addRecentIp(ip);
      state = state.copyWith(
        status: ConnectionStatus.connected,
        activeIp: ip,
        activePort: targetPort,
      );
      return true;
    } else {
      state = state.copyWith(
        status: ConnectionStatus.disconnected,
        errorMessage: 'Could not connect to $ip:$targetPort',
      );
      return false;
    }
  }

  Future<void> disconnectClient() async {
    await _clientService.disconnect();
    state = state.copyWith(
      status: ConnectionStatus.disconnected,
      pingMs: 0,
    );
  }

  // --- Role Switching ---

  Future<void> switchRole(AppRole newRole) async {
    if (state.role == newRole) return;

    if (state.role == AppRole.host) {
      await stopHost();
    } else {
      await disconnectClient();
      await _discoveryService.stop();
    }

    state = state.copyWith(
      role: newRole,
      status: ConnectionStatus.idle,
      pingMs: 0,
      connectedClientIps: const [],
      clearError: true,
    );

    if (newRole == AppRole.host) {
      await startHost();
    } else {
      await startDiscovery();
    }
  }

  void cleanup() {
    _discoverySub?.cancel();
    _discoveryService.dispose();
    _hostServer.stop();
    _clientService.dispose();
  }
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, AppConnectionState>(() {
  return ConnectionNotifier();
});
