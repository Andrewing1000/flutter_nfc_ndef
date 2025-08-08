import 'package:flutter/material.dart';

class NotificationBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const NotificationBox({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    const Color successBg = Colors.red;
    const Color successText = Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: successBg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Icon(
            icon,
            size: 20,
            color: successText,
          ),
          const SizedBox(
            width: 10,
          ),

          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                color: successText,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}