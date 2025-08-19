import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRContainer extends StatelessWidget {
  final String data;
  const QRContainer({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final subtleTextStyle = TextStyle(
      fontFamily: 'SpaceMono',
      fontSize: 12,
      color: Colors.grey[600],
      fontWeight: FontWeight.w200,
      height: 1.5, 
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400, minWidth: 200),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color:
              const Color.fromARGB(255, 252, 252, 252), 
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08), 
              blurRadius: 30,
              spreadRadius: -5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              clipBehavior: Clip.hardEdge,
              width: double.infinity,
              height: 80,
              decoration: const BoxDecoration(
                color: Color.fromRGBO(219, 11, 0, 1),
              ),
              child:  Align(
                  alignment: const Alignment(1, 1),
                  child: OverflowBox(
                    alignment: const Alignment(0, 0.8),
                    maxHeight: double.infinity,
                    maxWidth: double.infinity,
                    child: Image.asset(
                      'assets/icons/sazLogo.png',
                      height: 115,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                
            ),
            Container(
              padding:
                  const EdgeInsets.only(top: 15, left: 15, right: 15, bottom: 24),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        return QrImageView(
                          data: data,
                          version: QrVersions.auto,
                          size: constraints
                              .maxWidth,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  Column(
                    children: [
                      Text(
                        'Cta. 41232134234123',
                        style: subtleTextStyle,
                      ),
                      Text(
                        'Válido hasta: 8 de agosto de 2025',
                        style: subtleTextStyle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Opacity(
                    opacity: 0.6,
                    child: Image.asset(
                      'assets/icons/becLogo.png',
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
