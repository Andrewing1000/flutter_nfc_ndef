import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:nfc_proof_of_concept/nfc_active_bar.dart';
import 'dart:typed_data';

import 'package:nfc_proof_of_concept/nfc_aid_helper.dart';
import 'package:crypto/crypto.dart';


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

  bool hashCheck = false;

  Map<String, dynamic>? data;
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

  void _checkData(Map<String, dynamic> data){
    this.data = data;

    dynamic digest = data["digest"];
    dynamic payload = data["payload"];

    if(digest == null || payload == null || digest is! String || payload is! String){
      setState(() {
        hashCheck = false;
      });
      return;
    }

    String afterDigest = sha256.convert(utf8.encode(payload)).toString();
    if(digest != afterDigest){
      setState((){
        hashCheck = false;
      });
      return;
    }

    setState(() {
      hashCheck = true;
    });
  }

  @override
  Widget build(BuildContext build) {
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
                  mode: NfcBarMode.readOnly,
                  onRead: _checkData,
              ),

              Visibility(
                  visible: data != null,
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                            if(data != null)
                              if(hashCheck) const Icon(Icons.check, size: 40, color: Colors.black,)
                              else const Icon(Icons.error_outline, size: 40, color: Colors.black),

                            Text(data?["digest"] ?? ""),
                            // Text((data?["payload"] ?? "" as String).substring(0, 30) ?? "")
                      ]
                    )

                  )
              )

            ],
          ),
        ),
      ),
    );
  }
}