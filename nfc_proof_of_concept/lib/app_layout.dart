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
import 'package:nfc_proof_of_concept/services/app_launch_service.dart';

class AppLayout extends StatefulWidget {
  const AppLayout({super.key});

  @override
  State<AppLayout> createState() => AppLayoutState();
}

class AppLayoutState extends State<AppLayout> with TickerProviderStateMixin {
  NavigationController? _navigationController;
  bool _isInitialized = false;

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

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize launch service
    await AppLaunchService.instance.initialize();

    // Determine initial page based on launch type
    final AppPage initialPage =
        AppLaunchService.instance.launchedFromTechDiscovered
            ? AppPage.scanQr
            : AppPage.receivePayment;

    // Inicializar páginas persistentes
    _receivePaymentPage = const RecievePaymentPage();
    _scanQrPage = const ScanQrPage();

    _navigationController = NavigationController(initialPage: initialPage);
    _navigationController!.addListener(_onNavigationChanged);

    // Set up callback for TECH_DISCOVERED while app is running
    AppLaunchService.instance
        .setTechDiscoveredCallback(_handleTechDiscoveredWhileRunning);

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

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _onNavigationChanged() {
    setState(() {});
  }

  void _handleTechDiscoveredWhileRunning() {
    // When TECH_DISCOVERED is received while app is running, navigate to ScanQrPage
    if (mounted && _navigationController != null) {
      _navigationController!.initializeToScanQr();

      showNotification(
        text: "NFC detectado - Navegando a escaneo",
        icon: Icons.nfc,
      );
    }
  }

  @override
  void dispose() {
    _navigationController?.removeListener(_onNavigationChanged);
    _navigationController?.dispose();
    _notificationController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  // Métodos públicos para navegación
  void navigateToPaymentConfirmation(String paymentData) {
    if (_navigationController == null) return;

    // Crear nueva instancia de PaymentConfirmation solo si es necesario
    _paymentConfirmationPage =
        PaymentConfirmationPage(paymentData: paymentData);
    _navigationController!
        .navigateToPage(AppPage.paymentConfirmation, paymentData: paymentData);
  }

  // New method for navigating with complete NFC data
  void navigateToDataDisplay(Map<String, dynamic> ndefData) {
    if (_navigationController == null) return;

    // Create a formatted string representation of the complete data
    final dataString = _formatCompleteNdefData(ndefData);

    // Crear nueva instancia de PaymentConfirmation que mostrará todos los datos
    _paymentConfirmationPage = PaymentConfirmationPage(paymentData: dataString);
    _navigationController!
        .navigateToPage(AppPage.paymentConfirmation, paymentData: dataString);
  }

  // Helper method to format complete NDEF data for display
  String _formatCompleteNdefData(Map<String, dynamic> ndefData) {
    final buffer = StringBuffer();
    buffer.writeln('=== DATOS NFC RECIBIDOS ===\n');

    _formatMapRecursively(ndefData, buffer, 0);

    return buffer.toString();
  }

  void _formatMapRecursively(
      dynamic data, StringBuffer buffer, int indentLevel) {
    final indent = '  ' * indentLevel;

    if (data is Map<String, dynamic>) {
      for (final entry in data.entries) {
        buffer.write('$indent${entry.key}: ');
        if (entry.value is Map || entry.value is List) {
          buffer.writeln();
          _formatMapRecursively(entry.value, buffer, indentLevel + 1);
        } else {
          buffer.writeln('${entry.value}');
        }
      }
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        buffer.write('$indent[$i]: ');
        if (data[i] is Map || data[i] is List) {
          buffer.writeln();
          _formatMapRecursively(data[i], buffer, indentLevel + 1);
        } else {
          buffer.writeln('${data[i]}');
        }
      }
    } else {
      buffer.writeln('$indent$data');
    }
  }

  void goBack() {
    if (_navigationController == null) return;

    // Si volvemos desde PaymentConfirmation, limpiar la instancia
    if (_navigationController!.currentPage == AppPage.paymentConfirmation) {
      _paymentConfirmationPage = null;
    }
    _navigationController!.goBack();
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
    _navigationController?.navigateToTab(index);
  }

  Widget _getCurrentPage() {
    return IndexedStack(
      index: _getCurrentTabIndex(),
      children: [
        _receivePaymentPage, // índice 0
        _scanQrPage, // índice 1
      ],
    );
  }

  int _getCurrentTabIndex() {
    if (_navigationController == null) return 0;

    final currentPage = _navigationController!.currentPage;
    switch (currentPage) {
      case AppPage.receivePayment:
        return 0;
      case AppPage.scanQr:
        return 1;
      case AppPage.paymentConfirmation:
        // En confirmación de pago, mantener la última tab activa
        return _navigationController!.navigationStack.length > 1
            ? _getCurrentTabIndexFromPreviousPage()
            : 1;
    }
  }

  int _getCurrentTabIndexFromPreviousPage() {
    if (_navigationController == null ||
        _navigationController!.navigationStack.length < 2) return 1;
    final previousPage = _navigationController!
        .navigationStack[_navigationController!.navigationStack.length - 2];
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
    // Show loading screen while initializing
    if (!_isInitialized || _navigationController == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color.fromRGBO(219, 11, 0, 1),
          ),
        ),
      );
    }

    const Color bgRed = Color.fromRGBO(219, 11, 0, 1);
    const Color inactiveGreyText = Color.fromARGB(255, 163, 163, 163);

    final currentTabIndex = _getCurrentTabIndex();
    final showBackButton = _navigationController!.canGoBack;

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
            _navigationController!.getCurrentPageTitle(),
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
                  Color.fromARGB(255, 239, 235, 228),
                  Color.fromARGB(255, 197, 197, 197),
                ]),
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Stack principal con las páginas base (preserva estado)
              _getCurrentPage(),

              // Overlay para PaymentConfirmation si está activa
              if (_navigationController!.currentPage ==
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
