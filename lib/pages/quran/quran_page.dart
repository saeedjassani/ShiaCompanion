import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../data/universal_data.dart';
import '../../models/recitation_tracker_state.dart';
import '../../services/analytics_service.dart';
import '../../services/favorites_manager.dart';
import '../../services/recitation_tracker_manager.dart';
import '../../services/saved_verses_store.dart';
import '../../utils/quran_index.dart';
import '../../utils/quran_text_index.dart';
import '../../widgets/favorite_icon.dart';
import '../../widgets/responsive_content.dart';
import 'listen_and_follow_sheet.dart';
import 'quran_collections_tab.dart';
import 'quran_navigation.dart';
import 'recitation_tracker_tab.dart';

/// The Quran screen: your recitation tracks, a way to jump to any verse, the
/// two ways of browsing - by surah and by juz - and the collections (duas,
/// verses about Imam Ali (as), saved verses).
class QuranPage extends StatefulWidget {
  const QuranPage({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  List<SavedVerse> _saved = const [];
  late final List<SurahInfo> _surahs;
  late final List<Juz> _juz;
  bool _prewarmed = false;

  @override
  void initState() {
    super.initState();
    trackScreen('Quran Page');
    _surahs = allSurahs();
    _juz = allJuz();
    _saved = SavedVersesStore.instance.readAll();
    unawaited(RecitationTrackerManager.instance.loadRecitations());
  }

  /// Starts building the verse text index while the surah list is being read.
  ///
  /// Only for admins, since that is who can reach "Listen and follow" - nobody
  /// else should pay 114 document reads for a button they cannot see. Doing it
  /// here rather than on the tap moves the wait off the path between tapping the
  /// microphone and the microphone actually listening, which matters most on web
  /// where every document is a separate request.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prewarmed || !isUserAdmin) return;
    _prewarmed = true;
    prewarmQuranTextIndex(DefaultAssetBundle.of(context));
  }

  /// The kept verses can have moved while the reader was away, so they are
  /// re-read whenever the screen comes back.
  void _refresh() {
    _saved = SavedVersesStore.instance.readAll();
  }

  Future<void> _open(VerseKey verse,
      {String source = ZikrOpenSource.quran}) async {
    await openQuranVerse(context, verse, source: source);
    if (!mounted) return;
    setState(_refresh);
  }

  /// Listens to a recitation and opens the verse it turns out to be.
  ///
  /// Where the reader most recently was is handed to the matcher as context:
  /// someone following a recitation in al-Baqarah is most likely still in
  /// al-Baqarah, and a tie between two verses that read alike should break
  /// towards where they are. Deliberately not label-scoped - a recitation heard
  /// through the microphone belongs to whoever is reciting, not to a track.
  Future<void> _listenAndFollow() async {
    final verse = await showListenAndFollowSheet(
      context,
      readingAt: RecitationTrackerManager.instance.state.mostRecentPosition,
    );
    if (verse == null || !mounted) return;

    await _open(verse, source: ZikrOpenSource.quranListenAndFollow);
  }

  Future<void> _openJuz(int juz) async {
    await openQuranJuz(context, juz);
    if (!mounted) return;
    setState(_refresh);
  }

  Future<void> _removeSaved(SavedVerse saved) async {
    await SavedVersesStore.instance.remove(saved.verse);
    if (!mounted) return;
    setState(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quran'),
          actions: [
            // Dark-launched alongside the rest of the Quran reading experience
            // (see zikr_page.dart's _surahNumber and home_menu.dart), so the
            // microphone prompt reaches nobody until the matching is known to
            // be worth the interruption.
            if (isUserAdmin)
              IconButton(
                icon: const Icon(Icons.mic_none),
                tooltip: 'Listen and follow',
                onPressed: _listenAndFollow,
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Surahs'),
              Tab(text: 'Juz'),
              Tab(text: 'Collections'),
              Tab(text: 'Recitations'),
            ],
          ),
        ),
        body: Column(
          children: [
            ResponsiveContent(
              maxWidth: listContentWidth,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  const _RecitationLabelCards(),
                  const SizedBox(height: 8),
                  _GoToVerseField(onSubmit: _open),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SurahList(surahs: _surahs, onOpen: _open),
                  _JuzList(juz: _juz, onOpenJuz: _openJuz),
                  QuranCollectionsTab(
                    saved: _saved,
                    onOpenVerse: _open,
                    onRemoveSaved: _removeSaved,
                  ),
                  const RecitationTrackerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One resume card per recitation track, plus the reserved "Unlabeled"
/// bucket last and a card to start a new track.
///
/// This is what replaced the old single "Continue reciting" card: instead of
/// one global place to resume, every track keeps its own, since where you
/// left off reading with family and where you left off reading alone are not
/// the same place.
class _RecitationLabelCards extends StatelessWidget {
  const _RecitationLabelCards();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RecitationTrackerManager.instance,
      builder: (context, _) {
        final state = RecitationTrackerManager.instance.state;
        final labels = [...state.labels, unlabeledRecitationLabel];

        return SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: labels.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == labels.length) {
                return _AddTrackCard(onTap: () => _showAddLabelDialog(context));
              }
              return _LabelResumeCard(label: labels[index], state: state);
            },
          ),
        );
      },
    );
  }

