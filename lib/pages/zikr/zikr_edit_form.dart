import 'package:flutter/material.dart';

class ZikrEditFormWidget extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController slugController;
  final TextEditingController codeController;
  final TextEditingController orderController;
  final TextEditingController dayController;
  final TextEditingController meritsController;
  final TextEditingController dataController;
  final List<TextEditingController> tabControllers;
  final VoidCallback onAddTab;

  const ZikrEditFormWidget({
    Key? key,
    required this.titleController,
    required this.slugController,
    required this.codeController,
    required this.orderController,
    required this.dayController,
    required this.meritsController,
    required this.dataController,
    required this.tabControllers,
    required this.onAddTab,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAddTab,
              icon: const Icon(Icons.add),
              label: const Text('Add Tab'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: slugController,
            decoration: const InputDecoration(
              labelText: 'Slug',
              helperText:
                  'Canonical URL path. Leave blank to auto-generate once; old slugs keep working.',
            ),
          ),
          TextField(
            controller: codeController,
            decoration: const InputDecoration(
              helperMaxLines: 3,
              helperText:
                  'Blank for Only Arabic, 0 for Arabic, 1 for transliteration, 2 for translation. Example: 012 will have Arabic, transliteration, and translation. 02 for Arabic and translation only',
              labelText: 'Code',
            ),
          ),
          TextField(
            controller: orderController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Order',
              helperText: 'Custom list order for this zikr',
            ),
          ),
          TextField(
            controller: dayController,
            decoration: const InputDecoration(
              helperMaxLines: 4,
              labelText: 'Lunar Date(s)',
              helperText:
                  'MM-DD for fixed dates (e.g., 09-09 for 9th Zilhajj), MM-*-D for a weekday within one lunar month '
                  '(e.g., 10-*-0 for every Sunday of Zilqad), or *-*-D for a weekday every month (e.g., *-*-5 for every Friday). '
                  'Separate multiple with commas.',
            ),
          ),
          TextField(
            controller: meritsController,
            decoration: const InputDecoration(labelText: 'Merits'),
            maxLines: null,
          ),
          TextField(
            controller: dataController,
            decoration: const InputDecoration(labelText: 'Data'),
            maxLines: null,
          ),
          for (int i = 0; i < tabControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextField(
                controller: tabControllers[i],
                decoration: InputDecoration(
                  labelText: 'Tab ${i + 1}',
                  helperText: 'First line becomes the tab title',
                ),
                maxLines: null,
              ),
            ),
        ],
      ),
    );
  }
}
