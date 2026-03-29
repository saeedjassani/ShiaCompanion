import 'package:flutter/material.dart';

class ZikrCounter extends StatelessWidget {
  final int count;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onReset;

  const ZikrCounter({
    super.key,
    required this.count,
    required this.onIncrement,
    required this.onDecrement,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Counter', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$count', style: Theme.of(context).textTheme.displayMedium),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: count > 0 ? onDecrement : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: onIncrement,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: onReset,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
