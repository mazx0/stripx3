import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/strip_state.dart';
import '../services/ble/ble_protocol.dart';
import '../services/ble/ble_service.dart';
import '../services/storage/storage_service.dart';

class BleState {
  final BleStatus status;
  final List<DiscoveredBleDevice> devices;
  final List<Map<String, String>> savedDevices;
  final String? connectedDeviceId;
  final String? connectedDeviceName;
  final BleProtocolType activeProtocol;
  final bool showAllDevices;
  final String? errorMessage;

  const BleState({
    this.status = BleStatus.idle,
    this.devices = const [],
    this.savedDevices = const [],
    this.connectedDeviceId,
    this.connectedDeviceName,
    this.activeProtocol = BleProtocolType.bledom,
    this.showAllDevices = false,
    this.errorMessage,
  });

  bool get isConnected => status == BleStatus.connected;
  bool get isScanning => status == BleStatus.scanning;

  BleState copyWith({
    BleStatus? status,
    List<DiscoveredBleDevice>? devices,
    List<Map<String, String>>? savedDevices,
    String? connectedDeviceId,
    String? connectedDeviceName,
    BleProtocolType? activeProtocol,
    bool? showAllDevices,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BleState(
      status: status ?? this.status,
      devices: devices ?? this.devices,
      savedDevices: savedDevices ?? this.savedDevices,
      connectedDeviceId: connectedDeviceId ?? this.connectedDeviceId,
      connectedDeviceName: connectedDeviceName ?? this.connectedDeviceName,
      activeProtocol: activeProtocol ?? this.activeProtocol,
      showAllDevices: showAllDevices ?? this.showAllDevices,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class BleNotifier extends Notifier<BleState> {
  final BleService _bleService = BleService();
  StorageService? _storage;

  @override
  BleState build() {
    _bleService.onDevicesChanged = (devices) {
      state = state.copyWith(devices: devices);
    };

    _bleService.onStatusChanged = (status, msg) {
      state = state.copyWith(
        status: status,
        connectedDeviceId: _bleService.connectedDeviceId,
        connectedDeviceName: _bleService.connectedDeviceName,
        activeProtocol: _bleService.activeProtocol,
        errorMessage: msg,
        clearError: status != BleStatus.error,
      );
    };

    _bleService.onDeviceConnected = (id, name, protocol) {
      if (_storage != null) {
        _storage!.saveBleDevice(id, name, protocol.name);
        state = state.copyWith(savedDevices: _storage!.getSavedBleDevices());
      }
    };

    return const BleState();
  }

  void initialize(StorageService storage) {
    _storage = storage;
    state = state.copyWith(savedDevices: _storage!.getSavedBleDevices());
  }

  void startScan() {
    _bleService.startScan(showAll: state.showAllDevices);
  }

  void stopScan() {
    _bleService.stopScan();
  }

  void toggleShowAll(bool value) {
    state = state.copyWith(showAllDevices: value);
    if (state.isScanning) {
      startScan();
    }
  }

  Future<bool> connect(String deviceId, {String? deviceName}) async {
    return await _bleService.connect(deviceId, deviceName: deviceName);
  }

  Future<void> disconnect() async {
    await _bleService.disconnect();
  }

  Future<void> removeSavedDevice(String id) async {
    if (_storage != null) {
      await _storage!.removeSavedBleDevice(id);
      state = state.copyWith(savedDevices: _storage!.getSavedBleDevices());
    }
  }

  void sendColor(int r, int g, int b) {
    _bleService.sendColor(r, g, b);
  }

  void sendBrightness(double brightness) {
    _bleService.sendBrightness(brightness);
  }

  void sendPower(bool on) {
    _bleService.sendPower(on);
  }

  void sendSpeed(int speed) {
    _bleService.sendSpeed(speed);
  }

  void sendMode(StripMode mode, int speed) {
    _bleService.sendMode(mode, speed);
  }
}

final bleProvider = NotifierProvider<BleNotifier, BleState>(() {
  return BleNotifier();
});
