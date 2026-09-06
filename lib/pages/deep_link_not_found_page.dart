import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

import '../constants.dart';

class DeepLinkNotFoundPage extends StatefulWidget {
  final String? target;

  const DeepLinkNotFoundPage({super.key, this.target});

  @override
  State<DeepLinkNotFoundPage> createState() => _DeepLinkNotFoundPageState();
}

class _DeepLinkNotFoundPageState extends State<DeepLinkNotFoundPage> {
  @override
  void initState() {
    super.initState();
    // A link landing here is itself the diagnostic signal — how often a
    // shared link or a home-widget tap fails to resolve — so the screen
    // count is the whole metric; no separate feature event needed.
    unawaited(trackScreen('Deep Link Not Found Page'));
  }

  String? get target => widget.target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Not Found'),
      ),
      body: ResponsiveContent(
        maxWidth: compactContentWidth,
        padding: const EdgeInsets.all(24.0),
        child: Center(
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
                'We couldn\'t find this content.',
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
