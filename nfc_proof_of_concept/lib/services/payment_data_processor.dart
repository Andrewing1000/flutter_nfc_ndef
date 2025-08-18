// lib/services/payment_data_processor.dart

import 'dart:convert';

/// Service for processing and validating NFC payment data
class PaymentDataProcessor {
  /// Checks if the given data contains payment-related fields
  static bool isPaymentData(Map<String, dynamic> data) {
    // Check for common payment fields
    const paymentFields = [
      'amount',
      'currency',
      'recipient',
      'payment',
      'transaction',
      'transfer',
      'money'
    ];

    return paymentFields.any((field) =>
        data.keys.any((key) => key.toString().toLowerCase().contains(field)));
  }

  /// Checks if a text string looks like payment data
  static bool isSimplePaymentString(String data) {
    // Check if string looks like payment data (contains currency symbols or payment keywords)
    final lowerData = data.toLowerCase();
    const indicators = [
      '\$',
      '€',
      '£',
      '¥',
      'usd',
      'eur',
      'pay',
      'amount',
      'transfer'
    ];

    return indicators.any((indicator) => lowerData.contains(indicator));
  }

  /// Formats payment data into a human-readable string
  static String formatPaymentData(Map<String, dynamic> paymentData) {
    // Create a clean, readable format for payment confirmation
    final buffer = StringBuffer();

    // Add amount if present
    final amount =
        paymentData['amount'] ?? paymentData['value'] ?? paymentData['money'];
    final currency = paymentData['currency'] ?? paymentData['curr'] ?? '\$';

    if (amount != null) {
      buffer.write('Monto: $currency$amount\n');
    }

    // Add recipient if present
    final recipient =
        paymentData['recipient'] ?? paymentData['to'] ?? paymentData['payee'];
    if (recipient != null) {
      buffer.write('Para: $recipient\n');
    }

    // Add concept/description if present
    final concept = paymentData['concept'] ??
        paymentData['description'] ??
        paymentData['memo'];
    if (concept != null) {
      buffer.write('Concepto: $concept\n');
    }

    // If no structured data, return JSON string
    if (buffer.isEmpty) {
      return json.encode(paymentData);
    }

    return buffer.toString().trim();
  }
}
