import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../data/uid_title_data.dart';
import '../../data/universal_data.dart';
import '../../services/analytics_service.dart';
import '../../services/favorites_manager.dart';
import '../../services/quran_progress_store.dart';
import '../../services/saved_verses_store.dart';
import '../../utils/quran_index.dart';
import '../../utils/quran_portion.dart';
import '../../widgets/favorite_icon.dart';
import '../../widgets/responsive_content.dart';
import '../zikr/zikr_page.dart';

/// Opens a surah, at a verse when one is named.
///
/// Every Quran entry point goes through here - the surah list, the juz list,
/// the go-to-verse box, the Continue card and the `/quran/...` links - so they
/// all open the same reader the same way, and a surah with no document yet
/// fails in one place rather than four.
Future<void> openQuranVerse(
  BuildContext context,
  VerseKey verse, {
  String source = ZikrOpenSource.quran,
}) async {
  final info = surahInfoFor(verse.surah);
  if (info == null) return;

  await pushPageRoute(
    context,
    ZikrPage(
      UidTitleData(info.uid, items[info.uid]?.toString() ?? info.fullTitle),
      source: source,
      initialVerse: verse,
    ),
  );
}

/// Opens a juz as one continuous reading, optionally at a verse inside it.
///
/// A juz is not a document in the corpus - 28 of the 30 run across two or more
/// surahs - so it is assembled first and then handed to the reader whole. That
/// is why this is async where [openQuranVerse] is not.
Future<void> openQuranJuz(
  BuildContext context,
  int juz, {
  VerseKey? at,
  String source = ZikrOpenSource.quran,
}) async {
  final portion = await loadJuzPortion(juz, DefaultAssetBundle.of(context));
  if (portion == null || portion.isEmpty || !context.mounted) return;

  await pushPageRoute(
    context,
    ZikrPage(
      UidTitleData(quranJuzUid(juz), portion.title),
      source: source,
      portion: portion,
      initialVerse: at,
    ),
  );
}

/// The Quran screen: where you left off, a way to jump to any verse, and the
/// two ways of browsing - by surah and by juz.
class QuranPage extends StatefulWidget {
  const QuranPage({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  QuranProgress? _progress;
  List<SavedVerse> _saved = const [];
  late final List<SurahInfo> _surahs;
  late final List<Juz> _juz;

  @override
  void initState() {
    super.initState();
    trackScreen('Quran Page');
    _surahs = allSurahs();
    _juz = allJuz();
    _progress = QuranProgressStore.instance.read();
    _saved = SavedVersesStore.instance.readAll();
  }

  /// Both the place and the kept verses can have moved while the reader was
  /// away, so they are re-read together whenever the screen comes back.
  void _refresh() {
    _progress = QuranProgressStore.instance.read();
    _saved = SavedVersesStore.instance.readAll();
  }

  Future<void> _open(VerseKey verse, {String source = ZikrOpenSource.quran}) async {
    await openQuranVerse(context, verse, source: source);
    if (!mounted) return;
    setState(_refresh);
  }

  /// Picks up where the reader left off - in the juz if that is where they
  /// were, since someone working through a juz over a week means the juz, not
  /// whichever surah they happened to stop inside.
  Future<void> _resumeReading() async {
    final progress = _progress;
    if (progress == null) return;

    final verse = VerseKey(progress.surah, progress.ayah);
    final juz = progress.juz;
    if (juz != null) {
      await openQuranJuz(
        context,
        juz,
        at: verse,
        source: ZikrOpenSource.quranResume,
      );
      if (!mounted) return;
      setState(_refresh);
      return;
    }

    await _open(verse, source: ZikrOpenSource.quranResume);
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

  Future<void> _clearProgress() async {
    await QuranProgressStore.instance.clear();
    if (!mounted) return;
    setState(() => _progress = null);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quran'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Surahs'),
              Tab(text: 'Juz'),
              Tab(text: 'Saved'),
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
                  if (_progress != null)
                    _ContinueRecitingCard(
                      progress: _progress!,
                      onTap: _resumeReading,
                      onDismiss: _clearProgress,
                    ),
                  _GoToVerseField(onSubmit: _open),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SurahList(surahs: _surahs, onOpen: _open),
                  _JuzList(juz: _juz, onOpenJuz: _openJuz),
                  _SavedVerseList(
                    saved: _saved,
                    onOpen: _open,
                    onRemove: _removeSaved,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Pick up where you left off." Only ever shown when sequential reading has
/// actually recorded a place - a verse someone merely looked up never lands
/// here. See [QuranProgressStore].
class _ContinueRecitingCard extends StatelessWidget {
  const _ContinueRecitingCard({
    required this.progress,
    required this.onTap,
    required this.onDismiss,
  });

  final QuranProgress progress;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = surahInfoFor(progress.surah);
    final name = info?.englishName ?? progress.surahTitle;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.secondaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.play_circle_outline,
          color: theme.colorScheme.onSecondaryContainer,
        ),
        title: Text(
          'Continue reciting',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        subtitle: Text(
          progress.juz == null
              ? '$name · ayah ${progress.ayah}'
              : 'Juz ${progress.juz} · $name ${progress.ayah}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Clear',
          color: theme.colorScheme.onSecondaryContainer,
          onPressed: onDismiss,
        ),
        onTap: onTap,
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
    final name = surahInfoFor(verse.surah)?.englishName ?? 'Surah ${verse.surah}';
    return '$name ${verse.ayah}';
  }
}

/// The verses the reader has kept.
///
/// In mushaf order rather than most-recent-first: this is a reference list
/// someone builds up and returns to, so it should read like an index of their
/// own Quran rather than a feed of recent activity.
class _SavedVerseList extends StatelessWidget {
  const _SavedVerseList({
    required this.saved,
    required this.onOpen,
    required this.onRemove,
  });

  final List<SavedVerse> saved;
  final void Function(VerseKey verse) onOpen;
  final void Function(SavedVerse saved) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (saved.isEmpty) {
      return ResponsiveContent(
        maxWidth: listContentWidth,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_outline,
                size: 40,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),
              Text(
                'No saved verses yet',
                style: theme.textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Tap a verse while reading to keep it here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ResponsiveContent(
      maxWidth: listContentWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemCount: saved.length,
        itemBuilder: (context, index) {
          final verse = saved[index];
          final name = verse.surahName.isNotEmpty
              ? verse.surahName
              : surahInfoFor(verse.surah)?.englishName ?? 'Surah ${verse.surah}';

          return ListTile(
            title: Text('$name ${verse.ayah}'),
            subtitle: verse.excerpt.isEmpty
                ? null
                : Text(
                    verse.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: arabicFont,
                      fontFamilyFallback: const ['Qalam'],
                      fontSize: 16,
                    ),
                  ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
              onPressed: () => onRemove(verse),
            ),
            onTap: () => onOpen(verse.verse),
          );
        },
      ),
    );
  }
}
