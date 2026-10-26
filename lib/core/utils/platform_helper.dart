import 'dart:io';
import 'package:flutter/foundation.dart';

/// Clean platform detection utility.
class PlatformHelper {
  PlatformHelper._();

  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  
  /// Desktop defaults to Server Host mode; Mobile defaults to Client mode.
  static bool get defaultIsHost => isDesktop;
}
