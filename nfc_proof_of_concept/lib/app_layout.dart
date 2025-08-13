// In app_layout.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:nfc_proof_of_concept/bodered_bottom_navigation_bar.dart';
import 'package:nfc_proof_of_concept/notification_box.dart';
import 'package:nfc_proof_of_concept/recieve_payment.dart';
import 'package:nfc_proof_of_concept/scan_qr_page.dart';
import 'package:nfc_proof_of_concept/payment_confirmation_page.dart';
import 'package:nfc_proof_of_concept/navigation/navigation_controller.dart';
import 'package:nfc_proof_of_concept/navigation/app_pages.dart';

class AppLayout extends StatefulWidget {
  const AppLayout({super.key});

  @override
  State<AppLayout> createState() => AppLayoutState();
}

class AppLayoutState extends State<AppLayout> with TickerProviderStateMixin {
  late NavigationController _navigationController;

  // Páginas persistentes para preservar estado
  late final RecievePaymentPage _receivePaymentPage;
  late final ScanQrPage _scanQrPage;
  PaymentConfirmationPage? _paymentConfirmationPage;

  late AnimationController _notificationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _notificationTimer;

  String _notificationText = '';
  IconData _notificationIcon = Icons.info;

  @override
  void initState() {
    super.initState();

    // Inicializar páginas persistentes
    _receivePaymentPage = const RecievePaymentPage();
    _scanQrPage = const ScanQrPage();

    _navigationController = NavigationController();
    _navigationController.addListener(_onNavigationChanged);

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

  void _onNavigationChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _navigationController.removeListener(_onNavigationChanged);
    _navigationController.dispose();
    _notificationController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  // Métodos públicos para navegación
  void navigateToPaymentConfirmation(String paymentData) {
    // Crear nueva instancia de PaymentConfirmation solo si es necesario
    _paymentConfirmationPage =
        PaymentConfirmationPage(paymentData: paymentData);
    _navigationController.navigateToPage(AppPage.paymentConfirmation,
        paymentData: paymentData);
  }

  void goBack() {
    // Si volvemos desde PaymentConfirmation, limpiar la instancia
    if (_navigationController.currentPage == AppPage.paymentConfirmation) {
      _paymentConfirmationPage = null;
    }
    _navigationController.goBack();
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
    _navigationController.navigateToTab(index);
  }

  Widget _getCurrentPage() {
    // Siempre mostrar el IndexedStack para preservar estado de páginas principales
    return IndexedStack(
      index: _getCurrentTabIndex(),
      children: [
        _receivePaymentPage, // índice 0
        _scanQrPage, // índice 1
      ],
    );
  }

  int _getCurrentTabIndex() {
    final currentPage = _navigationController.currentPage;
    switch (currentPage) {
      case AppPage.receivePayment:
        return 0;
      case AppPage.scanQr:
        return 1;
      case AppPage.paymentConfirmation:
        // En confirmación de pago, mantener la última tab activa
        return _navigationController.navigationStack.length > 1
            ? _getCurrentTabIndexFromPreviousPage()
            : 1;
    }
  }

  int _getCurrentTabIndexFromPreviousPage() {
    if (_navigationController.navigationStack.length < 2) return 1;
    final previousPage = _navigationController
        .navigationStack[_navigationController.navigationStack.length - 2];
    return previousPage == AppPage.receivePayment ? 0 : 1;
  }

  Widget _buildPaymentConfirmationOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: _paymentConfirmationPage ?? Container(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgRed = Colors.red;
    const Color inactiveGreyText = Color.fromARGB(255, 163, 163, 163);

    final currentTabIndex = _getCurrentTabIndex();
    final showBackButton = _navigationController.canGoBack;

    return Scaffold(
        appBar: AppBar(
          backgroundColor: bgRed,
          elevation: 2,
          leading: showBackButton
              ? IconButton(
                  icon: const Icon(CupertinoIcons.back,
                      color: Colors.white, size: 22),
                  onPressed: goBack,
                )
              : const Icon(CupertinoIcons.qrcode,
                  color: Colors.white, size: 22),
          titleSpacing: 0,
          title: Text(
            _navigationController.getCurrentPageTitle(),
            style:
                const TextStyle(fontFamily: 'SpaceMono', color: Colors.white),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight.add(const Alignment(2, 1)),
                colors: const [
                  Color.fromARGB(255, 248, 244, 237),
                  Color.fromARGB(255, 222, 222, 221),
                ]),
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Stack principal con las páginas base (preserva estado)
              _getCurrentPage(),

              // Overlay para PaymentConfirmation si está activa
              if (_navigationController.currentPage ==
                  AppPage.paymentConfirmation)
                _buildPaymentConfirmationOverlay(),

              // Notificaciones
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
            currentIndex: currentTabIndex,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.qrcode, size: 24),
                  label: "Pago QR"),
              BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.qrcode_viewfinder, size: 20),
                  label: "Cobro QR")
            ],
            selectedLabelStyle: const TextStyle(fontFamily: 'SpaceMono'),
            unselectedLabelStyle: const TextStyle(fontFamily: 'SpaceMono'),
          ),
        ));
  }
}
