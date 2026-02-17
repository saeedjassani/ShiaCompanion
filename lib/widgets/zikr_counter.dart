import 'package:flutter/material.dart';
// No persistent storage needed

class ZikrCounter extends StatefulWidget {
  final String zikrId;
  ZikrCounter({Key? key, required this.zikrId}) : super(key: key);

  @override
  State<ZikrCounter> createState() => _ZikrCounterState();
}

class _ZikrCounterState extends State<ZikrCounter> {
  int count = 0;

  void _resetCount() {
    setState(() {
      count = 0;
    });
  }

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
                  onPressed: count > 0
                      ? () {
                          setState(() {
                            count--;
                          });
                        }
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      count++;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _resetCount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
