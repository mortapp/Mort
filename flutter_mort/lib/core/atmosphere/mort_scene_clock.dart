import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// A lifecycle-friendly elapsed-time source that drives painters directly.
///
/// The ticker updates [elapsed] and notifies paint listeners. It never asks a
/// widget to rebuild, so a running atmosphere can repaint at display cadence
/// while the surrounding route and content remain structurally stable.
class MortSceneClock extends ChangeNotifier {
  MortSceneClock(TickerProvider vsync) {
    _ticker = vsync.createTicker(_handleTick);
  }

  late Ticker _ticker;
  Duration _elapsed = Duration.zero;
  Duration _accumulated = Duration.zero;

  Duration get elapsed => _elapsed;
  bool get isActive => _ticker.isActive;

  void start() {
    if (_ticker.isActive) return;
    _ticker.start();
  }

  void stop() {
    if (!_ticker.isActive) return;
    _accumulated = _elapsed;
    _ticker.stop();
  }

  void _handleTick(Duration sessionElapsed) {
    _elapsed = _accumulated + sessionElapsed;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
