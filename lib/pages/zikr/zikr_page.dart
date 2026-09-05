import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/services/zikr_bookmark_store.dart';
import 'package:shia_companion/services/zikr_counter_session.dart';
import 'package:shia_companion/services/quran_progress_store.dart';
import 'package:shia_companion/services/saved_verses_store.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/quran_portion.dart';
import 'package:shia_companion/utils/external_launch.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/web_route_sync.dart';
import 'package:shia_companion/utils/zikr_wakelock.dart';
import 'package:shia_companion/models/zikr_audio_track.dart';
import '../../constants.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/zikr_action_bar.dart';
import '../../widgets/zikr_audio_player.dart';
import '../../widgets/zikr_reading_preferences.dart';
import '../../widgets/zikr_reading_progress_bar.dart';
import '../../widgets/zikr_settings.dart';
import '../../widgets/zikr_counter.dart';
import 'zikr_edit_form.dart';
import 'zikr_form_helpers.dart';
import 'zikr_content_parser.dart';
import 'zikr_content_viewer.dart';
import 'zikr_reading_stats.dart';
import 'zikr_share_image.dart';

enum _ZikrMenuAction { edit }

/// Whether a scroll notification from the reading content should hide, show,
/// or leave alone the reading chrome - the progress strip and the bottom
/// action bar, which move together. Null means no change - in particular,
/// horizontal scrolling (swiping between tabs) is not "scrolling the reading
/// area" and must not be read as a vertical reveal/hide signal.
///
/// Kept separate from [_ZikrPageState] and free of any Flutter scroll types
/// beyond [Axis]/[ScrollDirection] so it is trivial to unit test - building a
/// real [UserScrollNotification] needs a live [BuildContext].
bool? resolveChromeVisibilityForScroll(
  Axis axis,
  ScrollDirection direction,
) {
  if (axis != Axis.vertical) return null;
  return switch (direction) {
    ScrollDirection.reverse => false,
    ScrollDirection.forward => true,
    ScrollDirection.idle => null,
  };
}

/// Which verse a Quran reading should open at.
///
/// A destination only counts when it actually names an ayah: opening a surah
/// from the list passes its `VerseKey` with a null ayah, meaning "this surah"
/// rather than "the top of it".
///
/// Resuming is deliberately not part of this. Where someone left off is
/// [QuranProgressStore]'s job, surfaced by the Continue reciting card, and
/// saved verses are a collection to keep rather than a place to return to.
///
/// Pure and top-level, like [resolveChromeVisibilityForScroll], so the rule can
/// be tested without standing up a page.
VerseKey? resolveInitialVerse(VerseKey? requested) =>
    requested?.ayah != null ? requested : null;

class ZikrPage extends StatefulWidget {
  final UidTitleData item;
  final bool startEditing;

  /// Where the open came from, so the dashboard can say whether search, the
  /// home grid or a shared link is what actually brings people to a zikr.
  final String source;

  /// The verse to open at, when the reader arrived from a `/quran/23/56` link,
  /// the go-to-verse box, or a resumed recitation.
  ///
  /// A whole verse rather than an ayah number: a juz spans surahs, so "ayah 12"
  /// on its own would be ambiguous within one.
  final VerseKey? initialVerse;

  /// A juz to read instead of a single document.
  ///
  /// A juz is not a document in the corpus - it is several surahs stitched
  /// together by [loadJuzPortion]. Handing that here rather than building a
  /// second reader keeps audio, focus mode, fonts, progress and sharing.
  final QuranPortion? portion;

  ZikrPage(
    this.item, {
    this.startEditing = false,
    this.source = ZikrOpenSource.unknown,
    this.initialVerse,
    this.portion,
  });

  @override
  _ZikrPageState createState() => _ZikrPageState();
}

class _ZikrPageState extends State<ZikrPage> with RouteAware {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference zikrCollection =
      FirebaseFirestore.instance.collection('zikr');

  bool isAdmin = false;
  bool isEditing = false;
  bool _isSharingZikr = false;
  bool _isCurrentRoute = false;
  bool _didFailToLoadZikrData = false;
  int _selectedZikrTabIndex = 0;
  String? userId;
  Map<String, dynamic>? zikrData;
  TextEditingController? titleController;
  TextEditingController? slugController;
  TextEditingController? codeController;
  TextEditingController? dataController;
  TextEditingController? meritsController;
  TextEditingController? orderController;
  TextEditingController? dayController;
  final List<TextEditingController> tabControllers = [];
  PageRoute? _pageRoute;
  Uri? _previousBrowserUri;
  List<String> _slugAliases = const [];
  ZikrBookmark? _savedBookmark;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<int, double> _currentTabScrollOffsets = {};
  final Map<int, double> _currentTabMaxScrollExtents = {};

  /// The content line at the top of each tab's view, measured from the laid
  /// out list. This is what a bookmark records alongside the raw offset, so
  /// the marker is drawn on the very line the offset was read off.
  final Map<int, int> _currentTabTopLineIndexes = {};
  final ValueNotifier<double> _readingProgress = ValueNotifier<double>(0);
  bool _hasRecordedCompletion = false;
  DateTime? _openedAt;
  ZikrReadingStats _readingStats = ZikrReadingStats.empty;
  String? _readingStatsSignature;
  late final String _counterSessionId;
  late final ValueNotifier<Offset> _counterOffset;
  late final ValueNotifier<bool> _showCounter;
  late final ValueNotifier<int> _counterCount;

  /// Whether the reading chrome - the progress strip and the bottom action
  /// bar, which move as one - is on screen. Scroll direction is the primary
  /// signal - down hides it, up brings it back, and that alone is enough for
  /// anything long enough to actually scroll. An idle timer is only the
  /// fallback, for a zikr short enough that it never generates a scroll event
  /// to react to; see [_scheduleChromeIdleHide]. Both bars are overlays
  /// rather than something the text is padded around, so either way this
  /// only ever changes what is painted, never the text's layout.
  ///
  /// Only meaningful with Focus mode on. With it off, [_setChromeVisible] is
  /// the one place that enforces the chrome staying pinned - every writer
  /// below goes through it rather than each having to check the setting.
  final ValueNotifier<bool> _chromeVisible = ValueNotifier(true);

  /// Whether the bar is showing the player instead of the action row. Set by
  /// Listen, cleared by the player's close button. The player is only built
  /// while this is true, so audio costs nothing on a reading that never uses
  /// it — and closing it stops playback.
  bool _showAudioPlayer = false;

  /// Which surah this is, or null when the zikr is not one of the 114. Null is
  /// the ordinary case and keeps this page on its existing behaviour
  /// throughout — nothing below it does anything at all for a non-surah.
  int? _surahNumber;

  /// Verses the reader has kept, so the reader can mark them as they pass.
  Set<VerseKey> _savedVerses = const {};

  /// The verse at the top of the view right now, however the reader got there.
  /// Distinct from [_pendingProgressVerse], which only follows real scrolling
  /// because it feeds the saved recitation position.
  VerseKey? _currentVerse;

  /// That verse's text, so the bar can save an excerpt without the reader
  /// having had to open the per-verse menu.
  String _currentVerseText = '';

