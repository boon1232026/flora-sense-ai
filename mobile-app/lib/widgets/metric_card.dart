import 'package:flutter/material.dart';

import '../core/theme.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    this.icon,
    this.color,
    this.caption,
  });

  final String title;
  final String value;
  final String unit;
  final IconData? icon;
  final Color? color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? FloraPalette.leaf;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, accent.withValues(alpha: 0.08)],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: FloraPalette.leafDeep.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon ?? Icons.sensors, color: accent),
            ),
            const Spacer(),
            Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: const Color(0xFF6D8170))),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                text: value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: FloraPalette.leafDeep,
                      fontWeight: FontWeight.w900,
                    ),
                children: [
                  TextSpan(
                    text: ' $unit',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(caption!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
