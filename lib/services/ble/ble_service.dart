import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';
import '../../models/strip_state.dart';
import 'ble_protocol.dart';

class DiscoveredBleDevice {
  final String id;
  final String name;
  final int rssi;
  final bool isKnownLed;
  final DateTime lastSeen;

  const DiscoveredBleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.isKnownLed,
    required this.lastSeen,
  });

  DiscoveredBleDevice copyWith({
    String? name,
    int? rssi,
    bool? isKnownLed,
    DateTime? lastSeen,
  }) {
    return DiscoveredBleDevice(
      id: id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isKnownLed: isKnownLed ?? this.isKnownLed,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

enum BleStatus {
  idle,
  scanning,
  connecting,
  connected,
  disconnecting,
  error,
}

typedef OnBleDeviceListChanged = void Function(List<DiscoveredBleDevice> devices);
typedef OnBleStatusChanged = void Function(BleStatus status, String? message);
typedef OnBleConnectedCallback = void Function(String id, String name, BleProtocolType protocol);

/// Cross-platform Bluetooth Low Energy service for Windows Desktop and Android.
/// Connects to LED strip controllers (ELK-BLEDOM, Triones, Zengge, etc.) and writes commands.
class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BleStatus _status = BleStatus.idle;
  String? _connectedDeviceId;
  String? _connectedDeviceName;
  BleProtocolType _activeProtocol = BleProtocolType.bledom;

  String? _writeServiceUuid;
  String? _writeCharUuid;

  final Map<String, DiscoveredBleDevice> _devices = {};
  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<bool>? _connectionSub;

  OnBleDeviceListChanged? onDevicesChanged;
  OnBleStatusChanged? onStatusChanged;
  OnBleConnectedCallback? onDeviceConnected;

  BleStatus get status => _status;
  bool get isConnected => _status == BleStatus.connected;
  bool get isScanning => _status == BleStatus.scanning;
  String? get connectedDeviceId => _connectedDeviceId;
  String? get connectedDeviceName => _connectedDeviceName;
  BleProtocolType get activeProtocol => _activeProtocol;
  List<DiscoveredBleDevice> get discoveredDevices => _devices.values.toList();

  /// Start BLE scanning for nearby LED strip devices
  Future<void> startScan({bool showAll = false}) async {
    await stopScan();
    _devices.clear();
    onDevicesChanged?.call([]);

    _setStatus(BleStatus.scanning);

    try {
      if (!kIsWeb && Platform.isAndroid) {
        await UniversalBle.requestPermissions();
      }

      _scanSub = UniversalBle.scanStream.listen((BleDevice dev) {
        final name = dev.name?.trim() ?? '';
        final isKnown = BleProtocol.isKnownLedDevice(name);

        if (!showAll && !isKnown && name.isEmpty) {
          return;
        }

        final displayName = name.isNotEmpty ? name : 'BLE Device (${dev.deviceId.substring(0, 5)})';
        final item = DiscoveredBleDevice(
          id: dev.deviceId,
          name: displayName,
          rssi: dev.rssi ?? -99,
          isKnownLed: isKnown,
          lastSeen: DateTime.now(),
        );

        _devices[dev.deviceId] = item;
        onDevicesChanged?.call(_devices.values.toList());
      });

      await UniversalBle.startScan();
    } catch (e) {
      _setStatus(BleStatus.error, 'Failed to start BLE scan: $e');
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await _scanSub?.cancel();
      _scanSub = null;
      await UniversalBle.stopScan();
      if (_status == BleStatus.scanning) {
        _setStatus(BleStatus.idle);
      }
    } catch (_) {}
  }

  /// Connect to a target BLE device (by ID)
  Future<bool> connect(String deviceId, {String? deviceName}) async {
    await stopScan();
    _setStatus(BleStatus.connecting);
    _connectedDeviceId = deviceId;
    _connectedDeviceName = deviceName ?? _devices[deviceId]?.name ?? 'LED Strip';

    try {
      await UniversalBle.connect(
        deviceId,
        timeout: const Duration(seconds: 15),
      );

      // Listen for unexpected disconnections
      _connectionSub?.cancel();
      _connectionSub = UniversalBle.connectionStream(deviceId).listen((connected) {
        if (!connected && _status == BleStatus.connected) {
          _handleDisconnected();
        }
      });

      // Discover services & characteristics
      final services = await UniversalBle.discoverServices(deviceId);
      final discoveredServiceUuids = services.map((s) => s.uuid).toList();
      _activeProtocol = BleProtocol.detectProtocol(discoveredServiceUuids);

      // Find suitable write characteristic
      bool foundChar = false;
      final targetChars = BleProtocol.charUuids[_activeProtocol] ?? [];

      for (final service in services) {
        for (final char in service.characteristics) {
          final isMatch = targetChars.any((tc) => tc.toLowerCase() == char.uuid.toLowerCase());
          final canWrite = char.properties.contains(CharacteristicProperty.write) ||
              char.properties.contains(CharacteristicProperty.writeWithoutResponse);

          if (isMatch || (canWrite && !foundChar)) {
            _writeServiceUuid = service.uuid;
            _writeCharUuid = char.uuid;
            foundChar = true;
            if (isMatch) break;
          }
        }
        if (foundChar && _writeCharUuid != null) break;
      }

      if (!foundChar && services.isNotEmpty && services.first.characteristics.isNotEmpty) {
        _writeServiceUuid = services.first.uuid;
        _writeCharUuid = services.first.characteristics.first.uuid;
      }

      _setStatus(BleStatus.connected);
      onDeviceConnected?.call(_connectedDeviceId!, _connectedDeviceName!, _activeProtocol);
      return true;
    } catch (e) {
      _setStatus(BleStatus.error, 'Failed to connect: $e');
      _connectedDeviceId = null;
      _connectedDeviceName = null;
      return false;
    }
  }

  /// Send RGB color packet over BLE
  Future<void> sendColor(int r, int g, int b) async {
    if (!isConnected || _writeServiceUuid == null || _writeCharUuid == null) return;
    final cmd = BleProtocol.buildColorCmd(r, g, b, _activeProtocol);
    await _writeBytes(cmd);
  }

  /// Send Brightness packet over BLE (0.0 to 1.0)
  Future<void> sendBrightness(double brightness) async {
    if (!isConnected || _writeServiceUuid == null || _writeCharUuid == null) return;
    final cmd = BleProtocol.buildBrightnessCmd(brightness, _activeProtocol);
    await _writeBytes(cmd);
  }

  /// Send Power state packet over BLE
  Future<void> sendPower(bool on) async {
    if (!isConnected || _writeServiceUuid == null || _writeCharUuid == null) return;
    final cmd = BleProtocol.buildPowerCmd(on, _activeProtocol);
    await _writeBytes(cmd);
  }

  /// Send Speed packet over BLE (1 to 100)
  Future<void> sendSpeed(int speed) async {
    if (!isConnected || _writeServiceUuid == null || _writeCharUuid == null) return;
    final cmd = BleProtocol.buildSpeedCmd(speed, _activeProtocol);
    await _writeBytes(cmd);
  }

  /// Send native Hardware Mode command over BLE (e.g. rainbow, breathing, strobe)
  Future<void> sendMode(StripMode mode, int speed) async {
    if (!isConnected || _writeServiceUuid == null || _writeCharUuid == null) return;
    final cmd = BleProtocol.buildHardwareModeCmd(mode, speed, _activeProtocol);
    if (cmd != null) {
      await _writeBytes(cmd);
    }
  }

  Future<void> _writeBytes(Uint8List bytes) async {
    if (_connectedDeviceId == null || _writeServiceUuid == null || _writeCharUuid == null) return;
    try {
      await UniversalBle.write(
        _connectedDeviceId!,
        _writeServiceUuid!,
        _writeCharUuid!,
        bytes,
        withoutResponse: true,
      );
    } catch (_) {
      try {
        await UniversalBle.write(
          _connectedDeviceId!,
          _writeServiceUuid!,
          _writeCharUuid!,
          bytes,
          withoutResponse: false,
        );
      } catch (_) {}
    }
  }

  /// Disconnect from the current device
  Future<void> disconnect() async {
    if (_connectedDeviceId != null) {
      try {
        await UniversalBle.disconnect(_connectedDeviceId!);
      } catch (_) {}
    }
    _handleDisconnected();
  }

  void _handleDisconnected() {
    _connectionSub?.cancel();
    _connectionSub = null;
    _connectedDeviceId = null;
    _connectedDeviceName = null;
    _writeServiceUuid = null;
    _writeCharUuid = null;
    _setStatus(BleStatus.idle);
  }

  void _setStatus(BleStatus status, [String? message]) {
    _status = status;
    onStatusChanged?.call(_status, message);
  }

  void dispose() {
    stopScan();
    disconnect();
  }
}