  /// The last verse reported as being read, so a debounced save has something
  /// to write and repeat reports of the same verse cost nothing.
  VerseKey? _pendingProgressVerse;
  Timer? _progressSaveTimer;

  @override
  void initState() {
    super.initState();
    // A portion spans surahs, so it has no single surah of its own; its index
    // carries one per verse instead.
    isAdmin = isUserAdmin && widget.portion == null;
    _surahNumber =
        widget.portion == null ? surahForUid(widget.item.getFirstUId()) : null;
    _counterSessionId = widget.item.getFirstUId();
    final counterState =
        ZikrCounterSessionStore.instance.read(_counterSessionId);
    _counterOffset = ValueNotifier(counterState.offset);
    _showCounter = ValueNotifier(counterState.isVisible);
    _counterCount = ValueNotifier(counterState.count);
    _loadSavedBookmark();
    _loadSavedVerses();
    if (widget.startEditing) {
      isEditing = true;
    }
    // The one place a zikr open is counted, so every entry point lands in the
    // same bucket exactly once.
    _openedAt = DateTime.now();
    unawaited(trackScreen('Zikr Page'));
    unawaited(AnalyticsService.zikrView(
      uid: widget.item.getUId(),
      title: widget.item.getTitle(),
      source: widget.source,
    ));
    _readingProgress.addListener(_maybeRecordCompletion);
    _initializePageData();
    _scheduleChromeIdleHide();
  }

  /// Fires at most once. Opening a zikr and reciting one are different things
  /// and the dashboard should not conflate them.
  ///
  /// Scroll position alone is not enough: [zikrTabScrollFraction] treats a zikr
  /// too short to scroll as fully read the moment it lays out, so a stray tap
  /// on a two-line dua would outrank a real recitation. Time on the page,
  /// scaled to how long the text actually takes to recite, is the second half
  /// of the signal.
  void _maybeRecordCompletion() {
    if (_hasRecordedCompletion) return;
    if (_readingProgress.value < 0.98) return;

    final openedAt = _openedAt;
    if (openedAt == null) return;
    final estimatedSeconds = _readingStats.duration.inSeconds;
    final requiredSeconds = math.max(10, estimatedSeconds ~/ 2);
    if (DateTime.now().difference(openedAt).inSeconds < requiredSeconds) return;

    _hasRecordedCompletion = true;
    unawaited(AnalyticsService.zikrCompleted(
      uid: widget.item.getUId(),
      title: widget.item.getTitle(),
    ));
  }

  /// Records the reader's place in their recitation - but only once they have
  /// actually been reading.
  ///
  /// Arriving at 23:56 from a link or the go-to-verse box reports the position
  /// too, with [QuranReadingPosition.fromUserScroll] false, and that case is
  /// dropped here: a lookup should never cost someone the place they had
  /// reached. Scrolling on from there does count, which is what makes a lookup
  /// that turns into real reading become the new place on its own.
  void _handleAyahPositionChanged(QuranReadingPosition position) {
    _currentVerse = position.verse;
    _currentVerseText = position.text;
    if (!position.fromUserScroll) return;
    if (position.verse == _pendingProgressVerse) return;

    _pendingProgressVerse = position.verse;
    // Scrolling reports continuously; a save per frame would be pointless
    // churn, so wait for the reader to settle.
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer(const Duration(seconds: 1), _flushReadingProgress);
  }

  /// Writes the pending position out.
  ///
  /// Also called from [dispose], because leaving the page is the most likely
  /// moment for a debounced write to still be waiting - closing a surah right
  /// after reading a verse is the ordinary way to finish, and losing that last
  /// move is exactly the place someone would notice.
  void _flushReadingProgress() {
    final verse = _pendingProgressVerse;
    final ayah = verse?.ayah;
    if (verse == null || ayah == null) return;

    _pendingProgressVerse = null;
    unawaited(
      QuranProgressStore.instance.save(
        QuranProgress(
          surah: verse.surah,
          ayah: ayah,
          // The surah's own name, not the page title, which in a juz is
          // "Juz 5" and would make the Continue card say the wrong thing.
          surahTitle: surahInfoFor(verse.surah)?.fullTitle ??
              widget.item.getTitle(),
          // Recorded so someone working through a juz over a week comes back
          // to the juz rather than to a lone surah.
          juz: widget.portion?.juz,
          updatedAt: DateTime.now().toUtc(),
        ),
      ),
    );
  }

