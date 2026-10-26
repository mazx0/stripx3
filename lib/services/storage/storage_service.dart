import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../models/strip_state.dart';

/// Lightweight persistent local storage wrapper using SharedPreferences.
class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Connection History (Wi-Fi) ---

  List<String> getRecentIps() {
    return _prefs.getStringList(AppConstants.keyRecentIps) ?? [];
  }

  Future<void> saveRecentIp(String ip) async {
    final list = getRecentIps().toList();
    list.remove(ip);
    list.insert(0, ip);
    if (list.length > AppConstants.maxRecentIps) {
      list.removeRange(AppConstants.maxRecentIps, list.length);
    }
    await _prefs.setStringList(AppConstants.keyRecentIps, list);
    await _prefs.setString(AppConstants.keyLastIp, ip);
  }

  String? getLastIp() {
    return _prefs.getString(AppConstants.keyLastIp);
  }

  int getLastPort() {
    return _prefs.getInt(AppConstants.keyLastPort) ?? AppConstants.defaultWsPort;
  }

  Future<void> saveLastPort(int port) async {
    await _prefs.setInt(AppConstants.keyLastPort, port);
  }

  // --- Bluetooth (BLE) Saved Devices ---

  List<Map<String, String>> getSavedBleDevices() {
    final raw = _prefs.getStringList(AppConstants.keySavedBleDevices) ?? [];
    final List<Map<String, String>> list = [];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        list.add({
          'id': decoded['id']?.toString() ?? '',
          'name': decoded['name']?.toString() ?? 'LED Strip',
          'protocol': decoded['protocol']?.toString() ?? 'bledom',
        });
      } catch (_) {}
    }
    return list;
  }

  Future<void> saveBleDevice(String id, String name, String protocol) async {
    final list = getSavedBleDevices();
    list.removeWhere((d) => d['id'] == id);
    list.insert(0, {
      'id': id,
      'name': name,
      'protocol': protocol,
    });
    // Keep up to 8 saved strips
    if (list.length > 8) {
      list.removeRange(8, list.length);
    }
    final encoded = list.map((d) => jsonEncode(d)).toList();
    await _prefs.setStringList(AppConstants.keySavedBleDevices, encoded);
  }

  Future<void> removeSavedBleDevice(String id) async {
    final list = getSavedBleDevices();
    list.removeWhere((d) => d['id'] == id);
    final encoded = list.map((d) => jsonEncode(d)).toList();
    await _prefs.setStringList(AppConstants.keySavedBleDevices, encoded);
  }

  // --- Preferences ---

  bool getAutoDiscover() {
    return _prefs.getBool(AppConstants.keyAutoDiscover) ?? true;
  }

  Future<void> setAutoDiscover(bool value) async {
    await _prefs.setBool(AppConstants.keyAutoDiscover, value);
  }

  bool getAutoUpdateCheck() {
    return _prefs.getBool(AppConstants.keyAutoUpdateCheck) ?? true;
  }

  Future<void> setAutoUpdateCheck(bool value) async {
    await _prefs.setBool(AppConstants.keyAutoUpdateCheck, value);
  }

  String getUpdateManifestUrl() {
    return _prefs.getString(AppConstants.keyUpdateManifestUrl) ??
        AppConstants.defaultUpdateManifestUrl;
  }

  Future<void> setUpdateManifestUrl(String url) async {
    await _prefs.setString(AppConstants.keyUpdateManifestUrl, url);
  }

  bool getMinimizeToTray() {
    return _prefs.getBool(AppConstants.keyMinimizeToTray) ?? true;
  }

  Future<void> setMinimizeToTray(bool value) async {
    await _prefs.setBool(AppConstants.keyMinimizeToTray, value);
  }

  bool getAutoStartHost() {
    return _prefs.getBool(AppConstants.keyAutoStartHost) ?? true;
  }

  Future<void> setAutoStartHost(bool value) async {
    await _prefs.setBool(AppConstants.keyAutoStartHost, value);
  }

  // --- Strip State Persistence ---

  StripState? getSavedStripState() {
    final raw = _prefs.getString(AppConstants.keyStripState);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return StripState.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveStripState(StripState state) async {
    await _prefs.setString(AppConstants.keyStripState, jsonEncode(state.toJson()));
  }
}
