// In app_layout.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:nfc_proof_of_concept/bodered_bottom_navigation_bar.dart';
import 'package:nfc_proof_of_concept/notification_box.dart';
import 'package:nfc_proof_of_concept/recieve_payment.dart';
import 'package:nfc_proof_of_concept/scan_qr_page.dart';

class AppLayout extends StatefulWidget {
  const AppLayout({super.key});

  @override
  State<AppLayout> createState() => AppLayoutState();
}

class AppLayoutState extends State<AppLayout> with TickerProviderStateMixin {
  int _currIndex = 0;
  final List<String> labels = ["Pago QR", "Cobro QR"];
  final List<Widget> pages = [
    const RecievePaymentPage(),
    const ScanQrPage(),
  ];

  late AnimationController _notificationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _notificationTimer;

  String _notificationText = '';
  IconData _notificationIcon = Icons.info;

  @override
  void initState() {
    super.initState();
    _notificationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final slideTween = Tween<Offset>(
      begin: const Offset(1.1, 0.0),
      end: Offset.zero,
    );

    final fadeTween = Tween<double>(begin: 0.0, end: 1.0);

    _slideAnimation = _notificationController
        .drive(slideTween.chain(CurveTween(curve: Curves.easeOutCubic)));

    _fadeAnimation = _notificationController
        .drive(fadeTween.chain(CurveTween(curve: const Interval(0.25, 1.0))));
  }

  @override
  void dispose() {
    _notificationController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  void showNotification({required String text, required IconData icon}) {
    if (!mounted) return;
    _notificationTimer?.cancel();

    setState(() {
      _notificationText = text;
      _notificationIcon = icon;
    });

    _notificationController.forward(from: 0.0);

    _notificationTimer = Timer(const Duration(seconds: 4), () {
      _notificationController.reverse();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _currIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color bgRed = Colors.red;
    const Color inactiveGreyText = Color.fromARGB(255, 163, 163, 163);

    return Scaffold(
        appBar: AppBar(
          backgroundColor: bgRed,
          elevation: 2,
          leading:
              const Icon(CupertinoIcons.qrcode, color: Colors.white, size: 22),
          titleSpacing: 0,
          title: Text(labels[_currIndex],
              style: const TextStyle(
                  fontFamily: 'SpaceMono', color: Colors.white)),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight.add( const Alignment(2, 1)),
              colors: const [
              Color.fromARGB(255, 248, 244, 237),
              Color.fromARGB(255, 222, 222, 221),
            ]),
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              IndexedStack(
                index: _currIndex,
                children: pages,
              ),

              Positioned(
                top: 20,
                child: FadeTransition(
                  opacity: _fadeAnimation, 
                  child: SlideTransition(
                    position: _slideAnimation, 
                    child: NotificationBox(
                      icon: _notificationIcon,
                      text: _notificationText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BorderedBottomNav(
          itemCount: 2,
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            unselectedItemColor: inactiveGreyText,
            selectedItemColor: Colors.black,
            currentIndex: _currIndex,
            onTap: _onItemTapped,
            items: [
              BottomNavigationBarItem(
                  icon: const Icon(CupertinoIcons.qrcode, size: 24),
                  label: labels[0]),
              BottomNavigationBarItem(
                  icon: const Icon(CupertinoIcons.qrcode_viewfinder, size: 20),
                  label: labels[1])
            ],
            selectedLabelStyle: const TextStyle(fontFamily: 'SpaceMono'),
            unselectedLabelStyle: const TextStyle(fontFamily: 'SpaceMono'),
          ),
        ));
  }
}