  /// The per-ayah menu: what you can do with one verse rather than the whole
  /// surah, which is all the action bar has ever offered.
  Future<void> _showAyahActions(AyahActionRequest request) async {
    final verse = request.verse;
    final ayah = verse.ayah;
    if (ayah == null) return;

    final text = request.text;
    // Always the verse's own surah, which in a juz is not the page's subject.
    final surah = verse.surah;
    final surahTitle = surahInfoFor(surah)?.fullTitle ?? widget.item.getTitle();
    final link = buildQuranDeepLinkUrl(surah: surah, ayah: ayah);
    final isSaved = _savedVerses.contains(verse);

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: Text(
                '$surahTitle · $verse',
                style: Theme.of(sheetContext).textTheme.labelLarge,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy verse'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Clipboard.setData(ClipboardData(text: text));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied $verse')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy link'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Clipboard.setData(ClipboardData(text: link));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share verse'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(
                  SharePlus.instance.share(ShareParams(text: '$text\n\n$link')),
                );
              },
            ),
            ListTile(
              leading: Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_outline,
              ),
              title: Text(isSaved ? 'Remove from saved' : 'Save verse'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(_toggleSavedVerse(verse, text));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Bookmarks one verse, against the surah that verse belongs to.
  ///
  /// Deliberately not against whatever is open: reading juz 5 and bookmarking
  /// 5:12 marks al-Ma'idah, so opening al-Ma'idah directly finds it too. There
  /// is still one bookmark per surah and it is still a [ZikrBookmark] - what
  /// makes this possible is that the bookmark now carries the ayah, which is
  /// meaningful in both the juz and the surah, where a scroll offset measured
  /// inside a juz would be meaningless in the surah's own document.
  /// Keeps [verse], or lets it go if it was already kept.
  ///
  /// A collection rather than a marker: saving a second verse of a surah does
  /// not displace the first, which is exactly what a [ZikrBookmark] would have
  /// done. Where the reader left off is tracked separately, by
  /// [QuranProgressStore].
  Future<void> _toggleSavedVerse(VerseKey verse, String text) async {
    final ayah = verse.ayah;
    if (ayah == null) return;

    final store = SavedVersesStore.instance;
    final wasSaved = _savedVerses.contains(verse);

    if (wasSaved) {
      await store.remove(verse);
    } else {
      await store.add(
        SavedVerse(
          surah: verse.surah,
          ayah: ayah,
          surahName: surahInfoFor(verse.surah)?.englishName ?? '',
          // The first line of the verse as the reader sees it, kept so the
          // saved list can be read without loading a surah document per row.
          excerpt: _excerptOf(text),
          savedAt: DateTime.now().toUtc(),
        ),
      );
    }

    if (!mounted) return;
    setState(_loadSavedVerses);
    unawaited(AnalyticsService.feature(
      wasSaved ? 'quran_verse_unsaved' : 'quran_verse_saved',
      label: wasSaved ? 'Quran verse unsaved' : 'Quran verse saved',
      parameters: {'verse': verse.toString()},
    ));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(wasSaved ? 'Removed $verse' : 'Saved $verse')),
    );
  }

  /// The opening of a verse, for the saved list.
  static String _excerptOf(String text) {
    final first = text
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    return first.length <= 90 ? first : '${first.substring(0, 90)}…';
  }

  @override
  void dispose() {
    _progressSaveTimer?.cancel();
    _flushReadingProgress();
    if (_pageRoute != null) {
      routeObserver.unsubscribe(this);
    }
    titleController?.dispose();
    slugController?.dispose();
    codeController?.dispose();
    dataController?.dispose();
    meritsController?.dispose();
    orderController?.dispose();
    dayController?.dispose();
    for (final controller in tabControllers) {
      controller.dispose();
    }
    _counterOffset.dispose();
    _showCounter.dispose();
    _counterCount.dispose();
    _chromeIdleTimer?.cancel();
    _chromeVisible.dispose();
    _maybeRecordCompletion();
    _readingProgress.removeListener(_maybeRecordCompletion);
    _readingProgress.dispose();
    syncZikrWakelockPreference(owner: this, isActive: false);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _pageRoute) {
      if (_pageRoute != null) {
        routeObserver.unsubscribe(this);
      }
      _pageRoute = route;
      routeObserver.subscribe(this, route);
    }
  }

  String get _bookmarkUid => widget.item.getFirstUId();

  /// The verse to open at, once for this page.
  ///
  /// Only meaningful for a surah - an ayah number means nothing in a dua, and
  /// passing one through would put the viewer into ayah mode for a document
  /// that has no ayahs.
  VerseKey? get _initialVerse =>
      _isQuran ? resolveInitialVerse(widget.initialVerse) : null;

  /// Whether what is open is Quran at all - one surah, or a juz spanning
  /// several. False for every other zikr, which is what keeps them on the
  /// unchanged rendering and reporting paths.
  bool get _isQuran => _surahNumber != null || widget.portion != null;

  void _loadSavedVerses() {
    if (!_isQuran) return;
    _savedVerses = {
      for (final saved in SavedVersesStore.instance.readAll()) saved.verse,
    };
  }

  void _loadSavedBookmark() {
    // A portion is not a document bookmarks can be stored against.
    if (widget.portion != null) return;

    final bookmark = ZikrBookmarkStore.instance.read(_bookmarkUid);
    if (bookmark == null) return;

    _savedBookmark = bookmark;

    // An explicit destination wins over restoring the bookmark's position:
    // someone opening 23:56 asked for that verse, not for wherever they last
    // bookmarked this surah. The bookmark itself is kept, and still drawn.
    //
    // A verse-anchored bookmark is skipped here too, for a different reason:
    // it is restored by scrolling to its verse instead, which is exact, and
    // letting the offset restore as well would only fight it.
    if (_initialVerse != null) return;

    _selectedZikrTabIndex = bookmark.tabIndex;
    _currentTabScrollOffsets[bookmark.tabIndex] = bookmark.scrollOffset;
  }

  void _persistCounterSession({
    int? count,
    bool? isVisible,
    Offset? offset,
  }) {
    final nextState =
        ZikrCounterSessionStore.instance.read(_counterSessionId).copyWith(
              count: count ?? _counterCount.value,
              isVisible: isVisible ?? _showCounter.value,
              offset: offset ?? _counterOffset.value,
            );
    ZikrCounterSessionStore.instance.write(_counterSessionId, nextState);
  }

  void _setCounterVisibility(bool isVisible) {
    _showCounter.value = isVisible;
    _persistCounterSession(isVisible: isVisible);
  }

  void _toggleCounterFromActionBar() {
    if (_showCounter.value) {
      _setCounterVisibility(false);
      return;
    }
    unawaited(AnalyticsService.feature(
      'zikr_counter_shown',
      label: 'Tasbeeh counter shown',
    ));
    _setCounterVisibility(true);
  }

  void _openAudioPlayer() {
    unawaited(AnalyticsService.feature(
      'zikr_audio_opened',
      label: 'Zikr audio opened',
      parameters: {'zikr_uid': widget.item.getUId()},
    ));
    setState(() => _showAudioPlayer = true);
    // Reading down the page hides the chrome; opening the player has to
    // bring it back or the reader taps Listen and sees nothing happen. Always
    // allowed regardless of Focus mode - true is never a hide request, so it
    // needs no guard.
    _chromeVisible.value = true;
    _chromeIdleTimer?.cancel();
  }

  void _closeAudioPlayer() {
    setState(() => _showAudioPlayer = false);
    _scheduleChromeIdleHide();
  }

  /// Whether Focus mode is on - the reading chrome is only ever eligible to
  /// hide when it is. Read live rather than cached: it is an in-memory prefs
  /// read, and a cached copy would need re-syncing from the drawer, the
  /// global settings page, and [didPopNext].
  bool get _focusModeEnabled => zikrFocusModeEnabled();

  /// The one place the chrome is hidden. With Focus mode off the chrome is
  /// pinned, so a hide request from the scroll handler or the idle timer is
  /// dropped here rather than having to be caught at every call site.
  void _setChromeVisible(bool visible) {
    if (!visible && !_focusModeEnabled) return;
    _chromeVisible.value = visible;
  }

  /// Slides the chrome away as the reader moves down the text and back when
  /// they scroll up. Held open while the player is showing: hiding transport
  /// controls part-way through a half-hour recitation would strand them.
  ///
  /// The reading content is a [ListView] nested inside the tab [PageView], so
  /// its scroll notifications arrive here having already bubbled past the
  /// PageView - which, being itself a [Scrollable], bumps [depth] to 1 on the
  /// way through. Gating on `depth == 0` (as the counter FAB's old idle timer
  /// effectively assumed nothing nested) discarded every one of them, so the
  /// chrome never moved on a real read. Gating on axis instead of depth reads
  /// correctly regardless of nesting, and as a side effect also ignores the
  /// PageView's own horizontal swipes between tabs, whose forward/reverse
  /// would otherwise mean left/right rather than up/down.
  bool _handleScrollNotification(UserScrollNotification notification) {
    if (_showAudioPlayer || !_focusModeEnabled) return false;

    final visible = resolveChromeVisibilityForScroll(
      notification.metrics.axis,
      notification.direction,
    );
    if (visible != null) {
      _setChromeVisible(visible);
      // A deliberate scroll signal always wins; the idle fallback is only
      // for the short zikr that never generates one at all.
      _chromeIdleTimer?.cancel();
      if (visible) _scheduleChromeIdleHide();
    }
    return false;
  }

  /// Brings the chrome back and restarts the idle clock - called on any tap
  /// on the page, not just on either bar itself, so a reader is never left
  /// having to guess where to tap to get it back.
  void _revealChrome() {
    _setChromeVisible(true);
    _scheduleChromeIdleHide();
  }

  /// Fallback for a zikr short enough that it never scrolls, so the chrome
  /// would otherwise sit over the text for the entire visit. Longer than the
  /// old counter FAB's 4s: the FAB was a rarely-needed extra, but the action
  /// bar holds Bookmark and Share, which a reader is more likely to want
  /// mid-thought, and a shorter fallback would fight normal pauses in
  /// reading.
  static const Duration _chromeIdleDuration = Duration(seconds: 8);
  Timer? _chromeIdleTimer;

  void _scheduleChromeIdleHide() {
    if (!_focusModeEnabled) return;
    _chromeIdleTimer?.cancel();
    _chromeIdleTimer = Timer(_chromeIdleDuration, () {
      // Re-checked here, not just at scheduling time: the setting can change
      // while this timer is already in flight.
      if (mounted && !_showAudioPlayer && _focusModeEnabled) {
        _setChromeVisible(false);
      }
    });
  }

  /// Called when the reading settings change. Turning Focus mode off has to
  /// pin the chrome back open immediately - the reader just asked for it,
  /// and with no scroll or tap to follow, the pin would otherwise not take
  /// effect until something happened to write the notifier.
  void _applyFocusModePreference() {
    if (_focusModeEnabled) {
      _scheduleChromeIdleHide();
    } else {
      _chromeIdleTimer?.cancel();
      _chromeVisible.value = true; // direct write: _setChromeVisible only
      // ever filters out a hide, and true always needs to go through.
    }
  }

  void _updateCounterOffset(Offset offset) {
    _counterOffset.value = offset;
    _persistCounterSession(offset: offset);
  }

  void _setCounterCount(int count) {
    _counterCount.value = count;
    _persistCounterSession(count: count);
  }

  Widget _buildCounterCard() {
    return ValueListenableBuilder<int>(
      valueListenable: _counterCount,
      builder: (context, count, _) => ZikrCounter(
        count: count,
        onIncrement: () => _setCounterCount(count + 1),
        onDecrement: count > 0 ? () => _setCounterCount(count - 1) : () {},
        onReset: () => _setCounterCount(0),
      ),
    );
  }

  String _currentWebRoutePath() {
    final controllerSlug = normalizeSlug(slugController?.text.trim() ?? '');
    final dataSlug = normalizeSlug(zikrData?['slug']?.toString() ?? '');
    final cachedSlug = itemSlugs[widget.item.uid];

    return buildZikrDeepLinkPath(
      uid: widget.item.uid,
      slug: controllerSlug.isNotEmpty
          ? controllerSlug
          : dataSlug.isNotEmpty
              ? dataSlug
              : cachedSlug,
    );
  }

  String? _currentShareSlug() {
    final controllerSlug = normalizeSlug(slugController?.text.trim() ?? '');
    final dataSlug = normalizeSlug(zikrData?['slug']?.toString() ?? '');
    final cachedSlug = itemSlugs[widget.item.uid];

    if (controllerSlug.isNotEmpty) return controllerSlug;
    if (dataSlug.isNotEmpty) return dataSlug;
    return cachedSlug;
  }

  void _scheduleCurrentWebRouteSync({bool replace = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isCurrentRoute) return;
      syncWebRoutePath(_currentWebRoutePath(), replace: replace);
    });
  }

  /// [bottomInset] keeps the panel clear of the bottom action bar - the bar
  /// is a Stack overlay rather than something [constraints] already excludes,
  /// so without this the panel's default corner position and its drag range
  /// both reach straight under it.
  Offset _clampCounterOffset(
    Offset offset,
    BoxConstraints constraints, {
    double bottomInset = 0,
  }) {
    const edgePadding = 12.0;
    final maxLeft = math.max(
      edgePadding,
      constraints.maxWidth - ZikrCounter.panelWidth - edgePadding,
    );
    final maxTop = math.max(
      edgePadding,
      constraints.maxHeight -
          bottomInset -
          ZikrCounter.panelHeight -
          edgePadding,
    );

    return Offset(
      offset.dx.clamp(edgePadding, maxLeft).toDouble(),
      offset.dy.clamp(edgePadding, maxTop).toDouble(),
    );
  }

  Offset _resolveCounterOffset(
    BoxConstraints constraints,
    Offset offset, {
    double bottomInset = 0,
  }) {
    if (offset.dx >= 0 && offset.dy >= 0) {
      return _clampCounterOffset(offset, constraints, bottomInset: bottomInset);
    }

    return _clampCounterOffset(
      Offset(
        constraints.maxWidth - ZikrCounter.panelWidth - 16,
        constraints.maxHeight - bottomInset - ZikrCounter.panelHeight - 20,
      ),
      constraints,
      bottomInset: bottomInset,
    );
  }

  void _handleCounterDragUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints, {
    double bottomInset = 0,
  }) {
    final currentOffset = _resolveCounterOffset(
      constraints,
      _counterOffset.value,
      bottomInset: bottomInset,
    );
    _updateCounterOffset(
      _clampCounterOffset(
        currentOffset + details.delta,
        constraints,
        bottomInset: bottomInset,
      ),
    );
  }

  /// Vertical space the bottom action bar reserves, when it exists at all -
  /// its own height plus the device's bottom safe area, plus a small gap so
  /// the counter panel does not sit flush against it.
  double _counterBottomInset(BuildContext context, bool showActionBar) {
    if (!showActionBar) return 0;
    return ZikrActionBar.barHeight + MediaQuery.of(context).padding.bottom + 8;
  }

  Future<void> _checkAdmin() async {
    final user = _auth.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          userId = user.uid;
        });
      }
      try {
        final idTokenResult =
            await user.getIdTokenResult().timeout(const Duration(seconds: 4));
        final claims = idTokenResult.claims;
        if (!mounted) return;
        setState(() {
          isAdmin = claims != null && claims['admin'] == true;
        });
      } catch (error) {
        debugPrint('Unable to refresh zikr admin claim: $error');
      }
    }
  }

  Future<void> _initializePageData() async {
    final portion = widget.portion;
    if (portion != null) {
      // Already assembled in memory - there is nothing to fetch, and nothing
      // to write back either.
      _applyZikrData(portion.toZikrData());
      return;
    }

    if (isAdmin) {
      await _checkAdmin();
      final loaded = await _fetchZikrData();
      if (!loaded) _markZikrDataUnavailable();
      return;
    }

    final loaded = await _loadZikrDataFromAssets();
    if (!loaded) _markZikrDataUnavailable();
    _refreshAdminDataIfNeeded();
  }

  void _applyZikrData(Map<String, dynamic> data) {
    final currentSlug = normalizeSlug(data['slug']?.toString() ?? '');
    final currentAliases = normalizeSlugAliases(
      data['slugAliases'] is Iterable ? data['slugAliases'] : null,
      exclude: currentSlug,
    );
    setState(() {
      _didFailToLoadZikrData = false;
      zikrData = data;
      titleController = TextEditingController(text: zikrData?['title']);
      slugController = TextEditingController(text: currentSlug);
      codeController = TextEditingController(text: zikrData?['code']);
      dataController = TextEditingController(text: zikrData?['data']);
      meritsController = TextEditingController(text: zikrData?['merits']);
      dayController = TextEditingController(
        text: formatZikrDayValue(zikrData?['day']),
      );
      _slugAliases = currentAliases;
      final rawTabs = zikrData?['tabs'];
      if (rawTabs is List) {
        for (final controller in tabControllers) {
          controller.dispose();
        }
        tabControllers.clear();
        for (final tab in rawTabs) {
          tabControllers
              .add(TextEditingController(text: tab?.toString() ?? ''));
        }
      }
      final double? currentOrder = itemOrder[widget.item.uid];
      orderController = TextEditingController(
        text: formatZikrOrderValue(currentOrder),
      );
    });
    _scheduleCurrentWebRouteSync(replace: true);
  }

  Future<bool> _loadZikrDataFromAssets() async {
    try {
      final raw = await DefaultAssetBundle.of(context)
          .loadString('assets/zikr/${widget.item.getFirstUId()}');
      final decoded = json.decode(raw);
      if (decoded is! Map) {
        return false;
      }

      _applyZikrData(Map<String, dynamic>.from(decoded));
      return true;
    } catch (e) {
      debugPrint('Error loading zikr from assets: $e');
      return false;
    }
  }

  Future<bool> _loadZikrDataFromFirestore() async {
    try {
      final doc = await zikrCollection.doc(widget.item.getFirstUId()).get();
      if (!doc.exists) {
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      _applyZikrData(data);
      return true;
    } catch (e) {
      debugPrint('Error loading zikr from Firestore: $e');
      return false;
    }
  }

  Future<bool> _fetchZikrData() async {
    if (!isAdmin) {
      return _loadZikrDataFromAssets();
    }

    final loadedFromFirestore = await _loadZikrDataFromFirestore();
    if (loadedFromFirestore) return true;
    return _loadZikrDataFromAssets();
  }

  Future<void> _refreshAdminDataIfNeeded() async {
    await _checkAdmin();
    if (!mounted || !isAdmin) return;

    final loadedFromFirestore = await _loadZikrDataFromFirestore();
    if (!loadedFromFirestore && zikrData == null) {
      _markZikrDataUnavailable();
    }
  }

  void _markZikrDataUnavailable() {
    if (!mounted || zikrData != null) return;
    setState(() {
      _didFailToLoadZikrData = true;
    });
  }

  void _resetControllersFromCurrentData() {
    final currentSlug = normalizeSlug(zikrData?['slug']?.toString() ?? '');
    titleController?.text = zikrData?['title']?.toString() ?? '';
    slugController?.text = currentSlug;
    codeController?.text = zikrData?['code']?.toString() ?? '';
    dataController?.text = zikrData?['data']?.toString() ?? '';
    meritsController?.text = zikrData?['merits']?.toString() ?? '';
    dayController?.text = formatZikrDayValue(zikrData?['day']);
    final currentOrder = itemOrder[widget.item.uid];
    orderController?.text = formatZikrOrderValue(currentOrder);
    final rawSlugAliases = zikrData?['slugAliases'];
    _slugAliases = normalizeSlugAliases(
      rawSlugAliases is Iterable ? rawSlugAliases : null,
      exclude: currentSlug,
    );

    for (final controller in tabControllers) {
      controller.dispose();
    }
    tabControllers.clear();
    final rawTabs = zikrData?['tabs'];
    if (rawTabs is List) {
      for (final tab in rawTabs) {
        tabControllers.add(TextEditingController(text: tab?.toString() ?? ''));
      }
    }
  }

  void _toggleEdit() {
    setState(() {
      if (isEditing) {
        _resetControllersFromCurrentData();
      }
      isEditing = !isEditing;
    });
  }

  Future<void> _saveEdits() async {
    if (zikrData != null) {
      final trimmedTitle = titleController?.text.trim() ?? '';
      final rawOrder = orderController?.text.trim() ?? '';
      final rawDay = dayController?.text.trim() ?? '';
      final savedTabs = tabControllers
          .map((controller) => controller.text)
          .where((content) => content.trim().isNotEmpty)
          .toList();
      final existingSlug = normalizeSlug(zikrData?['slug']?.toString() ?? '');
      final enteredSlug = slugController?.text.trim() ?? '';
      final normalizedEnteredSlug = normalizeSlug(enteredSlug);
      if (enteredSlug.isNotEmpty && normalizedEnteredSlug.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Slug must contain letters or numbers'),
        ));
        return;
      }
      if (!isValidZikrOrderInput(rawOrder)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Order must be a number (examples: -2, 5, 5.5) or left blank'),
        ));
        return;
      }
      final parsedOrder = rawOrder.isEmpty ? null : double.parse(rawOrder);
      final nextSlug = enteredSlug.isNotEmpty
          ? normalizedEnteredSlug
          : existingSlug.isNotEmpty
              ? existingSlug
              : makeUniqueSlug(
                  buildSlugSeed(
                    uid: widget.item.uid,
                    title: trimmedTitle,
                  ),
                  currentUid: widget.item.uid,
                );
      if (!isSlugAvailable(nextSlug, currentUid: widget.item.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Slug is already in use. Please choose another one.'),
        ));
        return;
      }
      final nextSlugAliases = normalizeSlugAliases(
        [
          ..._slugAliases,
          if (existingSlug.isNotEmpty && existingSlug != nextSlug) existingSlug,
        ],
        exclude: nextSlug,
      );

      final dayValue = parseZikrDayInput(rawDay);

      await zikrCollection.doc(widget.item.uid).update({
        'title': titleController?.text,
        'slug': nextSlug,
        'slugAliases':
            nextSlugAliases.isEmpty ? FieldValue.delete() : nextSlugAliases,
        'code': codeController?.text,
        'data': dataController?.text,
        'merits': (meritsController?.text.trim().isEmpty ?? true)
            ? FieldValue.delete()
            : meritsController?.text,
        'day': dayValue == null ? FieldValue.delete() : dayValue,
        'tabs': savedTabs.isEmpty ? FieldValue.delete() : savedTabs,
        'order': parsedOrder ?? FieldValue.delete(),
      });
      if (parsedOrder == null) {
        itemOrder.remove(widget.item.uid);
      } else {
        itemOrder[widget.item.uid] = parsedOrder;
      }
      if (dayValue == null) {
        itemMetadata.remove(widget.item.uid);
      } else {
        itemMetadata[widget.item.uid] = {'day': dayValue};
      }
      items[widget.item.uid] = titleController?.text ?? widget.item.title;
      widget.item.title = titleController?.text ?? widget.item.title;
      setLocalSlugData(
        widget.item.uid,
        slug: nextSlug,
        aliases: nextSlugAliases,
      );
      setState(() {
        isEditing = false;
        zikrData?['title'] = titleController?.text;
        zikrData?['slug'] = nextSlug;
        zikrData?['slugAliases'] = nextSlugAliases;
        zikrData?['code'] = codeController?.text;
        zikrData?['data'] = dataController?.text;
        zikrData?['merits'] = meritsController?.text;
        zikrData?['day'] = dayValue;
        zikrData?['tabs'] = savedTabs;
        slugController?.text = nextSlug;
        _slugAliases = nextSlugAliases;
      });
      _scheduleCurrentWebRouteSync(replace: true);
    }
  }

  void _addTabField() {
    setState(() {
      tabControllers.add(TextEditingController());
    });
  }

  void _showMeritsSheet() {
    final merits = meritsController?.text.trim() ?? '';
    if (merits.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Merits',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    SelectableText(
                      merits,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _buildVisibleTabContents() {
    final primary = dataController?.text ?? zikrData?['data']?.toString() ?? '';
    final extraTabs = <String>[];
    final rawTabs = zikrData?['tabs'];

    if (tabControllers.isNotEmpty) {
      extraTabs.addAll(tabControllers.map((controller) => controller.text));
    } else if (rawTabs is List) {
      extraTabs.addAll(rawTabs.map((tab) => tab?.toString() ?? ''));
    }

    return buildVisibleZikrTabContents(
      primary: primary,
      extraTabs: extraTabs,
    );
  }

  Future<void> _deleteZikr() async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Zikr?'),
            content: Text(
              'This will permanently delete "${titleController?.text ?? widget.item.title}".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    await zikrCollection.doc(widget.item.uid).delete();
    items.remove(widget.item.uid);
    itemOrder.remove(widget.item.uid);
    itemMetadata.remove(widget.item.uid);
    removeLocalSlugData(widget.item.uid);

    if (!mounted) return;
    Navigator.pop(context);
  }

  int _clampedSelectedTabIndex(List<String> tabContents) {
    if (tabContents.isEmpty) return 0;
    return _selectedZikrTabIndex.clamp(0, tabContents.length - 1);
  }

  String _tabHeaderForContent(String content, int index) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    if (lines.isNotEmpty) {
      return ZikrContentParser.parseLineSegments(lines.first)
          .map((segment) => segment.text)
          .join()
          .trim();
    }
    return 'Part ${index + 1}';
  }

  Future<void> _shareZikrText({
    required String title,
    required String deepLink,
    required Rect sharePositionOrigin,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        text: '$title\n$deepLink',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<void> _shareCurrentZikr() async {
    if (_isSharingZikr) return;

    final title = titleController?.text.trim().isNotEmpty == true
        ? titleController!.text.trim()
        : widget.item.title;
    final deepLink = buildZikrDeepLinkUrl(
      uid: widget.item.uid,
      slug: _currentShareSlug(),
    );
    final sharePositionOrigin = Rect.fromLTWH(
      MediaQuery.of(context).size.width / 2,
      0,
      2,
      2,
    );

    setState(() {
      _isSharingZikr = true;
    });

    try {
      final shareImage = SP.prefs.getBool('share_zikr_image') ?? true;
      if (!shareImage) {
        await _shareZikrText(
          title: title,
          deepLink: deepLink,
          sharePositionOrigin: sharePositionOrigin,
        );
        return;
      }

      final tabContents = _buildVisibleTabContents();
      final selectedIndex = _clampedSelectedTabIndex(tabContents);
      final selectedContent =
          tabContents.isEmpty ? '' : tabContents[selectedIndex];
      if (selectedContent.trim().isEmpty) {
        await _shareZikrText(
          title: title,
          deepLink: deepLink,
          sharePositionOrigin: sharePositionOrigin,
        );
        return;
      }

      final showTabHeaders = tabContents.length > 1;
      final imageBytes = await buildZikrShareImage(
        ZikrShareImageRequest(
          title: title,
          tabTitle: showTabHeaders
              ? _tabHeaderForContent(selectedContent, selectedIndex)
              : '',
          content: selectedContent,
          hideHeaderLine: showTabHeaders,
          colorScheme: Theme.of(context).colorScheme,
          code: zikrData?['code']?.toString(),
        ),
      );
      if (imageBytes == null) {
        await _shareZikrText(
          title: title,
          deepLink: deepLink,
          sharePositionOrigin: sharePositionOrigin,
        );
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          title: title,
          subject: title,
          text: '$title\n$deepLink',
          files: [
            XFile.fromData(
              imageBytes,
              mimeType: 'image/png',
              name: 'shia-companion-zikr.png',
            ),
          ],
          fileNameOverrides: const ['shia-companion-zikr.png'],
          downloadFallbackEnabled: false,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (error) {
      debugPrint('Error sharing zikr image: $error');
      await _shareZikrText(
        title: title,
        deepLink: deepLink,
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharingZikr = false;
        });
      }
    }
  }

  void _handleContentScrollPositionChanged(
    ZikrContentScrollPosition position,
  ) {
    _currentTabScrollOffsets[position.tabIndex] = position.scrollOffset;
    _currentTabMaxScrollExtents[position.tabIndex] = position.maxScrollExtent;
    final lineIndex = position.lineIndex;
    if (lineIndex != null) {
      _currentTabTopLineIndexes[position.tabIndex] = lineIndex;
    }
    _updateReadingProgress();
  }

  /// Gives a bookmark saved before line indexes existed the line it turns out
  /// to sit on, measured once its offset has been restored, and rewrites it
  /// so the marker no longer depends on the offset surviving a relayout.
  void _handleBookmarkLineResolved(int lineIndex) {
    final bookmark = _savedBookmark;
    if (bookmark == null || bookmark.lineIndex != null) return;

    final upgraded = bookmark.copyWith(lineIndex: lineIndex);
    setState(() {
      _savedBookmark = upgraded;
    });
    unawaited(ZikrBookmarkStore.instance.save(upgraded));
  }

  /// Recomputes the reading estimate only when the rendered text changed, since
  /// this runs on every rebuild of the page.
  void _refreshReadingStats(
    List<String> tabContents, {
    required bool hideHeaderLine,
  }) {
    final signature = '$hideHeaderLine|${tabContents.join('\n')}';
    if (signature == _readingStatsSignature) return;

    _readingStatsSignature = signature;
    _readingStats = analyzeZikrReadingStats(
      tabContents,
      hideHeaderLine: hideHeaderLine,
    );
    // This runs from build, so the notifier is written once the frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateReadingProgress();
    });
  }

  void _updateReadingProgress() {
    _readingProgress.value = _computeReadingProgress();
  }

  double _computeReadingProgress() {
    final weights = _readingStats.tabWeights;
    if (weights.isEmpty) return 0;

    final tabIndex = _selectedZikrTabIndex.clamp(0, weights.length - 1);
    final maxScrollExtent = _currentTabMaxScrollExtents[tabIndex];
    // An unmeasured tab has not been laid out yet, so nothing is read.
    final tabFraction = maxScrollExtent == null
        ? 0.0
        : zikrTabScrollFraction(
            scrollOffset: _currentTabScrollOffsets[tabIndex] ?? 0,
            maxScrollExtent: maxScrollExtent,
          );

    return zikrReadingProgress(
      tabWeights: weights,
      tabIndex: tabIndex,
      tabFraction: tabFraction,
    );
  }

  Future<void> _toggleBookmark({
    required String pageTitle,
    required List<String> tabContents,
    required int selectedTabIndex,
  }) async {
    // Reading Quran, the bar keeps the verse on screen rather than marking a
    // place: resuming is the Continue reciting card's job, so one bookmark
    // icon means one thing throughout the Quran.
    if (_isQuran) {
      final verse = _currentVerse;
      if (verse != null) await _toggleSavedVerse(verse, _currentVerseText);
      return;
    }

    final existingBookmark = _savedBookmark;
    if (existingBookmark != null) {
      await ZikrBookmarkStore.instance.remove(_bookmarkUid);
      if (!mounted) return;
      setState(() {
        _savedBookmark = null;
      });
      unawaited(AnalyticsService.feature(
        'zikr_bookmark_removed',
        label: 'Bookmark removed',
      ));
      return;
    }

    final selectedContent =
        tabContents.isEmpty ? '' : tabContents[selectedTabIndex];
    final bookmark = ZikrBookmark(
      uid: _bookmarkUid,
      title: pageTitle,
      tabIndex: selectedTabIndex,
      tabTitle: tabContents.length > 1
          ? _tabHeaderForContent(selectedContent, selectedTabIndex)
          : null,
      scrollOffset: _currentTabScrollOffsets[selectedTabIndex] ?? 0,
      lineIndex: _currentTabTopLineIndexes[selectedTabIndex],
      updatedAt: DateTime.now().toUtc(),
    );

    await ZikrBookmarkStore.instance.save(bookmark);
    if (!mounted) return;
    setState(() {
      _savedBookmark = bookmark;
    });
    unawaited(AnalyticsService.feature(
      'zikr_bookmark_saved',
      label: 'Bookmark saved',
      parameters: {'zikr_uid': _bookmarkUid},
    ));
  }

  String? _lookupInternalItemUid(String segment) {
    if (segment.isEmpty) return null;

    if (items.containsKey(segment)) {
      return segment;
    }

    final mappedUid = slugToItemUid[segment];
    if (mappedUid != null) {
      return mappedUid;
    }

    return null;
  }

  String? _findInternalUid(String href) {
    final segment = extractZikrLinkSegment(href);
    return segment == null ? null : _lookupInternalItemUid(segment);
  }

  Future<void> _handleZikrLinkTap(String href) async {
    if (href.trim().isEmpty) return;

    final internalUid = _findInternalUid(href);
    if (internalUid != null) {
      final title = items[internalUid]?.toString() ?? internalUid;
      await pushPageRoute(
        context,
        ZikrPage(
          UidTitleData(internalUid, title),
          source: ZikrOpenSource.zikrLink,
        ),
      );
      return;
    }

    var uri = Uri.tryParse(href);
    if (uri == null) return;
    if (!uri.hasScheme) {
      uri = Uri.parse('https://$href');
    }

    await launchExternalUri(uri);
  }

  @override
  void didPush() {
    _isCurrentRoute = true;
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
    _previousBrowserUri ??= Uri.base;
    _scheduleCurrentWebRouteSync();
  }

  @override
  void didPopNext() {
    _isCurrentRoute = true;
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
    // Covers Focus mode being flipped from the global settings page while
    // this route sat underneath it - refreshState only runs from this
    // page's own drawer.
    _applyFocusModePreference();
    _scheduleCurrentWebRouteSync(replace: true);
  }

  @override
  void didPushNext() {
    _isCurrentRoute = false;
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
  }

  @override
  void didPop() {
    _isCurrentRoute = false;
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
    final previousBrowserUri = _previousBrowserUri;
    if (previousBrowserUri != null) {
      syncWebRouteUri(previousBrowserUri, replace: true);
    }
  }

  Widget _buildAppBarTitle(String title) {
    // Long titles wrap onto a second, smaller line instead of being clipped.
    final useTwoLines = title.trim().length > 24;
    return Text(
      title,
      maxLines: useTwoLines ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: useTwoLines ? const TextStyle(fontSize: 16, height: 1.2) : null,
    );
  }

  void _handleMenuAction(_ZikrMenuAction action) {
    switch (action) {
      case _ZikrMenuAction.edit:
        _toggleEdit();
        break;
    }
  }

  void _shareFromActionBar() {
    if (_isSharingZikr) return;
    unawaited(AnalyticsService.feature(
      'zikr_shared',
      label: 'Zikr shared',
      parameters: {'zikr_uid': widget.item.getFirstUId()},
    ));
    _shareCurrentZikr();
  }

  List<Widget> _buildAppBarActions({
    required String pageTitle,
    required List<String> tabContents,
    required int selectedTabIndex,
    required bool hasAnyContent,
  }) {
    final settingsButton = IconButton(
      icon: const Icon(Icons.filter_list),
      tooltip: 'Reading settings',
      onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
    );

    if (zikrData == null) return [settingsButton];

    if (isEditing) {
      if (!isAdmin) return [settingsButton];
      return [
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Delete Zikr',
          onPressed: _deleteZikr,
        ),
        IconButton(
          icon: const Icon(Icons.done),
          tooltip: 'Save Changes',
          onPressed: _saveEdits,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Stop editing',
          onPressed: _toggleEdit,
        ),
      ];
    }

    // Bookmark, share and reading settings now live in the bottom action
    // bar, where they are labelled and within thumb reach. All that stays
    // here is admin-only.
    return [
      if (isAdmin)
        PopupMenuButton<_ZikrMenuAction>(
          tooltip: 'More options',
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _ZikrMenuAction.edit,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit),
                title: Text('Edit Zikr'),
              ),
            ),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final merits = meritsController?.text.trim() ?? '';
    final hasMerits = merits.isNotEmpty;
    final tabContents = _buildVisibleTabContents();
    final pageTitle = isEditing
        ? (titleController?.text.trim().isNotEmpty == true
            ? titleController!.text.trim()
            : widget.item.title)
        : (zikrData?['title']?.toString().trim().isNotEmpty == true
            ? zikrData!['title'].toString().trim()
            : widget.item.title);
    final hasAnyContent =
        tabContents.any((content) => content.trim().isNotEmpty);
    final selectedTabIndex = _clampedSelectedTabIndex(tabContents);
    _refreshReadingStats(
      isEditing ? const [] : tabContents,
      hideHeaderLine: tabContents.length > 1,
    );
    final audioTracks = ZikrAudioTrack.listFrom(zikrData?['audio']);
    // Editing replaces the reading view with a form, and the bar's actions all
    // act on the rendered zikr, so it has nothing to do there.
    final showActionBar = !isEditing && zikrData != null;
    // Independent of showActionBar - a zikr with no estimable reading time
    // (still loading, or edit mode, where _refreshReadingStats is fed no
    // content at all) can lack one while the other still applies.
    final showProgressBar = !isEditing && _readingStats.hasContent;
    final readingTimeLabel = zikrReadingTimeLabel(_readingStats.duration);

    return SelectionArea(
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: _buildAppBarTitle(pageTitle),
          // Reading settings opens this same endDrawer from the bottom bar
          // now. Without this, AppBar auto-fills an empty actions list (the
          // common case, for any non-admin reader) with its own end-drawer
          // button - "Open navigation menu" - duplicating that entry point.
          automaticallyImplyActions: false,
          actions: _buildAppBarActions(
            pageTitle: pageTitle,
            tabContents: tabContents,
            selectedTabIndex: selectedTabIndex,
            hasAnyContent: hasAnyContent,
          ),
        ),
        endDrawer: ZikrSettingsPage(refreshState),
        body: Listener(
          // Covers the whole reading area, not just either bar: after the
          // idle timeout has hidden the chrome, the reader should not have to
          // hunt for exactly where to tap to get it back.
          onPointerDown: (_) {
            if (showActionBar || showProgressBar) _revealChrome();
          },
          behavior: HitTestBehavior.translucent,
          child: NotificationListener<UserScrollNotification>(
            onNotification: _handleScrollNotification,
            child: LayoutBuilder(
              builder: (context, bodyConstraints) => Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: zikrData == null
                            ? Center(
                                child: _didFailToLoadZikrData
                                    ? const Text('Unable to open this dua.')
                                    : const CircularProgressIndicator(),
                              )
                            : !hasAnyContent && !isEditing
                                ? const Center(child: Text('Coming soon...'))
                                : ValueListenableBuilder<bool>(
                                    valueListenable: _chromeVisible,
                                    builder: (context, chromeVisible, content) {
                                      // Both bars float over the reading area
                                      // rather than sitting in the column, so
                                      // this - not either bar's own size - is
                                      // what reserves room for them. Tied to
                                      // their shared visibility rather than
                                      // fixed, so the text reclaims that room
                                      // the moment they slide away instead of
                                      // leaving a standing gap sized for
                                      // chrome that is off screen.
                                      final chromeInsets = EdgeInsets.only(
                                        top: showProgressBar && chromeVisible
                                            ? ZikrReadingProgressBar.barHeight
                                            : 0.0,
                                        bottom: showActionBar && chromeVisible
                                            ? ZikrActionBar.barHeight
                                            : 0.0,
                                      );
                                      return TweenAnimationBuilder<EdgeInsets>(
                                        // begin == end here always - only
                                        // `end` changing between builds is
                                        // what TweenAnimationBuilder acts on,
                                        // animating from wherever it already
                                        // is. begin only matters on the very
                                        // first build, where it must equal
                                        // end so opening the page does not
                                        // play a spurious reveal animation.
                                        tween: EdgeInsetsTween(
                                          begin: chromeInsets,
                                          end: chromeInsets,
                                        ),
                                        duration:
                                            const Duration(milliseconds: 220),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, insets, content) =>
                                            ResponsiveContent(
                                          maxWidth: isEditing
                                              ? wideContentWidth
                                              : readingContentWidth,
                                          padding: EdgeInsets.fromLTRB(
                                            16,
                                            16 + insets.top,
                                            16,
                                            16 + insets.bottom,
                                          ),
                                          child: content!,
                                        ),
                                        child: content,
                                      );
                                    },
                                    child: isEditing
                                        ? ZikrEditFormWidget(
                                            titleController: titleController!,
                                            slugController: slugController!,
                                            codeController: codeController!,
                                            orderController: orderController!,
                                            dayController: dayController!,
                                            meritsController: meritsController!,
                                            dataController: dataController!,
                                            tabControllers: tabControllers,
                                            onAddTab: _addTabField,
                                          )
                                        : ZikrContentViewerWidget(
                                            tabContents: tabContents,
                                            selectedTabIndex: selectedTabIndex,
                                            onTabChanged: (index) {
                                              setState(() {
                                                _selectedZikrTabIndex = index;
                                              });
                                              _updateReadingProgress();
                                            },
                                            hasMerits: hasMerits,
                                            onShowMerits: _showMeritsSheet,
                                            onLinkTap: _handleZikrLinkTap,
                                            code: zikrData?['code']?.toString(),
                                            initialBookmarkTabIndex:
                                                _savedBookmark?.tabIndex,
                                            initialBookmarkScrollOffset:
                                                _savedBookmark?.scrollOffset,
                                            initialBookmarkLineIndex:
                                                _savedBookmark?.lineIndex,
                                            savedVerses: _savedVerses,
                                            onScrollPositionChanged:
                                                _handleContentScrollPositionChanged,
                                            surahNumber: _surahNumber,
                                            initialVerse: _initialVerse,
                                            ayahIndex: widget.portion?.index,
                                            onAyahPositionChanged:
                                                _handleAyahPositionChanged,
                                            onAyahAction: _isQuran
                                                ? _showAyahActions
                                                : null,
                                            onBookmarkLineResolved:
                                                _handleBookmarkLineResolved,
                                          ),
                                  ),
                      ),
                    ],
                  ),
                  if (showProgressBar)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      // Stack only clips a child that overflows its *layout*;
                      // AnimatedSlide is a paint-time translation, so without
                      // this the strip would paint up into the app bar's
                      // band instead of disappearing behind its edge.
                      child: ClipRect(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _chromeVisible,
                          builder: (context, visible, child) => AnimatedSlide(
                            offset: visible ? Offset.zero : const Offset(0, -1),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: child,
                          ),
                          // Purely informational and sits over selectable
                          // text - taps and drags must keep reaching the
                          // reading column underneath.
                          child: IgnorePointer(
                            child: ValueListenableBuilder<double>(
                              valueListenable: _readingProgress,
                              builder: (context, progress, _) =>
                                  ZikrReadingProgressBar(
                                progress: progress,
                                readingTimeLabel: readingTimeLabel,
                                progressLabel: zikrProgressLabel(progress),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Counter overlay
                  ValueListenableBuilder<bool>(
                    valueListenable: _showCounter,
                    builder: (context, visible, _) {
                      if (!visible) return const SizedBox.shrink();
                      return ValueListenableBuilder<Offset>(
                        valueListenable: _counterOffset,
                        builder: (context, offset, __) {
                          final bottomInset = _counterBottomInset(
                            context,
                            showActionBar,
                          );
                          final resolvedOffset = _resolveCounterOffset(
                            bodyConstraints,
                            offset,
                            bottomInset: bottomInset,
                          );
                          return Positioned(
                            left: resolvedOffset.dx,
                            top: resolvedOffset.dy,
                            child: SelectionContainer.disabled(
                              child: GestureDetector(
                                onPanUpdate: (details) =>
                                    _handleCounterDragUpdate(
                                  details,
                                  bodyConstraints,
                                  bottomInset: bottomInset,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _buildCounterCard(),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Material(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        shape: const CircleBorder(),
                                        child: IconButton(
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          icon:
                                              const Icon(Icons.close, size: 16),
                                          tooltip: 'Hide counter',
                                          onPressed: () =>
                                              _setCounterVisibility(false),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (showActionBar)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _chromeVisible,
                        builder: (context, visible, child) => AnimatedSlide(
                          // Slides out of frame rather than collapsing: the bar
                          // sits over the reading area, so its size never
                          // affects the text's layout either way.
                          offset: visible ? Offset.zero : const Offset(0, 1),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: child,
                        ),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _showCounter,
                          builder: (context, counterVisible, _) =>
                              ZikrActionBar(
                            hasAudio: audioTracks.isNotEmpty,
                            canBookmark: hasAnyContent,
                            isBookmarked: _isQuran
                                ? (_currentVerse != null &&
                                    _savedVerses.contains(_currentVerse))
                                : _savedBookmark != null,
                            canShare: !_isSharingZikr,
                            isCounterVisible: counterVisible,
                            onBookmark: () => _toggleBookmark(
                              pageTitle: pageTitle,
                              tabContents: tabContents,
                              selectedTabIndex: selectedTabIndex,
                            ),
                            onShare: _shareFromActionBar,
                            onListen: _openAudioPlayer,
                            onSettings: () =>
                                _scaffoldKey.currentState?.openEndDrawer(),
                            onCounter: _toggleCounterFromActionBar,
                            player: _showAudioPlayer && audioTracks.isNotEmpty
                                ? ZikrAudioPlayer(
                                    tracks: audioTracks,
                                    zikrUid: widget.item.getUId(),
                                    zikrTitle: pageTitle,
                                    onClose: _closeAudioPlayer,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void refreshState() {
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
    _applyFocusModePreference();
    setState(() {});
  }
}
