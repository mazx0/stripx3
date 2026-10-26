import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/platform_helper.dart';
import '../../models/update_manifest.dart';
import 'windows_updater.dart';

enum UpdateStatus {
  idle,
  checking,
  updateAvailable,
  downloading,
  readyToInstall,
  upToDate,
  error,
}

class UpdateProgress {
  final double progress; // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;
  final double speedKbps;

  const UpdateProgress({
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speedKbps = 0.0,
  });
}

typedef OnUpdateStatusChanged = void Function(UpdateStatus status, String? message);
typedef OnUpdateProgressChanged = void Function(UpdateProgress progress);

/// Discord-style self-hosted auto-update service.
class UpdateService {
  UpdateStatus _status = UpdateStatus.idle;
  UpdateManifest? _manifest;
  String? _downloadedFilePath;
  UpdateProgress _progress = const UpdateProgress();

  OnUpdateStatusChanged? onStatusChanged;
  OnUpdateProgressChanged? onProgressChanged;

  UpdateStatus get status => _status;
  UpdateManifest? get manifest => _manifest;
  UpdateProgress get progress => _progress;
  String? get downloadedFilePath => _downloadedFilePath;

  /// Check for updates quietly in the background or on demand.
  Future<UpdateManifest?> checkForUpdates({String? manifestUrl}) async {
    _setStatus(UpdateStatus.checking);

    try {
      final url = manifestUrl ?? AppConstants.defaultUpdateManifestUrl;
      String jsonText = '';

      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          jsonText = res.body;
        }
      } catch (_) {
        // Fallback to reading bundled version.json if network is unreachable or for self-test
        try {
          jsonText = await rootBundle.loadString('assets/version.json');
        } catch (_) {}
      }

      if (jsonText.isEmpty) {
        _setStatus(UpdateStatus.upToDate, 'No updates found');
        return null;
      }

      final manifestData = jsonDecode(jsonText) as Map<String, dynamic>;
      _manifest = UpdateManifest.fromJson(manifestData);

      // Determine current version
      String currentVersion = AppConstants.appVersion;
      try {
        final info = await PackageInfo.fromPlatform();
        if (info.version.isNotEmpty) {
          currentVersion = info.version;
        }
      } catch (_) {}

      if (_manifest!.isNewerThan(currentVersion)) {
        _setStatus(UpdateStatus.updateAvailable);
        return _manifest;
      } else {
        _setStatus(UpdateStatus.upToDate, 'StripX is up to date ($currentVersion)');
        return null;
      }
    } catch (e) {
      _setStatus(UpdateStatus.error, 'Failed to check for updates: $e');
      return null;
    }
  }

  /// Download the update package for the current platform.
  Future<bool> downloadUpdate() async {
    if (_manifest == null) return false;

    final downloadUrl = PlatformHelper.isWindows
        ? _manifest!.windows?.url
        : _manifest!.android?.url;

    if (downloadUrl == null || downloadUrl.isEmpty) {
      _setStatus(UpdateStatus.error, 'No download URL available for current platform');
      return false;
    }

    _setStatus(UpdateStatus.downloading);

    try {
      final tempDir = await getTemporaryDirectory();
      final ext = PlatformHelper.isWindows ? '.exe' : '.apk';
      final fileName = 'stripx3v_v${_manifest!.version}$ext';
      final file = File(p.join(tempDir.path, fileName));

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await http.Client().send(request);

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final startTime = DateTime.now();

      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final elapsedSec = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
        final speedKbps = elapsedSec > 0 ? (receivedBytes / 1024) / elapsedSec : 0.0;
        final pct = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

        _progress = UpdateProgress(
          progress: pct,
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          speedKbps: speedKbps,
        );
        onProgressChanged?.call(_progress);
      }

      await sink.flush();
      await sink.close();

      _downloadedFilePath = file.path;
      _setStatus(UpdateStatus.readyToInstall);
      return true;
    } catch (e) {
      _setStatus(UpdateStatus.error, 'Download failed: $e');
      return false;
    }
  }

  /// Apply update and restart application.
  Future<bool> applyUpdate() async {
    if (_downloadedFilePath == null) return false;

    if (PlatformHelper.isWindows) {
      return await WindowsUpdater.applyUpdateAndRestart(_downloadedFilePath!);
    } else if (PlatformHelper.isAndroid) {
      final result = await OpenFilex.open(
        _downloadedFilePath!,
        type: 'application/vnd.android.package-archive',
      );
      return result.type == ResultType.done;
    }
    return false;
  }

  void _setStatus(UpdateStatus status, [String? message]) {
    _status = status;
    onStatusChanged?.call(_status, message);
  }

  void reset() {
    _status = UpdateStatus.idle;
    _progress = const UpdateProgress();
    _downloadedFilePath = null;
    onStatusChanged?.call(_status, null);
  }
}
