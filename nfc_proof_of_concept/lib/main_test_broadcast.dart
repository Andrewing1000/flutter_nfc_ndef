import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nfc_proof_of_concept/nfc_active_bar.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import 'package:nfc_proof_of_concept/nfc_aid_helper.dart';

void main(){
  runApp(TestLayout());
}

class TestLayout extends StatefulWidget{

  @override
  State<TestLayout> createState(){
    return TestLayoutState();
  }
}

class TestLayoutState extends State<TestLayout>{

  Uint8List? aid;

  @override
  void initState() {
    super.initState();
    _retrieveAid();
  }

  Future<void> _retrieveAid() async {
    var retrievedAid = await NfcAidHelper.getAidFromXml();
    setState((){
      aid = retrievedAid;
    });
  }

  String generatePayload({int length = 10240}){
      final r = Random.secure();
      final charData = List<int>.generate(length, (index) => r.nextInt(255));
      return String.fromCharCodes(charData);
  }

  @override
  Widget build(BuildContext build) {

    String payload = generatePayload();
    Map<String, dynamic> testMessage = {
      "digest": sha256.convert(utf8.encode(payload)).toString(),
      "payload": payload,
    };
    
    return MaterialApp(
      home: Scaffold(
        body: Container(
          padding: EdgeInsets.all(80),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if(aid != null) NfcActiveBar(
                  aid: aid!,
                  broadcastData: jsonEncode(testMessage),
                  mode: NfcBarMode.broadcastOnly,
              )
            ],
          ),
        ),
      ),
    );
  }
}