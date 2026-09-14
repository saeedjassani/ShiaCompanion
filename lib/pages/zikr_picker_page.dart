import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/uid_title_data.dart';
import '../utils/data_search_filter.dart';
import '../widgets/responsive_content.dart';

/// A simple search-and-pick list over the zikr library, used to prefill a
/// reminder's title from an existing zikr. Pops the picked [UidTitleData], or
/// null if the user backs out — it never navigates into the zikr itself, so
/// it can be reused anywhere a caller just wants a selection back.
class ZikrPickerPage extends StatefulWidget {
  const ZikrPickerPage({super.key});

  @override
  State<ZikrPickerPage> createState() => _ZikrPickerPageState();
}

class _ZikrPickerPageState extends State<ZikrPickerPage> {
  late final List<UidTitleData> _allZikr = items.entries
      .map((entry) => UidTitleData(entry.key, entry.value))
      .where((entry) => !entry.uid.contains('|'))
      .toList(growable: false)
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<UidTitleData> get _results {
    if (_query.trim().isEmpty) return _allZikr;
    return filterDataSearchResults(_allZikr, _query);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Zikr or Dua'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search zikr, dua, ziyarat...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      'No matches found.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ResponsiveContent(
                    maxWidth: listContentWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: results.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = results[index];
                        return ListTile(
                          title: Text(entry.title),
                          onTap: () => Navigator.pop(context, entry),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
