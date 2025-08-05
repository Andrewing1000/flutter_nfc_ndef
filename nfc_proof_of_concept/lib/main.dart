import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  runApp(const BankingAppUI());
}

class BankingAppUI extends StatelessWidget {
  const BankingAppUI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cobro Digital',
      theme: ThemeData(
        fontFamily: 'IBMPlexSans',
        scaffoldBackgroundColor: const Color(0xFFF9F9F9), // A slightly off-white for a softer look
      ),
      home: const CoDiScreen(),
    );
  }
}

class CoDiScreen extends StatelessWidget {
  const CoDiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Define brand colors from the screenshot
    const Color santanderRed = Color(0xFFEC0000);
    const Color successGreenBg = Color(0xFFE8F5E9);
    const Color successGreenText = Color(0xFF2E7D32);
    const Color inactiveGreyBg = Color(0xFFEEEEEE);
    const Color inactiveGreyText = Color(0xFF757575);

    return Scaffold(
      // === APP BAR ===
      appBar: AppBar(
        backgroundColor: santanderRed,
        foregroundColor: Colors.white, // Sets icon and text color to white
        elevation: 2,
        leading: const Icon(Icons.qr_code), // Santander-like icon
        titleSpacing: 0,
        title: const Text("Za\$ Pago QR"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                // Action for hamburger menu
              },
            ),
          ),
        ],

      ),

      // === BODY ===
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // === QR CODE ===
              Container(
                padding: const EdgeInsets.all(8.0), // White border around QR
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: 'https://codi.org.mx/charge/123456789',
                  version: QrVersions.auto,
                  size: MediaQuery.of(context).size.width * 0.6, // Responsive size
                ),
              ),

              const Spacer(flex: 1),

              // === SUCCESS MESSAGE ===
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: successGreenBg,
                  borderRadius: BorderRadius.circular(20.0), // Pill shape
                ),
                child: const Text(
                  'Código QR generado exitosamente',
                  // Using a medium weight from the variable font for clarity
                  style: TextStyle(
                    color: successGreenText,
                    fontWeight: FontWeight.w500, // This works thanks to the Variable Font
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // === NFC STATUS (Secondary Font) ===
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                decoration: BoxDecoration(
                  color: Color.fromARGB(135, 129, 120, 92),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.nfc, color: Color.fromARGB(255, 255, 255, 255)),
                    const SizedBox(width: 12),
                    // Here we explicitly apply the secondary font "SpaceMono"
                    Text(
                      'NFC inactivo',
                      style: TextStyle(
                        fontFamily: 'SpaceMono', // Override the default font
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '100.00',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSans',
                      fontWeight: FontWeight.w500, // Selects SpaceMono-Bold.ttf
                      fontSize: 52,
                      color: Colors.black87,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'MXN',
                      // Using SpaceMono Regular for the currency
                      style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 20,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 3),
              const Padding(
                 padding: EdgeInsets.only(bottom: 20.0),
                 child: Icon(Icons.more_horiz, color: Colors.grey, size: 40),
              )
            ],
          ),
        ),
      ),
    );
  }
}