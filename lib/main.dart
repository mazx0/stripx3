import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/platform_helper.dart';
import 'core/utils/throttle.dart';
import 'models/strip_state.dart';
import 'providers/ble_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/strip_state_provider.dart';
import 'providers/update_provider.dart';
import 'screens/main_screen.dart';
import 'services/animation/animation_engine.dart';
import 'services/storage/storage_service.dart';
import 'services/tray/system_tray_service.dart';

void main() async {
  // Ensure Flutter engine bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize lightweight persistent storage (SharedPreferences)
  final storage = await StorageService.init();

  // Desktop Window & System Tray Configuration (Windows only)
  if (PlatformHelper.isDesktop) {
    final minimizeToTray = storage.getMinimizeToTray();
    await SystemTrayService().init(minimizeToTray: minimizeToTray);
  }

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
      child: const StripXApp(),
    ),
  );
}

class StripXApp extends ConsumerStatefulWidget {
  const StripXApp({super.key});

  @override
  ConsumerState<StripXApp> createState() => _StripXAppState();
}

class _StripXAppState extends ConsumerState<StripXApp> {
  @override
  void initState() {
    super.initState();
    // Schedule one-time async services startup on first frame
    scheduleMicrotask(() {
      final storage = ref.read(storageServiceProvider);

      // Initialize providers
      ref.read(settingsProvider.notifier).initialize(storage);
      ref.read(stripStateProvider.notifier).initialize(storage);
      ref.read(bleProvider.notifier).initialize(storage);
      ref.read(connectionProvider.notifier).initialize();
      ref.read(updateProvider.notifier).initialize();

      // Hook BLE commands so Dashboard sliders & colors send to connected Bluetooth strip
      ref.read(stripStateProvider.notifier).setBleBroadcastCallback((key, value) {
        final bleNotifier = ref.read(bleProvider.notifier);
        switch (key) {
          case 'power':
            if (value is bool) bleNotifier.sendPower(value);
            break;
          case 'brightness':
            if (value is num) {
              final b = value.toDouble();
              bleNotifier.sendBrightness(b);
              final st = ref.read(stripStateProvider);
              if (st.mode == StripMode.staticMode) {
                final c = st.primaryColor;
                bleNotifier.sendColor(
                  ((c.r * 255) * b).round().clamp(0, 255),
                  ((c.g * 255) * b).round().clamp(0, 255),
                  ((c.b * 255) * b).round().clamp(0, 255),
                );
              }
            }
            break;
          case 'speed':
            if (value is num) {
              final s = value.toInt();
              bleNotifier.sendSpeed(s);
            }
            break;
          case 'mode':
            if (value is String) {
              final mode = StripMode.fromString(value);
              final st = ref.read(stripStateProvider);
              if (mode == StripMode.staticMode) {
                final c = st.primaryColor;
                final b = st.brightness;
                bleNotifier.sendColor(
                  ((c.r * 255) * b).round().clamp(0, 255),
                  ((c.g * 255) * b).round().clamp(0, 255),
                  ((c.b * 255) * b).round().clamp(0, 255),
                );
              }
            }
            break;
          case 'primaryColor':
            if (value is num) {
              final c = Color(value.toInt());
              final st = ref.read(stripStateProvider);
              if (st.mode == StripMode.staticMode) {
                final b = st.brightness;
                bleNotifier.sendColor(
                  ((c.r * 255) * b).round().clamp(0, 255),
                  ((c.g * 255) * b).round().clamp(0, 255),
                  ((c.b * 255) * b).round().clamp(0, 255),
                );
              }
            }
            break;
        }
      });

      // Stream dynamic StripX Color Engine animation frames to connected BLE strip
      final bleFrameThrottler = Throttler(duration: const Duration(milliseconds: 45));
      AnimationEngine().onFrame = (color, brightness) {
        final bleState = ref.read(bleProvider);
        final stripState = ref.read(stripStateProvider);
        if (bleState.isConnected && stripState.power && stripState.mode != StripMode.staticMode) {
          bleFrameThrottler.run(() {
            final r = ((color.r * 255) * brightness).round().clamp(0, 255);
            final g = ((color.g * 255) * brightness).round().clamp(0, 255);
            final b = ((color.b * 255) * brightness).round().clamp(0, 255);
            ref.read(bleProvider.notifier).sendColor(r, g, b);
          });
        }
      };

      // Hook System Tray direct power toggle on Windows Desktop
      if (PlatformHelper.isDesktop) {
        SystemTrayService().onTrayPowerToggle = () {
          ref.read(stripStateProvider.notifier).togglePower();
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StripX v3',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        // Exclude semantics on Desktop to bypass Flutter Windows accessibility_bridge.cc AXTree bug
        if (PlatformHelper.isDesktop) {
          return ExcludeSemantics(
            child: child ?? const SizedBox.shrink(),
          );
        }
        return child ?? const SizedBox.shrink();
      },
      home: const MainScreen(),
    );
  }
}
