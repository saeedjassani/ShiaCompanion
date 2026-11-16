import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../constants.dart';
import '../../l10n/l10n.dart';
import '../../models/islamic_center.dart';
import '../../services/analytics_service.dart';
import '../../services/content_request_service.dart';
import '../../services/islamic_center_service.dart';
import '../../theme/shia_colors.dart';
import '../../utils/geo_utils.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/choice_sheet.dart';
import '../../widgets/find_field.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/responsive_content.dart' show compactContentWidth;
import 'center_formatting.dart';

/// Choosing which centres to follow: the ones followed, then the directory
/// nearest first, and a way to add any centre by its calendar link.
class CenterDirectoryPage extends StatefulWidget {
  const CenterDirectoryPage({super.key, this.service});

  final IslamicCenterService? service;

  @override
  State<CenterDirectoryPage> createState() => _CenterDirectoryPageState();
}

class _CenterDirectoryPageState extends State<CenterDirectoryPage> {
  IslamicCenterService get _service =>
      widget.service ?? IslamicCenterService.instance;
  final TextEditingController _find = TextEditingController();

  @override
  void initState() {
    super.initState();
    trackScreen('Center Directory');
    _service.restore();
    unawaited(_service.loadDirectory());
    _find.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _find.dispose();
    super.dispose();
  }

  Future<void> _follow(IslamicCenter center, {String source = 'directory'}) {
    unawaited(
      AnalyticsService.feature(
        'center_followed',
        label: 'Center followed',
        parameters: {'source': source, 'custom': center.isCustom.toString()},
      ),
    );
    showToast(context.l10n.centerFollowing(center.name));
    return _service.follow(center);
  }

  Future<void> _unfollow(IslamicCenter center) async {
    final l10n = context.l10n;
    final confirmed = await showRevampDialog<bool>(
      context,
      title: l10n.centerUnfollowTitle(center.name),
      answers: [
        DialogAnswer(true, l10n.centerUnfollow, danger: true),
        DialogAnswer(false, l10n.commonCancel),
      ],
    );
    if (confirmed != true) return;
    unawaited(
      AnalyticsService.feature('center_unfollowed', label: 'Center unfollowed'),
    );
    await _service.unfollow(center.id);
  }

