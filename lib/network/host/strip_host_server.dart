import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/strip_state.dart';
import '../protocol/network_messages.dart';

typedef OnStateChangedCallback = void Function(StripState newState);
typedef OnClientsChangedCallback = void Function(List<String> clientIps);

/// High-performance local HTTP & WebSocket Host Server running on Windows PC.
/// Built strictly with Dart's asynchronous I/O to guarantee zero UI thread lag.
class StripHostServer {
  HttpServer? _httpServer;
  final Set<WebSocket> _clients = {};
  StripState _currentState = const StripState();

  OnStateChangedCallback? onStateChanged;
  OnClientsChangedCallback? onClientsChanged;

  bool get isRunning => _httpServer != null;
  int get clientCount => _clients.length;
  StripState get currentState => _currentState;

  /// Start the Host Server on [port] (default 8765)
  Future<bool> start({
    int port = AppConstants.defaultWsPort,
    StripState? initialState,
  }) async {
    await stop();
    if (initialState != null) {
      _currentState = initialState;
    }

    try {
      _httpServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );

      _httpServer!.listen(_handleHttpRequest);
      return true;
    } catch (_) {
      await stop();
      return false;
    }
  }

  void _handleHttpRequest(HttpRequest request) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (path == '/ws') {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        try {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleNewClient(socket, request.connectionInfo?.remoteAddress.address ?? 'Client');
        } catch (_) {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        }
      } else {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Expected WebSocket Upgrade');
        await request.response.close();
      }
      return;
    }

    if (path == '/health' || path == '/') {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'service': 'stripx3v',
        'status': 'online',
        'version': AppConstants.appVersion,
        'clients': _clients.length,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      await request.response.close();
      return;
    }

    if (path == '/state') {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_currentState.toJson()));
      await request.response.close();
      return;
    }

    // Default 404
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  void _handleNewClient(WebSocket socket, String clientIp) {
    _clients.add(socket);
    _notifyClientsChanged();

    // Send initial full state immediately upon connect
    try {
      socket.add(NetworkMessage.hostWelcome(_currentState));
    } catch (_) {}

    socket.listen(
      (data) {
        if (data is String) {
          _processClientMessage(data, socket);
        }
      },
      onDone: () {
        _clients.remove(socket);
        _notifyClientsChanged();
      },
      onError: (_) {
        _clients.remove(socket);
        _notifyClientsChanged();
      },
      cancelOnError: true,
    );
  }

  void _processClientMessage(String raw, WebSocket sender) {
    final msg = NetworkMessage.parse(raw);
    if (msg == null) return;

    if (msg.type == MsgType.ping) {
      try {
        sender.add(NetworkMessage.pong(msg.timestamp));
      } catch (_) {}
      return;
    }

    if (msg.type == MsgType.stateUpdate) {
      if (msg.payload is Map<String, dynamic>) {
        try {
          final newState = StripState.fromJson(msg.payload as Map<String, dynamic>);
          _currentState = newState;
          onStateChanged?.call(_currentState);
          // Broadcast to other clients except the sender
          _broadcastToClients(raw, exclude: sender);
        } catch (_) {}
      }
      return;
    }

    if (msg.type == MsgType.paramChange) {
      if (msg.payload is Map<String, dynamic>) {
        final key = msg.payload['key'] as String?;
        final val = msg.payload['value'];
        if (key != null) {
          _applyParamChange(key, val);
          onStateChanged?.call(_currentState);
          // Broadcast to other clients
          _broadcastToClients(raw, exclude: sender);
        }
      }
      return;
    }
  }

  void _applyParamChange(String key, dynamic value) {
    switch (key) {
      case 'power':
        if (value is bool) _currentState = _currentState.copyWith(power: value);
        break;
      case 'brightness':
        if (value is num) _currentState = _currentState.copyWith(brightness: value.toDouble());
        break;
      case 'speed':
        if (value is num) _currentState = _currentState.copyWith(speed: value.toInt());
        break;
      case 'mode':
        if (value is String) _currentState = _currentState.copyWith(mode: StripMode.fromString(value));
        break;
      case 'primaryColor':
        if (value is num) _currentState = _currentState.copyWith(primaryColor: Color(value.toInt()));
        break;
      case 'secondaryColor':
        if (value is num) _currentState = _currentState.copyWith(secondaryColor: Color(value.toInt()));
        break;
      case 'audioSensitivity':
        if (value is num) _currentState = _currentState.copyWith(audioSensitivity: value.toDouble());
        break;
    }
  }

  /// Broadcast updated state initiated by the host PC itself
  void updateStateAndBroadcast(StripState newState) {
    _currentState = newState;
    final msg = NetworkMessage.stateUpdate(_currentState);
    _broadcastToClients(msg);
  }

  /// Broadcast a single fast parameter change initiated by the host PC
  void broadcastParamChange(String key, dynamic value) {
    _applyParamChange(key, value);
    final msg = NetworkMessage.paramChange(key, value);
    _broadcastToClients(msg);
  }

  void _broadcastToClients(String message, {WebSocket? exclude}) {
    final deadSockets = <WebSocket>[];
    for (final client in _clients) {
      if (client == exclude) continue;
      try {
        client.add(message);
      } catch (_) {
        deadSockets.add(client);
      }
    }
    if (deadSockets.isNotEmpty) {
      _clients.removeAll(deadSockets);
      _notifyClientsChanged();
    }
  }

  void _notifyClientsChanged() {
    final ips = _clients.map((c) => 'Client #${c.hashCode.toString().substring(0, 4)}').toList();
    onClientsChanged?.call(ips);
  }

  Future<void> stop() async {
    for (final client in _clients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _clients.clear();
    await _httpServer?.close(force: true);
    _httpServer = null;
    _notifyClientsChanged();
  }
}
