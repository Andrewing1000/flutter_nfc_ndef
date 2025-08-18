import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hce/flutter_hce.dart';

void main() => runApp(const HceDemoApp());

class HceDemoApp extends StatefulWidget {
  const HceDemoApp({super.key});

  @override
  State<HceDemoApp> createState() => _HceDemoAppState();
}

class _HceDemoAppState extends State<HceDemoApp> {
  final _mgr = FlutterHceManager.instance;
  NfcState _nfcState = NfcState.unknown;
  bool _initializing = false;
  String _lastEvent = '—';

  @override
  void initState() {
    super.initState();
    _checkNfc();
  }

  Future<void> _checkNfc() async {
    final s = await _mgr.checkNfcState();
    if (!mounted) return;
    setState(() => _nfcState = s);
  }

  Future<void> _startHce() async {
    setState(() {
      _initializing = true;
      _lastEvent = 'starting…';
    });

    final aid = AidUtils.createStandardNdefAid();

    // Simple single-record NDEF message: Text("Hello from Flutter HCE")
    final records = <NdefRecordSerializer>[
      NdefRecordSerializer.text('Hello from Flutter HCE', 'en'),
    ];

    final ok = await _mgr.initialize(
      aid: aid,
      records: records,
      isWritable: false,
      maxNdefFileSize: 2048,
      onTransaction: (cmd, resp) {
        setState(() {
          final cla = cmd.cla.buffer[0];
          final ins = cmd.ins.buffer[0];
          _lastEvent =
              'APDU cmd ${cla.toRadixString(16).padLeft(2, '0').toUpperCase()}${ins.toRadixString(16).padLeft(2, '0').toUpperCase()}';
        });
      },
      onDeactivation: (reason) {
        setState(() {
          _lastEvent = 'Deactivated: ${reason.description}';
        });
      },
      onError: (err) {
        setState(() {
          _lastEvent = 'Error: ${err.message}';
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _initializing = false;
      _lastEvent = ok ? 'HCE ready' : 'Init failed';
    });
  }

  Future<void> _stopHce() async {
    await _mgr.stop();
    if (!mounted) return;
    setState(() => _lastEvent = 'stopped');
  }

  @override
  Widget build(BuildContext context) {
    final canStart =
        _nfcState == NfcState.enabled && !_mgr.isActive && !_initializing;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutter_hce example')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('NFC state: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_nfcState.description),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Text('HCE active: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_mgr.isActive ? 'yes' : 'no'),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Last event: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                    child: Text(_lastEvent, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 24),
              Wrap(spacing: 12, children: [
                ElevatedButton(
                  onPressed: canStart ? _startHce : null,
                  child: const Text('Start HCE'),
                ),
                ElevatedButton(
                  onPressed: _mgr.isActive ? _stopHce : null,
                  child: const Text('Stop HCE'),
                ),
                IconButton(
                  tooltip: 'Refresh NFC state',
                  onPressed: _checkNfc,
                  icon: const Icon(Icons.refresh),
                ),
              ]),
              const SizedBox(height: 16),
              const Text(
                  'Tip: use a second NFC-enabled phone to read the tag.'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
