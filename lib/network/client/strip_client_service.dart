import 'dart:async';
import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../../models/strip_state.dart';
import '../protocol/network_messages.dart';

typedef OnClientStateCallback = void Function(StripState state);
typedef OnClientParamCallback = void Function(String key, dynamic value);
typedef OnClientStatusCallback = void Function(bool connected, String? error);
typedef OnPingCallback = void Function(int pingMs);

/// Remote control client service for Android APK (or desktop in client mode).
/// Connects to the PC host WebSocket with auto-reconnection and low-latency streaming.
class StripClientService {
  WebSocket? _socket;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  String? _targetIp;
  int _targetPort = AppConstants.defaultWsPort;
  bool _intentionalDisconnect = false;
  int _reconnectAttempts = 0;

  OnClientStateCallback? onStateReceived;
  OnClientParamCallback? onParamReceived;
  OnClientStatusCallback? onStatusChanged;
  OnPingCallback? onPingUpdated;

  bool get isConnected => _socket != null;
  String? get currentTargetIp => _targetIp;
  int get currentTargetPort => _targetPort;

  /// Connect to the host PC at [ip]:[port]
  Future<bool> connect(String ip, {int port = AppConstants.defaultWsPort}) async {
    _intentionalDisconnect = false;
    _targetIp = ip.trim();
    _targetPort = port;

    await _cleanupSocket();

    try {
      final uri = Uri.parse('ws://$_targetIp:$_targetPort/ws');
      _socket = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 4));

      _reconnectAttempts = 0;
      onStatusChanged?.call(true, null);

      _socket!.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (err) => _handleDisconnect(error: err.toString()),
        cancelOnError: true,
      );

      _startPingLoop();
      return true;
    } catch (e) {
      onStatusChanged?.call(false, 'Failed to connect to $_targetIp:$_targetPort');
      _scheduleReconnect();
      return false;
    }
  }

  void _handleMessage(dynamic data) {
    if (data is! String) return;

    final msg = NetworkMessage.parse(data);
    if (msg == null) return;

    if (msg.type == MsgType.pong) {
      if (msg.payload is Map<String, dynamic>) {
        final echo = (msg.payload['echo'] as num?)?.toInt();
        if (echo != null) {
          final now = DateTime.now().microsecondsSinceEpoch;
          final diffMs = ((now - echo) / 1000).round();
          onPingUpdated?.call(diffMs.clamp(0, 999));
        }
      }
      return;
    }

    if (msg.type == MsgType.hostWelcome || msg.type == MsgType.stateUpdate) {
      if (msg.payload is Map<String, dynamic>) {
        try {
          final state = StripState.fromJson(msg.payload as Map<String, dynamic>);
          onStateReceived?.call(state);
        } catch (_) {}
      }
      return;
    }

    if (msg.type == MsgType.paramChange) {
      if (msg.payload is Map<String, dynamic>) {
        final key = msg.payload['key'] as String?;
        final val = msg.payload['value'];
        if (key != null) {
          onParamReceived?.call(key, val);
        }
      }
      return;
    }
  }

  void _startPingLoop() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.pingIntervalMs),
      (_) {
        if (_socket != null) {
          try {
            _socket!.add(NetworkMessage.ping());
          } catch (_) {}
        }
      },
    );
    // Send immediate ping
    try {
      _socket?.add(NetworkMessage.ping());
    } catch (_) {}
  }

  /// Send updated full state to host
  void sendState(StripState state) {
    if (_socket == null) return;
    try {
      _socket!.add(NetworkMessage.stateUpdate(state));
    } catch (_) {}
  }

  /// Send lightweight incremental parameter change (e.g. brightness slider)
  void sendParam(String key, dynamic value) {
    if (_socket == null) return;
    try {
      _socket!.add(NetworkMessage.paramChange(key, value));
    } catch (_) {}
  }

  void _handleDisconnect({String? error}) {
    _pingTimer?.cancel();
    _socket = null;
    onStatusChanged?.call(false, error);

    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect || _targetIp == null) return;

    _reconnectTimer?.cancel();
    // Exponential backoff capped at 6 seconds
    final delaySec = (_reconnectAttempts < 3) ? 2 : 5;
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (!_intentionalDisconnect && _targetIp != null) {
        connect(_targetIp!, port: _targetPort);
      }
    });
  }

  Future<void> _cleanupSocket() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    if (_socket != null) {
      try {
        await _socket!.close();
      } catch (_) {}
      _socket = null;
    }
  }

  /// Clean disconnection
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectAttempts = 0;
    await _cleanupSocket();
    onStatusChanged?.call(false, null);
  }

  void dispose() {
    disconnect();
  }
}
