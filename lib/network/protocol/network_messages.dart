import 'dart:convert';
import '../../models/strip_state.dart';

/// Protocol message types for StripX WebSocket communication.
class MsgType {
  MsgType._();

  static const String stateUpdate = 'STATE_UPDATE';
  static const String paramChange = 'PARAM_CHANGE';
  static const String ping = 'PING';
  static const String pong = 'PONG';
  static const String clientHello = 'CLIENT_HELLO';
  static const String hostWelcome = 'HOST_WELCOME';
}

/// Network message helper for fast serializing and deserializing.
class NetworkMessage {
  final String type;
  final dynamic payload;
  final int timestamp;

  NetworkMessage({
    required this.type,
    this.payload,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().microsecondsSinceEpoch;

  String serialize() {
    return jsonEncode({
      'type': type,
      'payload': payload,
      'ts': timestamp,
    });
  }

  static NetworkMessage? parse(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return NetworkMessage(
        type: map['type'] as String? ?? '',
        payload: map['payload'],
        timestamp: (map['ts'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Create state broadcast message
  static String stateUpdate(StripState state) {
    return NetworkMessage(
      type: MsgType.stateUpdate,
      payload: state.toJson(),
    ).serialize();
  }

  /// Create incremental parameter change message (e.g. brightness slider)
  static String paramChange(String key, dynamic value) {
    return NetworkMessage(
      type: MsgType.paramChange,
      payload: {'key': key, 'value': value},
    ).serialize();
  }

  /// Ping message
  static String ping() {
    return NetworkMessage(type: MsgType.ping).serialize();
  }

  /// Pong message with echoed origin timestamp
  static String pong(int originTimestamp) {
    return NetworkMessage(
      type: MsgType.pong,
      payload: {'echo': originTimestamp},
    ).serialize();
  }

  /// Client hello message
  static String clientHello(String clientName, String platform) {
    return NetworkMessage(
      type: MsgType.clientHello,
      payload: {'name': clientName, 'platform': platform},
    ).serialize();
  }

  /// Host welcome message
  static String hostWelcome(StripState currentState) {
    return NetworkMessage(
      type: MsgType.hostWelcome,
      payload: currentState.toJson(),
    ).serialize();
  }
}
