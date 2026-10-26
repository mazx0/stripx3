import 'dart:async';

/// High-performance throttler and debouncer.
/// Ensures rapid UI events (e.g., slider drags at 120Hz) do not saturate the network,
/// while guaranteeing that the final settled value is immediately sent.
class Throttler {
  final Duration duration;
  Timer? _timer;
  bool _isThrottling = false;
  Function? _trailingCall;

  Throttler({required this.duration});

  /// Run callback immediately if not throttled; otherwise schedule a trailing call.
  void run(void Function() action) {
    if (!_isThrottling) {
      action();
      _isThrottling = true;
      _timer = Timer(duration, () {
        _isThrottling = false;
        if (_trailingCall != null) {
          _trailingCall!();
          _trailingCall = null;
        }
      });
    } else {
      _trailingCall = action;
    }
  }

  void cancel() {
    _timer?.cancel();
    _trailingCall = null;
    _isThrottling = false;
  }
}

/// Simple debounce utility.
class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer({required this.duration});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() {
    _timer?.cancel();
  }
}
