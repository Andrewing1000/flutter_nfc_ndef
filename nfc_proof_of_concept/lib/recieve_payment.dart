import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:nfc_proof_of_concept/nfc_active_bar.dart';
import 'package:nfc_proof_of_concept/qr_container.dart';
import './main.dart';

class RecievePaymentPage extends StatefulWidget {
  const RecievePaymentPage({super.key});

  @override
  State createState() {
    return RecievePaymentPageState();
  }
}

class RecievePaymentPageState extends State<RecievePaymentPage> {
  late TextEditingController control;
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if the widget is still in the tree before calling.
      if (mounted) {
        appLayoutKey.currentState?.showNotification(
            text: "QR creado exitosamente", icon: Icons.check);
      }
    });
    super.initState();
    control = TextEditingController(text: '0.0');
  }

  @override
  void dispose() {
    control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 1),
            const QRContainer(data: 'fadsfsdkanfkjasdnfsdafsdkjfnnasdkjfnasd'),
            const Spacer(flex: 1),
            NfcActiveBar(),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
