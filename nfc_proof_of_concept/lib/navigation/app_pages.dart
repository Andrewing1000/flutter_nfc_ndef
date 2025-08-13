// lib/navigation/app_pages.dart

enum AppPage {
  receivePayment,
  scanQr,
  paymentConfirmation,
}

class AppPageData {
  final String title;
  final String? paymentData;

  const AppPageData({
    required this.title,
    this.paymentData,
  });
}

class AppPageConfig {
  static const Map<AppPage, AppPageData> _pageData = {
    AppPage.receivePayment: AppPageData(title: "Pago QR"),
    AppPage.scanQr: AppPageData(title: "Cobro QR"),
    AppPage.paymentConfirmation: AppPageData(title: "Confirmar Pago"),
  };

  static AppPageData getPageData(AppPage page) {
    return _pageData[page] ?? const AppPageData(title: "Página");
  }

  static AppPageData getPaymentConfirmationData(String paymentData) {
    return AppPageData(
      title: "Confirmar Pago",
      paymentData: paymentData,
    );
  }
}