  Future<void> _showAddLabelDialog(BuildContext context) async {
    final controller = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('New recitation track'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(hintText: 'e.g. Family, Tahajjud'),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Add'),
            ),
          ],
        ),
      );

      final trimmed = name?.trim() ?? '';
      if (trimmed.isEmpty) return;
      await RecitationTrackerManager.instance.addLabel(trimmed);
    } finally {
      controller.dispose();
    }
  }
}

class _LabelResumeCard extends StatelessWidget {
  const _LabelResumeCard({required this.label, required this.state});

  final String label;
  final RecitationTrackerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUnlabeled = label == unlabeledRecitationLabel;
    final resume = state.resumePositionFor(label);
    final percent = state.percentCompleteFor(label);
    final foreground = isUnlabeled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSecondaryContainer;
    final subtitle = resume == null
        ? 'Start reading'
        : '${surahInfoFor(resume.surah)?.englishName ?? "Surah ${resume.surah}"} '
            '${resume.ayah}';

    return SizedBox(
      width: 168,
      child: Card(
        margin: EdgeInsets.zero,
        color: isUnlabeled
            ? colorScheme.surfaceContainerLow
            : colorScheme.secondaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _resume(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isUnlabeled
                          ? Icons.menu_book_outlined
                          : Icons.play_circle_outline,
                      size: 18,
                      color: foreground,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: foreground.withValues(alpha: 0.85)),
                ),
                Text(
                  percent <= 0
                      ? ' '
                      : '${percent.toStringAsFixed(percent < 10 ? 1 : 0)}% of the Quran',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: foreground.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resume(BuildContext context) async {
    final resume = state.resumePositionFor(label);
    await openQuranVerse(
      context,
      resume ?? const VerseKey(1),
      source: ZikrOpenSource.quranResume,
      recitationLabel: label,
    );
  }
}

class _AddTrackCard extends StatelessWidget {
  const _AddTrackCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: 96,
      child: Card(
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: colorScheme.primary),
                const SizedBox(height: 4),
                Text(
                  'New track',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Jump straight to a verse by typing it, in whatever form comes to hand -
/// `23:56`, `23/56` or just `23`.
class _GoToVerseField extends StatefulWidget {
  const _GoToVerseField({required this.onSubmit});

  final void Function(VerseKey verse) onSubmit;

  @override
  State<_GoToVerseField> createState() => _GoToVerseFieldState();
}

class _GoToVerseFieldState extends State<_GoToVerseField> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final verse = VerseKey.tryParse(_controller.text);
    if (verse == null) {
      setState(() => _error = 'Try something like 23:56');
      return;
    }

    setState(() => _error = null);
    _controller.clear();
    FocusScope.of(context).unfocus();
    widget.onSubmit(verse);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search),
          hintText: 'Go to verse, e.g. 23:56',
          errorText: _error,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Go',
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}

class _SurahList extends StatelessWidget {
  const _SurahList({required this.surahs, required this.onOpen});

  final List<SurahInfo> surahs;
  final void Function(VerseKey verse) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveContent(
      maxWidth: listContentWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemCount: surahs.length,
        itemBuilder: (context, index) {
          final surah = surahs[index];
          // The same UniversalData shape the category lists build, so
          // favouriting a surah here is the same favourite as anywhere else.
          final itemData = UniversalData(
            surah.uid,
            items[surah.uid]?.toString() ?? surah.fullTitle,
            0,
          );

          return ListTile(
            leading: SizedBox(
              width: 32,
              child: Text(
                '${surah.number}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            // The Arabic name shares the title row rather than sitting in
            // `trailing`: some are long enough to consume the whole tile
            // width there, which ListTile treats as a layout error.
            title: Row(
              children: [
                Expanded(child: Text(surah.englishName)),
                if (surah.arabicName.isNotEmpty)
                  Flexible(
                    child: Text(
                      surah.arabicName,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: arabicFont,
                        fontFamilyFallback: const ['Qalam'],
                        fontSize: 18,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text('${surah.ayahCount} ayahs'),
            trailing: InkWell(
              onTap: () => FavoritesManager.instance.toggleFavorite(itemData),
              child: FavoriteIcon(favorite: itemData),
            ),
            onTap: () => onOpen(VerseKey(surah.number)),
          );
        },
      ),
    );
  }
}

class _JuzList extends StatelessWidget {
  const _JuzList({required this.juz, required this.onOpenJuz});

  final List<Juz> juz;
  final void Function(int juz) onOpenJuz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveContent(
      maxWidth: listContentWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemCount: juz.length,
        itemBuilder: (context, index) {
          final part = juz[index];
          return ListTile(
            leading: SizedBox(
              width: 32,
              child: Text(
                '${part.number}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            title: Text('Juz ${part.number}'),
            subtitle: Text(
              '${_verseLabel(part.start)} → ${_verseLabel(part.end)}',
            ),
            onTap: () => onOpenJuz(part.number),
          );
        },
      ),
    );
  }

  String _verseLabel(VerseKey verse) {
    final name =
        surahInfoFor(verse.surah)?.englishName ?? 'Surah ${verse.surah}';
    return '$name ${verse.ayah}';
  }
}
