import 'package:flutter/material.dart';

class BottomIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const BottomIcon({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
