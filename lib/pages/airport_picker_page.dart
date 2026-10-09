import 'package:flutter/material.dart';

import '../models/airport.dart';
import '../services/airport_repository.dart';
import '../utils/timezone_database.dart';
import '../theme/shia_colors.dart';
import '../widgets/find_field.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/responsive_content.dart' show compactContentWidth;
import '../l10n/l10n.dart';

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
    _controller.addListener(_onQueryChanged);
    _isLoading = !_repository.isLoaded;
    if (_isLoading) {
      _repository.load().then((_) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _onQueryChanged();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() => _results = _repository.search(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _controller.text.trim();
    final gutter = pageGutter(context, maxWidth: compactContentWidth);

    final Widget body;
    if (_isLoading) {
      body = const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (query.isEmpty) {
      body = SliverToBoxAdapter(
        child: EmptyStateCard(
          glyph: OutlineGlyph.plane,
          title: l10n.airportSearchTitle,
          body: '${l10n.airportSearchDetail}\n${l10n.airportSearchHint}',
        ),
      );
    } else if (_results.isEmpty) {
      body = SliverToBoxAdapter(
        child: EmptyStateCard(
          glyph: OutlineGlyph.search,
          title: l10n.airportNoneFound,
          body: l10n.airportNothingMatched(query),
        ),
      );
    } else {
      body = SliverCardList(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final airport = _results[index];
          return CardListRow(
            first: index == 0,
            last: index == _results.length - 1,
            leading: _CodeWell(airport.iata),
            title: Text(airport.name),
            subtitle: Text(_subtitleFor(airport)),
            onTap: () => Navigator.pop(context, airport),
          );
        },
      );
    }

    return LargeTitlePage(
      title: widget.title,
      maxWidth: compactContentWidth,
      bottom: FindField(
        controller: _controller,
        hint: l10n.airportSearchLabel,
        autofocus: true,
      ),
      slivers: [SliverPadding(padding: gutter, sliver: body)],
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

/// The airport's three-letter code in a well, at the start of its row.
class _CodeWell extends StatelessWidget {
  const _CodeWell(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      width: 48,
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colors.well,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          code,
          maxLines: 1,
          style: ShiaText.secondary.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: colors.accent,
          ),
        ),
      ),
    );
  }
}
