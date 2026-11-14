import 'package:flutter/material.dart';

import '../core/theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label});

  final String label;

  Color _color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (label.toUpperCase()) {
      'LOW' || 'ONLINE' || 'OFF' => FloraPalette.leaf,
      'MEDIUM' || 'WARNING' || 'MANUAL' => Colors.orange.shade700,
      'HIGH' || 'CRITICAL' || 'FAULT' => scheme.error,
      'TEST' => FloraPalette.water,
      'WAITING' => Colors.grey,
      _ => FloraPalette.leaf,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}
