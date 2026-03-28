import 'package:flutter/material.dart';

class DeepLinkNotFoundPage extends StatelessWidget {
  final String? target;

  const DeepLinkNotFoundPage({super.key, this.target});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Not Found'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_off,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'We couldn\'t find this shared content.',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (target != null && target!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Requested link: $target',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
