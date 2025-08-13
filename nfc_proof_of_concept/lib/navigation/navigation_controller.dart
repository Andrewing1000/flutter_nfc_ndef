// lib/navigation/navigation_controller.dart

import 'package:flutter/material.dart';
import 'app_pages.dart';

class NavigationController extends ChangeNotifier {
  final List<AppPage> _navigationStack = [AppPage.receivePayment];
  final Map<AppPage, String?> _pagePaymentData = {};

  List<AppPage> get navigationStack => List.unmodifiable(_navigationStack);
  AppPage get currentPage => _navigationStack.last;
  bool get canGoBack => _navigationStack.length > 1;

  // Constructor that allows setting initial page
  NavigationController({AppPage? initialPage}) {
    if (initialPage != null) {
      _navigationStack.clear();
      _navigationStack.add(initialPage);
    }
  }

  String? getPaymentDataForPage(AppPage page) {
    return _pagePaymentData[page];
  }

  void navigateToPage(AppPage page, {String? paymentData}) {
    _navigationStack.add(page);
    if (paymentData != null) {
      _pagePaymentData[page] = paymentData;
    }
    notifyListeners();
  }

  void goBack() {
    if (canGoBack) {
      final removedPage = _navigationStack.removeLast();
      _pagePaymentData.remove(removedPage);
      notifyListeners();
    }
  }

  void navigateToTab(int tabIndex) {
    // Limpiar stack y navegar a la tab correspondiente
    _navigationStack.clear();
    _pagePaymentData.clear();

    if (tabIndex == 0) {
      _navigationStack.add(AppPage.receivePayment);
    } else if (tabIndex == 1) {
      _navigationStack.add(AppPage.scanQr);
    }

    notifyListeners();
  }

  void initializeToScanQr() {
    // Método específico para inicializar directamente en ScanQrPage
    _navigationStack.clear();
    _pagePaymentData.clear();
    _navigationStack.add(AppPage.scanQr);
    notifyListeners();
  }

  void reset() {
    _navigationStack.clear();
    _pagePaymentData.clear();
    _navigationStack.add(AppPage.receivePayment);
    notifyListeners();
  }

  String getCurrentPageTitle() {
    final currentPageData = AppPageConfig.getPageData(currentPage);
    return currentPageData.title;
  }
}
