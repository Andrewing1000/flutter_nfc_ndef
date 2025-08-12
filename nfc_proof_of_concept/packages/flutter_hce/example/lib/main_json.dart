import 'package:flutter/material.dart';
import 'json_hce_widget.dart';

void main() {
  runApp(JsonHceApp());
}

class JsonHceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JSON NFC HCE Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: JsonHceWidget(),
      debugShowCheckedModeBanner: false,
    );
  }
}
