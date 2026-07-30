import 'package:flutter/material.dart';

import '../models/airport.dart';
import '../services/airport_repository.dart';
import '../utils/timezone_database.dart';
import '../widgets/responsive_content.dart';

/// Full-screen airport search. Pops with the chosen [Airport], or null.
class AirportPickerPage extends StatefulWidget {
  const AirportPickerPage({super.key, required this.title});

  final String title;

  @override
  State<AirportPickerPage> createState() => _AirportPickerPageState();
}

class _AirportPickerPageState extends State<AirportPickerPage> {
  final TextEditingController _controller = TextEditingController();
  final AirportRepository _repository = AirportRepository.instance;

  List<Airport> _results = const [];
  late bool _isLoading;

  @override
  void initState() {
    super.initState();
    _isLoading = !_repository.isLoaded;
    if (_isLoading) {
      _repository.load().then((_) {
        if (mounted) setState(() => _isLoading = false);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() => _results = _repository.search(query));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _controller.text.trim();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ResponsiveContent(
        maxWidth: compactContentWidth,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Airport code or city',
                hintText: 'e.g. SFO, Istanbul, Najaf',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults(theme, query)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme, String query) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (query.isEmpty) {
      return _Message(
        icon: Icons.flight_takeoff,
        title: 'Search for an airport',
        detail: 'Type an airport code, a city, or a country name.',
      );
    }

    if (_results.isEmpty) {
      return _Message(
        icon: Icons.search_off,
        title: 'No airports found',
        detail: 'Nothing matched "$query". Try the three letter code instead.',
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final airport = _results[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              airport.iata,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(airport.name),
          subtitle: Text(_subtitleFor(airport)),
          onTap: () => Navigator.pop(context, airport),
        );
      },
    );
  }

  /// The UTC offset is shown rather than the IANA identifier: the database
  /// stores canonical zone names, so an airport in Dar es Salaam would
  /// otherwise appear to be in Nairobi.
  static String _subtitleFor(Airport airport) {
    final location = tryGetLocation(airport.timeZoneId);
    if (location == null) return airport.locationLabel;
    return '${airport.locationLabel} · '
        '${utcOffsetLabel(location, DateTime.now())}';
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
