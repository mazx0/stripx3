/// Remote version manifest representing the update specification.
class UpdatePlatformInfo {
  final String url;
  final String? sha256;
  final String? type; // 'exe', 'msix', 'apk', 'zip'
  final int? sizeBytes;

  const UpdatePlatformInfo({
    required this.url,
    this.sha256,
    this.type,
    this.sizeBytes,
  });

  factory UpdatePlatformInfo.fromJson(Map<String, dynamic> json) {
    return UpdatePlatformInfo(
      url: json['url'] as String? ?? '',
      sha256: json['sha256'] as String?,
      type: json['type'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'sha256': sha256,
      'type': type,
      'sizeBytes': sizeBytes,
    };
  }
}

class UpdateManifest {
  final String version;
  final int versionCode;
  final String releaseDate;
  final bool mandatory;
  final String releaseNotes;
  final UpdatePlatformInfo? windows;
  final UpdatePlatformInfo? android;

  const UpdateManifest({
    required this.version,
    required this.versionCode,
    required this.releaseDate,
    required this.mandatory,
    required this.releaseNotes,
    this.windows,
    this.android,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    return UpdateManifest(
      version: json['version'] as String? ?? '1.0.0',
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 100,
      releaseDate: json['releaseDate'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
      releaseNotes: json['releaseNotes'] as String? ?? '',
      windows: json['windows'] != null
          ? UpdatePlatformInfo.fromJson(json['windows'] as Map<String, dynamic>)
          : null,
      android: json['android'] != null
          ? UpdatePlatformInfo.fromJson(json['android'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'versionCode': versionCode,
      'releaseDate': releaseDate,
      'mandatory': mandatory,
      'releaseNotes': releaseNotes,
      'windows': windows?.toJson(),
      'android': android?.toJson(),
    };
  }

  /// Compares this version against a target semantic version string (e.g. '3.0.0').
  /// Returns true if this manifest version is strictly newer.
  bool isNewerThan(String currentVersion) {
    try {
      final currentParts = currentVersion.split('+').first.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final manifestParts = version.split('+').first.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final cur = i < currentParts.length ? currentParts[i] : 0;
        final man = i < manifestParts.length ? manifestParts[i] : 0;
        if (man > cur) return true;
        if (man < cur) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
