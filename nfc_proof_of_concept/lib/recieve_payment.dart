import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nfc_proof_of_concept/nfc_active_bar.dart';
import 'package:nfc_proof_of_concept/qr_container.dart';
import 'package:nfc_proof_of_concept/nfc_aid_helper.dart';
import './main.dart';

class RecievePaymentPage extends StatefulWidget {
  const RecievePaymentPage({super.key});

  @override
  State createState() {
    return RecievePaymentPageState();
  }
}

class RecievePaymentPageState extends State<RecievePaymentPage> {
  Uint8List? aid;
  bool isLoadingAid = true;

  @override
  void initState() {
    super.initState();
    _loadAid();
  }

  Future<void> _loadAid() async {
    try {
      final retrievedAid = await NfcAidHelper.getAidFromXml();
      setState(() {
        aid = retrievedAid;
        isLoadingAid = false;
      });

      if (mounted) {
        appLayoutKey.currentState?.showNotification(
            text: "QR creado exitosamente", icon: Icons.check);
      }
    } catch (e) {
      setState(() {
        isLoadingAid = false;
      });

      if (mounted) {
        appLayoutKey.currentState
            ?.showNotification(text: "Error al cargar AID", icon: Icons.error);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 1),
            const QRContainer(data: 'fadsfsdkanfkjasdnfsdafsdkjfnnasdkjfnasd'),
            const Spacer(flex: 1),
            if (isLoadingAid)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando configuración NFC...'),
                  ],
                ),
              )
            else if (aid != null)
              NfcActiveBar(
                broadcastData: 'fadsfsdkanfkjasdnfsdafsdkjfnnasdkjfnasd',
                mode: NfcBarMode.broadcastOnly,
                aid: aid!,
              )
            else
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(height: 8),
                    Text('Error al cargar configuración NFC'),
                  ],
                ),
              ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
