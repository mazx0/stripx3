import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/platform_helper.dart';
import '../../services/storage/storage_service.dart';
import '../../services/tray/system_tray_service.dart';

class AppSettings {
  final bool autoDiscover;
  final bool autoUpdateCheck;
  final String updateManifestUrl;
  final bool minimizeToTray;
  final bool autoStartHost;
  final int hostPort;
  final List<String> recentIps;
  final String? lastIp;

  const AppSettings({
    this.autoDiscover = true,
    this.autoUpdateCheck = true,
    this.updateManifestUrl = AppConstants.defaultUpdateManifestUrl,
    this.minimizeToTray = true,
    this.autoStartHost = true,
    this.hostPort = AppConstants.defaultWsPort,
    this.recentIps = const [],
    this.lastIp,
  });

  AppSettings copyWith({
    bool? autoDiscover,
    bool? autoUpdateCheck,
    String? updateManifestUrl,
    bool? minimizeToTray,
    bool? autoStartHost,
    int? hostPort,
    List<String>? recentIps,
    String? lastIp,
  }) {
    return AppSettings(
      autoDiscover: autoDiscover ?? this.autoDiscover,
      autoUpdateCheck: autoUpdateCheck ?? this.autoUpdateCheck,
      updateManifestUrl: updateManifestUrl ?? this.updateManifestUrl,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      autoStartHost: autoStartHost ?? this.autoStartHost,
      hostPort: hostPort ?? this.hostPort,
      recentIps: recentIps ?? this.recentIps,
      lastIp: lastIp ?? this.lastIp,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  late final StorageService _storage;

  @override
  AppSettings build() {
    return const AppSettings();
  }

  void initialize(StorageService storage) {
    _storage = storage;
    state = AppSettings(
      autoDiscover: _storage.getAutoDiscover(),
      autoUpdateCheck: _storage.getAutoUpdateCheck(),
      updateManifestUrl: _storage.getUpdateManifestUrl(),
      minimizeToTray: _storage.getMinimizeToTray(),
      autoStartHost: _storage.getAutoStartHost(),
      hostPort: _storage.getLastPort(),
      recentIps: _storage.getRecentIps(),
      lastIp: _storage.getLastIp(),
    );
  }

  Future<void> setAutoDiscover(bool value) async {
    state = state.copyWith(autoDiscover: value);
    await _storage.setAutoDiscover(value);
  }

  Future<void> setAutoUpdateCheck(bool value) async {
    state = state.copyWith(autoUpdateCheck: value);
    await _storage.setAutoUpdateCheck(value);
  }

  Future<void> setUpdateManifestUrl(String url) async {
    state = state.copyWith(updateManifestUrl: url);
    await _storage.setUpdateManifestUrl(url);
  }

  Future<void> setMinimizeToTray(bool value) async {
    state = state.copyWith(minimizeToTray: value);
    await _storage.setMinimizeToTray(value);
    if (PlatformHelper.isDesktop) {
      SystemTrayService().updateMinimizeToTrayPreference(value);
    }
  }

  Future<void> setAutoStartHost(bool value) async {
    state = state.copyWith(autoStartHost: value);
    await _storage.setAutoStartHost(value);
  }

  Future<void> setHostPort(int port) async {
    state = state.copyWith(hostPort: port);
    await _storage.saveLastPort(port);
  }

  Future<void> addRecentIp(String ip) async {
    await _storage.saveRecentIp(ip);
    state = state.copyWith(
      recentIps: _storage.getRecentIps(),
      lastIp: ip,
    );
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be initialized in main');
});

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(() {
  return SettingsNotifier();
});
