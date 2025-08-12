import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'services/nfc_service.dart';
import 'widgets/nfc_pulse_manager.dart';
import 'widgets/nfc_pulse_painter.dart';

// Re-export for backward compatibility
export 'services/nfc_service.dart' show NfcBarMode;

class NfcActiveBar extends StatefulWidget {
  final bool toggle;
  final bool clearText;
  final String broadcastData;
  final NfcBarMode mode;
  final Uint8List? aid; // Add AID parameter

  const NfcActiveBar({
    super.key,
    this.toggle = false,
    this.clearText = false,
    this.broadcastData = " ",
    this.mode = NfcBarMode.broadcastOnly,
    this.aid,
  });

  @override
  State<NfcActiveBar> createState() => _NfcActiveBarState();
}

class _NfcActiveBarState extends State<NfcActiveBar>
    with TickerProviderStateMixin {
  late final NfcService _nfcService;
  late final NfcPulseManager _pulseManager;

  static const double _boxWidth = 210;
  static const double _boxHeight = 38;

  @override
  void initState() {
    super.initState();
    _nfcService = NfcService();
    _pulseManager = NfcPulseManager();
    _pulseManager.initialize(this, getContainerSize: _getContainerSize);

    // Listen to both services
    _pulseManager.addListener(_onPulseUpdate);
    _nfcService.addListener(_onNfcServiceUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNfc());
  }

  Size _getContainerSize() {
    final box = context.findRenderObject() as RenderBox?;
    if (box?.hasSize == true) {
      return box!.size;
    }
    return const Size(_boxWidth, _boxHeight);
  }

  @override
  void dispose() {
    _pulseManager.removeListener(_onPulseUpdate);
    _nfcService.removeListener(_onNfcServiceUpdate);
    _pulseManager.dispose();
    _nfcService.dispose();
    super.dispose();
  }

  void _onPulseUpdate() {
    setState(() {});
  }

  void _onNfcServiceUpdate() {
    setState(() {});

    // React to transaction state changes by triggering pulses
    if (_nfcService.isTransactionActive) {
      final box = context.findRenderObject() as RenderBox?;
      if (box?.hasSize == true) {
        // Create a pulse at the center when a transaction occurs
        final center = Offset(box!.size.width / 2, box.size.height / 2);
        _pulseManager.addManualPulse(center, box.size);
      }
    }
  }

  Future<void> _checkNfc() async {
    final wasReady = await _nfcService.checkNfcState(
      broadcastData: widget.broadcastData,
      mode: widget.mode,
      aid: widget.aid,
    );

    if (!mounted) return;

    if (wasReady) {
      _pulseManager.startHeartbeat(true);
    } else {
      _pulseManager.stopHeartbeat();
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (_nfcService.isReady) {
      final box = context.findRenderObject() as RenderBox?;
      if (box?.hasSize == true) {
        _pulseManager.addManualPulse(details.localPosition, box!.size);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isActiveUi = _nfcService.isReady;
    final bool hasError = _nfcService.lastError != null;

    // Enhanced UI based on transaction state
    final bgColor = isActiveUi
        ? (_nfcService.isTransactionActive
            ? const Color.fromARGB(255, 40, 40, 40)
            : Colors.black)
        : Colors.transparent;

    final fgColor =
        (widget.clearText || isActiveUi) ? Colors.white : Colors.black;

    final rippleColor = (widget.clearText || isActiveUi ^ widget.toggle)
        ? (_nfcService.isTransactionActive ? Colors.greenAccent : Colors.white)
        : const Color.fromARGB(255, 146, 146, 146);

    final decoration = BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(3),
      border: hasError
          ? Border.all(color: Colors.red.withOpacity(0.5), width: 1)
          : null,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: GestureDetector(
        onTapDown: _onTapDown,
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
                  if (_pulseManager.isAnimating)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: NfcPulsePainter(
                          pulses: _pulseManager.pulses,
                          currentTimeMs: _pulseManager.currentTimeMs,
                          color: rippleColor,
                        ),
                      ),
                    ),
                  Center(
                    child: _nfcService.isChecking
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(fgColor),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.nfc,
                                  color: hasError ? Colors.red : fgColor,
                                  size: 18),
                              const SizedBox(width: 10),
                              Text(
                                _getStatusText(),
                                style: TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 14,
                                  color: hasError ? Colors.red : fgColor,
                                ),
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

  String _getStatusText() {
    if (_nfcService.lastError != null) {
      return 'Error NFC';
    } else if (_nfcService.isReady) {
      if (_nfcService.isTransactionActive) {
        return 'Transacción...';
      } else {
        final mode = _nfcService.currentMode == NfcBarMode.broadcastOnly
            ? 'HCE'
            : 'Lectura';
        return 'NFC $mode';
      }
    } else {
      return 'NFC inactivo';
    }
  }
}
