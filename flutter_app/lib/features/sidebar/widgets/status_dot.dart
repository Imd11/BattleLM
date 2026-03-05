import 'package:flutter/material.dart';

class StatusDot extends StatelessWidget {
  final bool isOn;
  const StatusDot({super.key, required this.isOn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOn ? Colors.green : Colors.grey,
      ),
    );
  }
}

