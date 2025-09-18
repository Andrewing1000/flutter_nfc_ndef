import 'package:flutter/material.dart';
import 'package:nfc_proof_of_concept/nfc_active_bar.dart';
import 'dart:typed_data';

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

  String? data;
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
                  onRead: (data){
                    setState(() {
                      this.data = data.toString();
                    });
                  },
              ),

              if(data != null)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: const Alignment(0, 0),
                  child: Text(data!),
                )
            ],
          ),
        ),
      ),
    );
  }
}