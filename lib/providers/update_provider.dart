import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/update_manifest.dart';
import '../../services/updater/update_service.dart';
import 'settings_provider.dart';

class UpdateState {
  final UpdateStatus status;
  final UpdateManifest? manifest;
  final UpdateProgress progress;
  final bool isBannerVisible;
  final bool isModalVisible;
  final String? statusMessage;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.manifest,
    this.progress = const UpdateProgress(),
    this.isBannerVisible = false,
    this.isModalVisible = false,
    this.statusMessage,
  });

  bool get hasUpdate =>
      status == UpdateStatus.updateAvailable ||
      status == UpdateStatus.downloading ||
      status == UpdateStatus.readyToInstall;

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateManifest? manifest,
    UpdateProgress? progress,
    bool? isBannerVisible,
    bool? isModalVisible,
    String? statusMessage,
    bool clearMessage = false,
  }) {
    return UpdateState(
      status: status ?? this.status,
      manifest: manifest ?? this.manifest,
      progress: progress ?? this.progress,
      isBannerVisible: isBannerVisible ?? this.isBannerVisible,
      isModalVisible: isModalVisible ?? this.isModalVisible,
      statusMessage: clearMessage ? null : (statusMessage ?? this.statusMessage),
    );
  }
}

class UpdateNotifier extends Notifier<UpdateState> {
  final UpdateService _updateService = UpdateService();

  @override
  UpdateState build() {
    _updateService.onStatusChanged = (status, msg) {
      final showBanner = status == UpdateStatus.updateAvailable ||
          status == UpdateStatus.readyToInstall;
      state = state.copyWith(
        status: status,
        statusMessage: msg,
        isBannerVisible: showBanner,
        manifest: _updateService.manifest,
      );
    };

    _updateService.onProgressChanged = (progress) {
      state = state.copyWith(progress: progress);
    };

    return const UpdateState();
  }

  void initialize() {
    final settings = ref.read(settingsProvider);
    if (settings.autoUpdateCheck) {
      checkForUpdates(quiet: true);
    }
  }

  Future<void> checkForUpdates({bool quiet = false}) async {
    final settings = ref.read(settingsProvider);
    final manifest = await _updateService.checkForUpdates(
      manifestUrl: settings.updateManifestUrl,
    );

    if (manifest != null) {
      state = state.copyWith(
        manifest: manifest,
        isBannerVisible: true,
      );
    } else if (!quiet) {
      state = state.copyWith(
        statusMessage: 'StripX is currently up to date.',
      );
    }
  }

  Future<void> downloadUpdate() async {
    await _updateService.downloadUpdate();
  }

  Future<void> applyUpdate() async {
    await _updateService.applyUpdate();
  }

  void dismissBanner() {
    state = state.copyWith(isBannerVisible: false);
  }

  void showModal() {
    state = state.copyWith(isModalVisible: true);
  }

  void hideModal() {
    state = state.copyWith(isModalVisible: false);
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(() {
  return UpdateNotifier();
});