  Future<void> _addByLink() async {
    final draft = await showRevampSheet<_CenterDraft>(
      context,
      title: context.l10n.centerAddByLink,
      closeLabel: context.l10n.commonCancel,
      builder: (_) => const _AddByLinkForm(),
    );
    if (draft == null || !mounted) return;
    final center = IslamicCenterService.customCenter(
      name: draft.name,
      calendar: draft.calendar,
    );
    await _follow(center, source: 'link');
    if (draft.suggest) {
      unawaited(
        ContentRequestService.submit(
          type: ContentRequestType.center,
          title: center.name,
          details:
              'Calendar: ${center.calendar}'
              '${city == null ? '' : '\nNear: $city'}'
              '${lat == null || long == null ? '' : '\nAt: $lat, $long'}',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final gutter = pageGutter(context, maxWidth: compactContentWidth);
    final followed = _service.followed;
    final here = lat == null || long == null ? null : GeoPoint(lat!, long!);
    final query = _find.text.trim().toLowerCase();
    final rows = [
      for (final row in _service.centersByDistance(here))
        if (!_service.isFollowing(row.$1.id) &&
            (query.isEmpty ||
                row.$1.name.toLowerCase().contains(query) ||
                row.$1.city.toLowerCase().contains(query)))
          row,
    ];
    // Within reach first, under Near you; the rest under Centers. While
    // searching, one list.
    bool near((IslamicCenter, double?) row) =>
        query.isEmpty &&
        (row.$2 ?? double.infinity) <= IslamicCenterService.suggestionRadiusKm;
    final groups = [
      (
        l10n.centerNearbyLabel,
        [
          for (final r in rows)
            if (near(r)) r,
        ],
      ),
      (
        l10n.centerAllLabel,
        [
          for (final r in rows)
            if (!near(r)) r,
        ],
      ),
    ];

    Widget centerRow(
      IslamicCenter center,
      double? km, {
      required bool first,
      required bool last,
    }) {
      final following = _service.isFollowing(center.id);
      final details = [
        if (center.city.isNotEmpty) center.city,
        if (km != null) centerDistance(km, l10n),
      ].join(' · ');
      return CardListRow(
        first: first,
        last: last,
        title: Text(center.name),
        subtitle: details.isEmpty ? null : Text(details),
        trailing: following
            ? PageTextAction(
                label: l10n.centerUnfollow,
                semanticsLabel: l10n.centerUnfollowTitle(center.name),
                onPressed: () => _unfollow(center),
              )
            : PageTextAction(
                label: l10n.centerFollow,
                onPressed: () => _follow(center),
              ),
      );
    }

    final showFind = _service.directory.length > 8;

    return LargeTitlePage(
      title: l10n.centerDirectoryTitle,
      maxWidth: compactContentWidth,
      slivers: [
        if (followed.isNotEmpty) ...[
          SliverPadding(
            padding: gutter.copyWith(bottom: 8),
            sliver: SliverToBoxAdapter(
              child: GroupLabel(l10n.centerFollowingLabel),
            ),
          ),
          SliverPadding(
            padding: gutter,
            sliver: SliverCardList(
              itemCount: followed.length,
              itemBuilder: (context, i) {
                final center = followed[i];
                final km = here == null || center.point == null
                    ? null
                    : greatCircleDistanceKm(here, center.point!);
                return centerRow(
                  center,
                  km,
                  first: i == 0,
                  last: i == followed.length - 1,
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
        ],
        if (showFind)
          SliverPadding(
            padding: gutter.copyWith(bottom: 12),
            sliver: SliverToBoxAdapter(
              child: FindField(controller: _find, hint: l10n.centerFindHint),
            ),
          ),
        for (final (label, group) in groups)
          if (group.isNotEmpty) ...[
            SliverPadding(
              padding: gutter.copyWith(bottom: 8),
              sliver: SliverToBoxAdapter(child: GroupLabel(label)),
            ),
            SliverPadding(
              padding: gutter.copyWith(bottom: 18),
              sliver: SliverCardList(
                itemCount: group.length,
                itemBuilder: (context, i) => centerRow(
                  group[i].$1,
                  group[i].$2,
                  first: i == 0,
                  last: i == group.length - 1,
                ),
              ),
            ),
          ],
        if (rows.isEmpty && _service.directory.isEmpty)
          SliverPadding(
            padding: gutter,
            sliver: SliverToBoxAdapter(
              child: Text(
                l10n.centerDirectoryEmpty,
                style: ShiaText.secondary.copyWith(color: colors.textMuted),
              ),
            ),
          ),
        SliverPadding(
          padding: gutter.copyWith(top: 4, bottom: 8),
          sliver: SliverToBoxAdapter(
            child: GroupLabel(l10n.centerNotListedLabel),
          ),
        ),
        SliverPadding(
          padding: gutter,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.centerNotListedBody,
                  style: ShiaText.secondary.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 12),
                PageButton(
                  label: l10n.centerAddByLink,
                  glyph: OutlineGlyph.link,
                  onPressed: _addByLink,
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _CenterDraft {
  const _CenterDraft(this.name, this.calendar, this.suggest);

  final String name;
  final String calendar;
  final bool suggest;
}

/// The centre's name and its calendar link; checks the link is one the
/// app can read before letting it through.
class _AddByLinkForm extends StatefulWidget {
  const _AddByLinkForm();

  @override
  State<_AddByLinkForm> createState() => _AddByLinkFormState();
}

class _AddByLinkFormState extends State<_AddByLinkForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _link = TextEditingController();
  bool _suggest = true;
  bool _showError = false;

  @override
  void dispose() {
    _name.dispose();
    _link.dispose();
    super.dispose();
  }

  bool get _linkOk => calendarFeedUrl(_link.text) != null;

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    if (!_linkOk) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context)
        .pop(_CenterDraft(_name.text.trim(), _link.text.trim(), _suggest));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final fieldStyle = ShiaText.body.copyWith(color: colors.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.centerAddByLinkBody,
          style: ShiaText.secondary.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 120,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          style: fieldStyle,
          onChanged: (_) => setState(() {}),
          decoration: revampFieldDecoration(
            context,
            label: l10n.centerNameField,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _link,
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: fieldStyle,
          onChanged: (_) => setState(() => _showError = false),
          onSubmitted: (_) => _submit(),
          decoration: revampFieldDecoration(
            context,
            label: l10n.centerLinkField,
            helper: l10n.centerLinkHelp,
            error: _showError ? l10n.centerLinkInvalid : null,
          ),
        ),
        const SizedBox(height: 4),
        CardSwitchRow(
          label: l10n.centerSuggestToggle,
          value: _suggest,
          onChanged: (value) => setState(() => _suggest = value),
          last: true,
        ),
        const SizedBox(height: 12),
        PageButton(
          label: l10n.centerFollow,
          glyph: OutlineGlyph.plus,
          filled: true,
          onPressed: _name.text.trim().isEmpty || _link.text.trim().isEmpty
              ? null
              : _submit,
        ),
      ],
    );
  }
}
