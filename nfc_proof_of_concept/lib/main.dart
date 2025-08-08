import 'package:flutter/material.dart';
import 'package:nfc_proof_of_concept/app_layout.dart';

final GlobalKey<AppLayoutState> appLayoutKey = GlobalKey<AppLayoutState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NFC Proof of Concept',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: AppLayout(key: appLayoutKey),
    );
  }
}