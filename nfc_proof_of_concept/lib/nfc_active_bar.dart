import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:flutter/scheduler.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation.dart';

class NfcActiveBar extends StatefulWidget {
  final bool toggle;
  const NfcActiveBar({super.key, this.toggle = false});
  @override
  State<NfcActiveBar> createState() => _NfcActiveBarState();
}

class _NfcActiveBarState extends State<NfcActiveBar>
    with TickerProviderStateMixin, ChangeNotifier {
  bool _nfcReady = false;
  bool _checking = false;
  bool _coolDown = false;

  static const double _boxWidth = 210;
  static const double _boxHeight = 38;

  final Duration _pulseDuration = const Duration(milliseconds: 2200);
  final Duration _heartbeatMedian = const Duration(milliseconds: 1500);
  final double _heartbeatJitter = 0.10;
  final double _autoBaseAlpha = 0.30;
  final double _manualBaseAlpha = 0.25;

  final List<_Pulse> pulses = <_Pulse>[];
  int nowMs = DateTime.now().millisecondsSinceEpoch;

  final math.Random _rng = math.Random();
  Timer? _hbTimer;

  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNfc());
  }

  @override
  void dispose() {
    _hbTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _checkNfc() async {
    if (_checking) return;

    setState(() => _checking = true);
    _stopHeartbeat();

    bool isEnabled = false;
    try {
      var res = await NfcHce.checkDeviceNfcState();
      isEnabled = (res == NfcState.enabled);
      await Future.delayed(const Duration(milliseconds: 1000));
    } catch (e) {
      isEnabled = false;
    } finally {
      if (!mounted) return;
      setState(() {
        _nfcReady = isEnabled;
        _checking = false;
      });
    }
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _enqueueHeartbeatPulse();
    _scheduleNextHeartbeat();
  }

  void _stopHeartbeat() {
    _hbTimer?.cancel();
    _hbTimer = null;
  }

  void _scheduleNextHeartbeat() {
    _hbTimer?.cancel();
    final Duration delay = _jitteredDelay(
      _nfcReady ? _heartbeatMedian : _heartbeatMedian * 2,
      _heartbeatJitter,
    );

    _hbTimer = Timer(delay, () {
      if (!mounted) return;
      _enqueueHeartbeatPulse();

      _scheduleNextHeartbeat();
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

  void _enqueueHeartbeatPulse() {
    if (_coolDown) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final s = box.size;
    final origin = _randomOriginUniformDisk(s);
    _enqueueOnePulse(origin, baseAlpha: _autoBaseAlpha);
  }

  Offset _randomOriginUniformDisk(Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final R = math.min(s.width, s.height) * 0.45;
    final u = _rng.nextDouble();
    final r = math.sqrt(u) * R;
    final th = _rng.nextDouble() * 2 * math.pi;
    return c + Offset(r * math.cos(th), r * math.sin(th));
  }

  void _enqueueOnePulse(Offset origin,
      {required double baseAlpha, Duration? duration}) {
    final d = duration ?? _pulseDuration;
    final start = DateTime.now().millisecondsSinceEpoch;
    final wasEmpty = pulses.isEmpty;
    pulses.add(_Pulse(
        origin: origin,
        baseAlpha: baseAlpha,
        startMs: start,
        durationMs: d.inMilliseconds));
    _ensureTicker();
    if (wasEmpty) setState(() {});
  }

  void _enqueueTriplePulse(Offset baseOrigin) {
    const double spread = 10.0;
    const angles = <double>[0.0, 2 * math.pi / 3, 4 * math.pi / 3];
    const delays = <int>[0, 210, 420];
    const dimming = <double>[0.7, 0.5, 0.1];

    final o1 = baseOrigin +
        Offset(spread * math.cos(angles[0]), spread * math.sin(angles[0]));
    _enqueueOnePulse(o1, baseAlpha: _manualBaseAlpha * dimming[0]);

    final o2 = baseOrigin +
        Offset(spread * math.cos(angles[1]), spread * math.sin(angles[1]));
    Future.delayed(Duration(milliseconds: delays[1]), () {
      if (!mounted) return;
      _enqueueOnePulse(o2, baseAlpha: _manualBaseAlpha * dimming[1]);
    });

    final o3 = baseOrigin +
        Offset(spread * math.cos(angles[2]), spread * math.sin(angles[2]));
    Future.delayed(Duration(milliseconds: delays[2]), () {
      if (!mounted) return;
      _enqueueOnePulse(o3, baseAlpha: _manualBaseAlpha * dimming[2]);
    });

    _coolDown = true;
    Future.delayed(_heartbeatMedian, () {
      _coolDown = false;
    });
  }

  void _ensureTicker() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    nowMs = DateTime.now().millisecondsSinceEpoch;
    final initialCount = pulses.length;
    if (initialCount > 0) {
      pulses.removeWhere((p) => (nowMs - p.startMs) >= p.durationMs);
    }

    final wasEmptied = initialCount > 0 && pulses.isEmpty;

    if (pulses.isEmpty) {
      _ticker.stop();
      if (wasEmptied) setState(() {});
    } else {
      notifyListeners();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isActiveUi = _nfcReady;
    final bgColor = isActiveUi ? Colors.black : Colors.transparent;
    final fgColor = isActiveUi^widget.toggle ? Colors.white : Colors.black;

    final rippleColor =
        isActiveUi^widget.toggle ? const Color.fromARGB(255, 228, 228, 228) : Colors.white;

    final decoration = BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(3),
      // border: isActiveUi ? null : Border.all(color: Colors.black, width: 1),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: GestureDetector(
        onTapDown: (d) {
          if (_nfcReady) _enqueueTriplePulse(d.localPosition);
        },
        onTap: _checkNfc,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _boxWidth),
          child: SizedBox(
            width: _boxWidth,
            height: _boxHeight,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              clipBehavior: Clip.antiAlias,
              decoration: decoration,
              child: Stack(
                children: [
                  if (pulses.isNotEmpty)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PulseQueuePainter(
                          state: this,
                          color: rippleColor,
                        ),
                      ),
                    ),
                  Center(
                    child: _checking
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.nfc, color: fgColor, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                _nfcReady ? 'NFC activo' : 'NFC inactivo',
                                style: TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 14,
                                    color: fgColor),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pulse {
  final Offset origin;
  final double baseAlpha;
  final int startMs;
  final int durationMs;
  _Pulse(
      {required this.origin,
      required this.baseAlpha,
      required this.startMs,
      required this.durationMs});
}

class _PulseQueuePainter extends CustomPainter {
  final _NfcActiveBarState state;
  final Color color;

  _PulseQueuePainter({
    required this.state,
    required this.color,
  }) : super(repaint: state);

  @override
  void paint(Canvas canvas, Size size) {
    final pulses = state.pulses;
    final nowMs = state.nowMs;

    if (size.isEmpty || pulses.isEmpty) return;

    for (final p in pulses) {
      final t = ((nowMs - p.startMs) / p.durationMs).clamp(0.0, 1.0);
      _drawOne(canvas, size, p.origin, t, p.baseAlpha);
    }
  }

  void _drawOne(
      Canvas canvas, Size size, Offset origin, double t, double baseAlpha) {
    if (t <= 0 || t >= 1) return;

    final farR = _farthestCornerDistance(size, origin);
    final r = _easeOut(t) * farR;

    final opacity = (t < 0.75)
        ? _easeIn((t / 0.4).clamp(0.0, 1.0)) * baseAlpha
        : (1.0 - _easeOut(((t - 0.75) / 0.25).clamp(0.0, 1.0))) * baseAlpha;

    if (opacity <= 0) return;

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(origin, r, paint);
  }

  double _easeIn(double x) => Curves.easeIn.transform(x.clamp(0.0, 1.0));
  double _easeOut(double x) => Curves.easeOut.transform(x.clamp(0.0, 1.0));

  double _farthestCornerDistance(Size s, Offset o) {
    final c1 = (o - const Offset(0, 0)).distance;
    final c2 = (o - Offset(s.width, 0)).distance;
    final c3 = (o - Offset(0, s.height)).distance;
    final c4 = (o - Offset(s.width, s.height)).distance;
    return math.max(math.max(c1, c2), math.max(c3, c4));
  }

  @override
  bool shouldRepaint(covariant _PulseQueuePainter old) {
    return true;
  }
}
