import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/platform_helper.dart';

typedef OnTrayPowerToggleCallback = void Function();

/// Service managing Windows Desktop Window sizing and System Tray background running.
class SystemTrayService with TrayListener, WindowListener {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  bool _initialized = false;
  bool _minimizeToTrayOnClose = true;
  OnTrayPowerToggleCallback? onTrayPowerToggle;

  bool get isSupported => PlatformHelper.isWindows;

  /// Initialize Window and System Tray for Windows Desktop
  Future<void> init({bool minimizeToTray = true}) async {
    if (!isSupported || _initialized) return;
    _minimizeToTrayOnClose = minimizeToTray;

    try {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(AppConstants.desktopDefaultWidth, AppConstants.desktopDefaultHeight),
        minimumSize: Size(AppConstants.desktopMinWidth, AppConstants.desktopMinHeight),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: AppConstants.appName,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      await windowManager.setPreventClose(true);
      windowManager.addListener(this);

      // System Tray Initialization
      trayManager.addListener(this);
      await _setupTray();

      _initialized = true;
    } catch (_) {
      // Graceful fallback if window_manager / tray fails on certain environments
    }
  }

  void updateMinimizeToTrayPreference(bool value) {
    _minimizeToTrayOnClose = value;
  }

  Future<void> _setupTray() async {
    try {
      final iconPath = Platform.isWindows ? 'assets/icons/tray_icon.ico' : 'assets/icons/app_icon.png';
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('StripX v3');

      final menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Show StripX v3',
          ),
          MenuItem(
            key: 'toggle_power',
            label: 'Toggle Power',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Exit StripX',
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
    } catch (_) {}
  }

  // --- WindowListener Events ---

  @override
  void onWindowClose() async {
    if (_minimizeToTrayOnClose) {
      await windowManager.hide();
    } else {
      await dispose();
      exit(0);
    }
  }

  // --- TrayListener Events ---

  @override
  void onTrayIconMouseDown() async {
    await restoreWindow();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_window':
        await restoreWindow();
        break;
      case 'toggle_power':
        onTrayPowerToggle?.call();
        break;
      case 'exit_app':
        await dispose();
        exit(0);
    }
  }

  Future<void> restoreWindow() async {
    try {
      final isVisible = await windowManager.isVisible();
      if (!isVisible) {
        await windowManager.show();
      }
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> minimizeToTray() async {
    try {
      await windowManager.hide();
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (!isSupported) return;
    try {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
      await trayManager.destroy();
    } catch (_) {}
  }
}
