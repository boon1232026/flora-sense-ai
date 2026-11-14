import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.construction, size: 48),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(description, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
