import 'dart:io';
import 'package:path/path.dart' as p;

/// Handles seamless self-updating on Windows Desktop.
/// Writes and executes a background detached batch script that waits for
/// the current process to terminate, replaces the binary/files, and restarts the app.
class WindowsUpdater {
  WindowsUpdater._();

  static Future<bool> applyUpdateAndRestart(String downloadedFilePath) async {
    if (!Platform.isWindows) return false;

    try {
      final currentExe = Platform.resolvedExecutable;
      final tempDir = Directory.systemTemp.path;
      final scriptPath = p.join(tempDir, 'stripx_update_${DateTime.now().millisecondsSinceEpoch}.bat');

      final ext = p.extension(downloadedFilePath).toLowerCase();

      String scriptContent;
      if (ext == '.exe' && !downloadedFilePath.toLowerCase().contains('setup')) {
        // Direct executable replacement
        scriptContent = '''
@echo off
setlocal
echo Updating StripX v3...
timeout /t 1 /nobreak > nul

:WAIT_LOOP
tasklist /fi "imagename eq ${p.basename(currentExe)}" | find /i "${p.basename(currentExe)}" > nul
if %ERRORLEVEL% == 0 (
    timeout /t 1 /nobreak > nul
    goto WAIT_LOOP
)

echo Replacing executable...
copy /Y "$downloadedFilePath" "$currentExe" > nul
if %ERRORLEVEL% NEQ 0 (
    echo Retrying in 1s...
    timeout /t 1 /nobreak > nul
    copy /Y "$downloadedFilePath" "$currentExe" > nul
)

echo Restarting StripX v3...
start "" "$currentExe"

echo Cleaning up...
del "$downloadedFilePath" > nul 2>&1
(goto) 2>nul & del "%~f0"
''';
      } else {
        // Installer / Setup execution
        scriptContent = '''
@echo off
setlocal
echo Launching StripX v3 Installer...
timeout /t 1 /nobreak > nul
start "" "$downloadedFilePath"
(goto) 2>nul & del "%~f0"
''';
      }

      await File(scriptPath).writeAsString(scriptContent);

      // Launch the detached batch script
      await Process.start(
        'cmd.exe',
        ['/c', scriptPath],
        mode: ProcessStartMode.detached,
      );

      // Gracefully exit the current Flutter application
      exit(0);
    } catch (_) {
      return false;
    }
  }
}
