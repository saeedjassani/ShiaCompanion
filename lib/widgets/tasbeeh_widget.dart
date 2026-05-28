import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../utils/shared_preferences.dart';

class TasbeehWidget extends StatefulWidget {
  const TasbeehWidget({super.key});

  @override
  State<TasbeehWidget> createState() => _TasbeehWidgetState();
}

class _TasbeehWidgetState extends State<TasbeehWidget> {
  int counter = 0;
  bool isChecked = true;
  late final TextEditingController controller1;
  late final TextEditingController controller2;
  late final TextEditingController controller3;

  @override
  void initState() {
    super.initState();
    counter = SP.prefs.getInt('count') ?? 0;
    controller1 = TextEditingController(text: '34');
    controller2 = TextEditingController(text: '67');
    controller3 = TextEditingController(text: '100');
    trackScreen('Tasbeeh Page');
  }

  int? _parseMilestone(TextEditingController controller) {
    return int.tryParse(controller.text.trim());
  }

  void _incrementCounter() {
    final nextCount = counter + 1;
    final milestones = [
      _parseMilestone(controller1),
      _parseMilestone(controller2),
      _parseMilestone(controller3),
    ];

    if (isChecked && milestones.any((milestone) => milestone == nextCount)) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.mediumImpact();
    }

    setState(() {
      counter = nextCount;
    });
  }

  Widget _buildMilestoneField(
    BuildContext context,
    TextEditingController controller,
    String label,
  ) {
    return SizedBox(
      width: 92,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasbeeh Counter'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tap the counter circle to count. The beep will play at the milestones below.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isChecked,
                      onChanged: (value) {
                        setState(() {
                          isChecked = value;
                        });
                      },
                      title: const Text('Enable beep'),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildMilestoneField(context, controller1, 'Beep 1'),
                        _buildMilestoneField(context, controller2, 'Beep 2'),
                        _buildMilestoneField(context, controller3, 'Beep 3'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final circleSize = math.min(constraints.maxWidth, 340.0);

                  return Center(
                    child: GestureDetector(
                      onTap: _incrementCounter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: circleSize,
                        height: circleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primaryContainer,
                              colorScheme.secondaryContainer,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.18),
                              blurRadius: 30,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$counter',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tap to count',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: counter > 0
                        ? () {
                            setState(() {
                              counter--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove),
                    label: const Text('Minus one'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      setState(() {
                        counter = 0;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    SP.prefs.setInt('count', counter);
    controller1.dispose();
    controller2.dispose();
    controller3.dispose();
    super.dispose();
  }
}
