import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../constants.dart';
import '../../models/islamic_center.dart';
import '../../services/islamic_center_service.dart';
import '../../utils/ics_calendar.dart';

/// The admin's editor for the Islamic centre directory
/// (`islamic_centers/directory`, docs/ISLAMIC_CENTERS.md): every centre
/// readers can follow, and the ones Home suggests to those nearby.
///
/// English only, like the other admin tools.
class CenterDirectoryAdminPage extends StatefulWidget {
  const CenterDirectoryAdminPage({super.key, this.service});

  final IslamicCenterService? service;

  @override
  State<CenterDirectoryAdminPage> createState() =>
      _CenterDirectoryAdminPageState();
}

class _CenterDirectoryAdminPageState extends State<CenterDirectoryAdminPage> {
  IslamicCenterService get _service =>
      widget.service ?? IslamicCenterService.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service.restore();
    unawaited(
      _service
          .loadDirectory(force: true)
          .whenComplete(
            () => mounted ? setState(() => _loading = false) : null,
          ),
    );
  }

  Future<void> _edit([IslamicCenter? center]) async {
    final result = await Navigator.of(context).push<_EditResult>(
      MaterialPageRoute(
        builder: (_) => _CenterEditor(center: center, service: _service),
      ),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.updateDirectory((current) {
        final others = [
          for (final c in current)
            if (c.id != (center?.id ?? result.center.id)) c,
        ];
        if (result.delete) return others;
        var saved = result.center;
        if (center == null) {
          saved = IslamicCenter(
            id: IslamicCenterService.newDirectoryId(
              saved.name,
              current.map((c) => c.id),
            ),
            name: saved.name,
            calendar: saved.calendar,
            city: saved.city,
            latitude: saved.latitude,
            longitude: saved.longitude,
            address: saved.address,
            website: saved.website,
          );
        }
        return [...others, saved];
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.delete ? 'Deleted' : 'Saved to the directory'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Centers Directory')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add center'),
      ),
      body: ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          final centers = _service.directory;
          if (_loading && centers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (centers.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No centers yet. Add one with its public Google Calendar: '
                'readers within 50 km of it are offered it on Home.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: centers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = centers[i];
              return ListTile(
                title: Text(c.name),
                subtitle: Text(
                  [
                    if (c.city.isNotEmpty) c.city,
                    if (c.point == null) 'no coordinates - never suggested',
                    if (c.feedUrl == null) 'calendar link not understood',
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _edit(c),
              );
            },
          );
        },
      ),
    );
  }
}

class _EditResult {
  const _EditResult(this.center, {this.delete = false});

  final IslamicCenter center;
  final bool delete;
}

class _CenterEditor extends StatefulWidget {
  const _CenterEditor({required this.center, required this.service});

  final IslamicCenter? center;
  final IslamicCenterService service;

  @override
  State<_CenterEditor> createState() => _CenterEditorState();
}

class _CenterEditorState extends State<_CenterEditor> {
  late final _name = TextEditingController(text: widget.center?.name);
  late final _city = TextEditingController(text: widget.center?.city);
  late final _calendar = TextEditingController(text: widget.center?.calendar);
  late final _coordinates = TextEditingController(
    text: widget.center?.point == null
        ? ''
        : '${widget.center!.latitude}, ${widget.center!.longitude}',
  );
  late final _address = TextEditingController(text: widget.center?.address);
  late final _website = TextEditingController(text: widget.center?.website);
  String? _testResult;
  bool _testing = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _city,
      _calendar,
      _coordinates,
      _address,
      _website,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// "29.7604, -95.3698" as Google Maps copies it.
  (double, double)? get _point {
    final parts = _coordinates.text.split(',');
    if (parts.length != 2) return null;
    final la = double.tryParse(parts[0].trim());
    final lo = double.tryParse(parts[1].trim());
    if (la == null || lo == null || la.abs() > 90 || lo.abs() > 180) {
      return null;
    }
    return (la, lo);
  }

  IslamicCenter _draft() {
    final point = _point;
    final website = _website.text.trim();
    return IslamicCenter(
      id: widget.center?.id ?? 'new',
      name: _name.text.trim(),
      calendar: _calendar.text.trim(),
      city: _city.text.trim(),
      latitude: point?.$1,
      longitude: point?.$2,
      address: _address.text.trim(),
      website: website.isEmpty ? null : website,
    );
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    String result;
    try {
      final events = await widget.service.loadEvents(_draft());
      final next = events.isEmpty ? null : events.first;
      result =
          '${events.length} programs in the next 60 days'
          '${next == null ? '' : '. Next: ${next.title}, '
                    '${next.localStart.toString().substring(0, 16)}'}';
    } on CenterFeedException catch (error) {
      result = switch (error.reason) {
        CenterFeedError.badLink => 'Not a calendar link or ID this reads.',
        CenterFeedError.notPublic =>
          'The calendar is not public. In Google Calendar: Settings > the '
              "calendar > Access permissions > tick 'Make available to "
              "public' (See all event details).",
        CenterFeedError.network => 'Could not reach the calendar.',
      };
    } on IcsFormatException {
      result = 'That address is not a calendar.';
    }
    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = result;
      });
    }
  }

  void _save() {
    final draft = _draft();
    if (draft.name.isEmpty || draft.feedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A name and a calendar link or ID are needed.'),
        ),
      );
      return;
    }
    if (_coordinates.text.trim().isNotEmpty && _point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coordinates should look like 29.7604, -95.3698'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(_EditResult(draft));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${widget.center!.name}?'),
        content: const Text(
          'Readers who follow it keep it; nobody new can find it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(_EditResult(widget.center!, delete: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget field(
      TextEditingController controller,
      String label, {
      String? helper,
      TextInputType? keyboard,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.center == null ? 'Add center' : 'Edit center'),
        actions: [
          if (widget.center != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field(_name, 'Name'),
          field(_city, 'City', helper: 'Shown under the name: "Houston, TX"'),
          field(
            _calendar,
            'Google Calendar ID or link',
            helper:
                'The calendar ID (Settings > the calendar > Integrate '
                'calendar), its public URL, or any .ics address. The '
                'calendar must be public.',
            keyboard: TextInputType.url,
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _testing ? null : _test,
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Test calendar'),
              ),
              const SizedBox(width: 12),
              if (_testing)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_testResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_testResult!),
            ),
          const SizedBox(height: 20),
          field(
            _coordinates,
            'Coordinates',
            helper:
                'Latitude, longitude - right-click the spot in Google '
                'Maps to copy them. Without them the center is never '
                'suggested on Home.',
          ),
          if (lat != null && long != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(
                  () => _coordinates.text =
                      '${lat!.toStringAsFixed(5)}, ${long!.toStringAsFixed(5)}',
                ),
                icon: const Icon(Icons.my_location),
                label: const Text("Use this phone's location"),
              ),
            ),
          const SizedBox(height: 8),
          field(_address, 'Address', helper: 'For directions'),
          field(_website, 'Website', keyboard: TextInputType.url),
        ],
      ),
    );
  }
}
