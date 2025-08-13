// lib/payment_confirmation_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';

class PaymentConfirmationPage extends StatefulWidget {
  final String paymentData;

  const PaymentConfirmationPage({
    super.key,
    required this.paymentData,
  });

  @override
  State<PaymentConfirmationPage> createState() =>
      _PaymentConfirmationPageState();
}

class _PaymentConfirmationPageState extends State<PaymentConfirmationPage> {
  bool _isProcessing = false;
  Map<String, dynamic>? _parsedData;

  @override
  void initState() {
    super.initState();
    _parsePaymentData();
  }

  void _parsePaymentData() {
    try {
      if (widget.paymentData.startsWith('{') &&
          widget.paymentData.endsWith('}')) {
        _parsedData = json.decode(widget.paymentData) as Map<String, dynamic>;
      }
    } catch (e) {
      // Si no es JSON válido, tratarlo como texto plano
      _parsedData = {'message': widget.paymentData};
    }
  }

  void _processPayment() async {
    setState(() => _isProcessing = true);

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isProcessing = false);

      _showPaymentResult();
    }
  }

  void _showPaymentResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text(
                'Pago Exitoso',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: const Text(
            'El pago se ha procesado correctamente.',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar dialog
                Navigator.of(context).pop(); // Volver a ScanQrPage
              },
              child: const Text(
                'Aceptar',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _cancelPayment() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const Color bgRed = Colors.red;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgRed,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 22),
          onPressed: _cancelPayment,
        ),
        titleSpacing: 0,
        title: const Text(
          'Confirmar Pago',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 248, 244, 237),
              Color.fromARGB(255, 222, 222, 221),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Título principal
                const Text(
                  'Datos recibidos por NFC',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Card con datos del pago
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.nfc, color: Colors.red, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Información del Pago',
                            style: TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_parsedData != null)
                        ..._buildParsedDataWidgets()
                      else
                        _buildRawDataWidget(),
                    ],
                  ),
                ),

                const Spacer(),

                // Botones de acción
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: bgRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: _isProcessing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Procesando...',
                                    style: TextStyle(
                                      fontFamily: 'SpaceMono',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Confirmar Pago',
                                style: TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : _cancelPayment,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: bgRed,
                          side: const BorderSide(color: bgRed, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildParsedDataWidgets() {
    final widgets = <Widget>[];

    _parsedData!.forEach((key, value) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  '$key:',
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value.toString(),
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });

    return widgets;
  }

  Widget _buildRawDataWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 248, 244, 237),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        widget.paymentData,
        style: const TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 14,
          color: Colors.black54,
        ),
      ),
    );
  }
}
