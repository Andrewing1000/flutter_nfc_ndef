import 'package:flutter/material.dart';
import 'package:flutter_hce/flutter_hce.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _text = 'Calculando...';

  @override
  void initState() {
    super.initState();
    _runNativeSum();
  }

  Future<void> _runNativeSum() async {
    try {
      final res = await FlutterHce.addNative(5, 7);
      setState(() => _text = '5 + 7 (native) = $res');
    } catch (e) {
      setState(() => _text = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter HCE Example')),
        body: Center(child: Text(_text, style: const TextStyle(fontSize: 24))),
      ),
    );
  }
}
