import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'nfc_pulse_painter.dart';

/// Manages NFC pulse animations and timing
class NfcPulseManager extends ChangeNotifier {
  final List<NfcPulse> _pulses = <NfcPulse>[];
  final math.Random _rng = math.Random();

  int _currentTimeMs = DateTime.now().millisecondsSinceEpoch;
  Timer? _heartbeatTimer;
  Ticker? _animationTicker;
  bool _coolDown = false;

  // Callback to request container size for heartbeat pulses
  Size Function()? _getContainerSize;

  // Animation configuration
  static const Duration pulseDuration = Duration(milliseconds: 2200);
  static const Duration heartbeatMedian = Duration(milliseconds: 1500);
  static const double heartbeatJitter = 0.60;
  static const double autoBaseAlpha = 0.30;
  static const double manualBaseAlpha = 0.25;

  List<NfcPulse> get pulses => List.unmodifiable(_pulses);
  int get currentTimeMs => _currentTimeMs;
  bool get isAnimating => _pulses.isNotEmpty;

  void initialize(TickerProvider vsync, {Size Function()? getContainerSize}) {
    _animationTicker = vsync.createTicker(_onAnimationTick);
    _getContainerSize = getContainerSize;
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _animationTicker?.dispose();
    super.dispose();
  }

  void startHeartbeat(bool isNfcReady) {
    _scheduleNextHeartbeat(isNfcReady);
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void addManualPulse(Offset position, Size containerSize) {
    if (_coolDown) return;

    _enqueueTriplePulse(position);
  }

  void addHeartbeatPulse(Size containerSize) {
    if (_coolDown) return;

    final origin = _randomOriginUniformDisk(containerSize);
    _enqueueSinglePulse(origin, baseAlpha: autoBaseAlpha);
  }

  void _enqueueHeartbeatPulse() {
    // This method is now empty - heartbeat pulses are handled by the widget
  }

  void _scheduleNextHeartbeat(bool isNfcReady) {
    _heartbeatTimer?.cancel();

    final Duration delay = _jitteredDelay(
      isNfcReady ? heartbeatMedian : heartbeatMedian * 3,
      isNfcReady ? heartbeatJitter : 0.1,
    );

    _heartbeatTimer = Timer(delay, () {
      // Try to create a heartbeat pulse if we can get the container size
      final getSize = _getContainerSize;
      if (getSize != null) {
        try {
          final size = getSize();
          addHeartbeatPulse(size);
        } catch (_) {
          // Ignore errors if size is not available
        }
      }
      _scheduleNextHeartbeat(isNfcReady);
    });
  }

  Duration _jitteredDelay(Duration median, double jitter) {
    final low =
        (median.inMilliseconds * (1.0 - jitter)).clamp(50, 1 << 31).toInt();
    final high =
        (median.inMilliseconds * (1.0 + jitter)).clamp(50, 1 << 31).toInt();
    final ms = low + _rng.nextInt((high - low + 1).clamp(1, 1 << 30));
    return Duration(milliseconds: ms);
  }

  Offset _randomOriginUniformDisk(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.45;
    final u = _rng.nextDouble();
    final r = math.sqrt(u) * radius;
    final theta = _rng.nextDouble() * 2 * math.pi;
    return center + Offset(r * math.cos(theta), r * math.sin(theta));
  }

  void _enqueueSinglePulse(Offset origin,
      {required double baseAlpha, Duration? duration}) {
    final d = duration ?? pulseDuration;
    final start = DateTime.now().millisecondsSinceEpoch;
    final wasEmpty = _pulses.isEmpty;

    _pulses.add(NfcPulse(
      origin: origin,
      baseAlpha: baseAlpha,
      startMs: start,
      durationMs: d.inMilliseconds,
    ));

    _ensureAnimationTicker();
    if (wasEmpty) notifyListeners();
  }

  void _enqueueTriplePulse(Offset baseOrigin) {
    const double spread = 10.0;
    const angles = <double>[0.0, 2 * math.pi / 3, 4 * math.pi / 3];
    const delays = <int>[0, 210, 420];
    const dimming = <double>[0.7, 0.5, 0.1];

    // First pulse
    final o1 = baseOrigin +
        Offset(spread * math.cos(angles[0]), spread * math.sin(angles[0]));
    _enqueueSinglePulse(o1, baseAlpha: manualBaseAlpha * dimming[0]);

    // Second pulse
    final o2 = baseOrigin +
        Offset(spread * math.cos(angles[1]), spread * math.sin(angles[1]));
    Timer(Duration(milliseconds: delays[1]), () {
      _enqueueSinglePulse(o2, baseAlpha: manualBaseAlpha * dimming[1]);
    });

    // Third pulse
    final o3 = baseOrigin +
        Offset(spread * math.cos(angles[2]), spread * math.sin(angles[2]));
    Timer(Duration(milliseconds: delays[2]), () {
      _enqueueSinglePulse(o3, baseAlpha: manualBaseAlpha * dimming[2]);
    });

    // Set cooldown
    _coolDown = true;
    Timer(heartbeatMedian, () {
      _coolDown = false;
    });
  }

  void _ensureAnimationTicker() {
    if (_animationTicker?.isActive != true) {
      _animationTicker?.start();
    }
  }

  void _onAnimationTick(Duration _) {
    _currentTimeMs = DateTime.now().millisecondsSinceEpoch;
    final initialCount = _pulses.length;

    if (initialCount > 0) {
      _pulses.removeWhere((p) => (_currentTimeMs - p.startMs) >= p.durationMs);
    }

    final wasEmptied = initialCount > 0 && _pulses.isEmpty;

    if (_pulses.isEmpty) {
      _animationTicker?.stop();
      if (wasEmptied) notifyListeners();
    } else {
      notifyListeners();
    }
  }
}
