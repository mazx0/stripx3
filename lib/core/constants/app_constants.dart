/// Application-wide constants, network defaults, and timing parameters.
class AppConstants {
  AppConstants._();

  static const String appName = 'StripX v3';
  static const String appVersion = '3.0.0';
  static const int appBuildNumber = 1;

  // Network Ports
  static const int defaultWsPort = 8765;
  static const int defaultUdpPort = 41235;

  // Auto-Update Manifest URL (Can be replaced with any self-hosted or raw GitHub URL)
  static const String defaultUpdateManifestUrl =
      'https://raw.githubusercontent.com/stripx/stripx3v/main/version.json';

  // Desktop Window Dimensions
  static const double desktopDefaultWidth = 980;
  static const double desktopDefaultHeight = 680;
  static const double desktopMinWidth = 800;
  static const double desktopMinHeight = 560;

  // Performance & Network Timers
  static const int pingIntervalMs = 2500;
  static const int sliderThrottleMs = 35; // ~28 fps network rate while keeping 60fps UI
  static const int autoDiscoveryIntervalSec = 3;
  static const int reconnectBackoffMs = 2000;
  static const int maxRecentIps = 5;

  // Storage Keys
  static const String keyRecentIps = 'stripx_recent_ips';
  static const String keyLastIp = 'stripx_last_ip';
  static const String keyLastPort = 'stripx_last_port';
  static const String keyAutoDiscover = 'stripx_auto_discover';
  static const String keyAutoUpdateCheck = 'stripx_auto_update_check';
  static const String keyUpdateManifestUrl = 'stripx_update_manifest_url';
  static const String keyMinimizeToTray = 'stripx_minimize_to_tray';
  static const String keyAutoStartHost = 'stripx_auto_start_host';
  static const String keyStripState = 'stripx_saved_strip_state';
  static const String keySavedBleDevices = 'stripx_saved_ble_devices';
}
