import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kTouchSlop;
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/data/retired_zikr_redirects.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/services/activity_stats_store.dart';
import 'package:shia_companion/services/analytics_service.dart';
import 'package:shia_companion/services/mistake_report_service.dart';
import 'package:shia_companion/services/rating_prompt_service.dart';
import 'package:shia_companion/services/zikr_audio_index.dart';
import 'package:shia_companion/services/zikr_bookmark_store.dart';
import 'package:shia_companion/services/zikr_bookmarks_manager.dart';
import 'package:shia_companion/services/zikr_counter_session.dart';
import 'package:shia_companion/models/recitation_tracker_state.dart';
import 'package:shia_companion/models/saved_verse.dart';
import 'package:shia_companion/services/recitation_tracker_manager.dart';
import 'package:shia_companion/services/saved_verses_manager.dart';
import 'package:shia_companion/utils/deep_links.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/quran_indopak.dart';
import 'package:shia_companion/utils/quran_script.dart';
import 'package:shia_companion/utils/quran_portion.dart';
import 'package:shia_companion/utils/external_launch.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/web_route_sync.dart';
import 'package:shia_companion/utils/zikr_wakelock.dart';
import 'package:shia_companion/models/zikr_audio_track.dart';
import '../../constants.dart';
import '../../theme/shia_colors.dart';
import '../../widgets/choice_sheet.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/zikr_action_bar.dart';
import '../../widgets/zikr_audio_player.dart';
import '../../widgets/zikr_reading_preferences.dart';
import '../../widgets/favorite_icon.dart';
import '../../widgets/outline_icon.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/reader_text_sheet.dart';
import '../../widgets/reader_top_bar.dart';
import '../../widgets/zikr_counter.dart';
import '../quran/quran_navigation.dart';
import '../zikr_reminder_form_page.dart';
import 'zikr_form_helpers.dart';
import 'zikr_content_parser.dart';
import 'zikr_content_viewer.dart';
import 'zikr_reading_stats.dart';
import 'zikr_share_image.dart';
import '../../services/zikr_translations.dart';
import '../../l10n/l10n.dart';

/// How far the text has to actually travel in one direction before the
/// reading chrome reacts.
///
/// This replaces reacting to [UserScrollNotification]'s direction, which
/// flips the instant a finger wobbles back by a pixel: on a normal read that
/// meant the progress strip and action bar popping in and back out several
/// times a gesture. A deliberate scroll crosses this in a frame or two; the
/// wobble inside one never does.
const double kZikrChromeScrollThreshold = 36.0;

/// Turns the reading area's stream of scroll deltas into hide/show decisions
/// for the reading chrome - the progress strip and the bottom action bar,
/// which move together. [update] returns true to show, false to hide, and
/// null - by far the common case - for "leave it exactly as it is".
///
/// Kept free of Flutter's scroll notification types (which need a live
/// [BuildContext] to build) so the whole hysteresis rule is unit testable.
class ZikrChromeScrollTracker {
  /// Signed pixels travelled since the last decision, positive downwards.
  /// Reset rather than carried whenever the reader reverses, so a scroll up
  /// starts earning its reveal from zero instead of from a debt built up
  /// scrolling down.
  double _accumulated = 0.0;

  /// Called at the start and end of every gesture: a new gesture always
  /// starts from zero, and momentum left over from the last one must not
  /// count towards the next one's threshold.
  void reset() {
    _accumulated = 0.0;
  }

  bool? update({
    required Axis axis,
    required double delta,
    required bool outOfRange,
    required bool chromeVisible,
    double threshold = kZikrChromeScrollThreshold,
  }) {
    // Horizontal scrolling is a swipe between tabs, not reading movement.
    // The reading list is nested inside the tabs' PageView, so its
    // notifications and the PageView's own arrive at the same listener.
    if (axis != Axis.vertical) return null;
    // An overscroll bounce reverses under its own momentum with no reader
    // input at all; letting that count would reveal the chrome every time a
    // read hit the end of a zikr.
    if (outOfRange) {
      _accumulated = 0.0;
      return null;
    }
    if (delta == 0) return null;
    if (_accumulated != 0 && _accumulated.isNegative != delta.isNegative) {
      _accumulated = 0.0;
    }
    _accumulated += delta;

    if (_accumulated >= threshold) {
      _accumulated = 0.0;
      return chromeVisible ? false : null;
    }
    if (_accumulated <= -threshold) {
      _accumulated = 0.0;
      return chromeVisible ? null : true;
    }
    return null;
  }
}

/// Which verse a Quran reading should open at.
///
/// A destination only counts when it actually names an ayah: opening a surah
/// from the list passes its `VerseKey` with a null ayah, meaning "this surah"
/// rather than "the top of it".
///
/// Resuming is deliberately not part of this. Where someone left off is a
/// recitation track's own job — each label's resume card opens at
/// [RecitationTrackerState.resumePositionFor] — and saved verses are a
/// collection to keep rather than a place to return to.
///
/// Pure and top-level, like [resolveChromeVisibilityForScroll], so the rule can
/// be tested without standing up a page.
VerseKey? resolveInitialVerse(VerseKey? requested) =>
    requested?.ayah != null ? requested : null;

/// Whether a scroll notification from the reading content should drop a live
/// text selection.
///
/// Any scroll the reader drives should: the reading column is a lazily built
/// list, so scrolling disposes the very [Selectable] a selection edge sits in
/// and leaves the selection overlay reading geometry that is no longer in the
/// tree - the crash in `SelectableRegion` this guards against.
///
/// Idle is the carve-out, and it is not a nicety. `SelectableRegion`
/// auto-scrolls the list by `jumpTo` while a selection handle is dragged past
/// its edge, and `jumpTo` reports its scroll as idle. Acting on that would
/// cancel the selection the reader is in the middle of making.
///
/// Kept out of [_ZikrPageState] for the same reason as
/// [resolveChromeVisibilityForScroll]: a real [UserScrollNotification] needs a
/// live [BuildContext] to build.
bool shouldClearSelectionForScroll(ScrollDirection direction) =>
    direction != ScrollDirection.idle;

class ZikrPage extends StatefulWidget {
  final UidTitleData item;

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

  /// The recitation track this read belongs to ("Family", "Personal", ...),
  /// set only when opened by tapping that track's resume card. Null for
  /// every other entry point — browsing, search, a deep link — which is what
  /// routes genuine reading there into [unlabeledRecitationLabel] instead of
  /// silently attributing it to whichever track was last used.
  final String? recitationLabel;

  /// The browser URL to put back when this page is popped, when it replaced
  /// another reader rather than being pushed over the page it returns to - a
  /// "Next surah" step swaps the route, so the URL worth restoring on back is
  /// the one the first reader in the chain was opened from.
  final Uri? returnBrowserUri;

  ZikrPage(
    this.item, {
    this.source = ZikrOpenSource.unknown,
    this.initialVerse,
    this.portion,
    this.recitationLabel,
    this.returnBrowserUri,
  });

  @override
  _ZikrPageState createState() => _ZikrPageState();
}

class _ZikrPageState extends State<ZikrPage> with RouteAware {
  bool _isSharingZikr = false;
  bool _isCurrentRoute = false;
  bool _didFailToLoadZikrData = false;
  int _selectedZikrTabIndex = 0;
  Map<String, dynamic>? zikrData;

  /// This zikr in the reader's translation language, or null in English or
  /// when none of it has been translated - see [ZikrTranslations].
  ZikrDocumentTranslation? _translation;
  PageRoute? _pageRoute;
  Uri? _previousBrowserUri;
  ZikrBookmark? _savedBookmark;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Focus for the reading area's [SelectionArea]. Held here, rather than left
  /// to the node the widget would make for itself, so the page can drop a live
  /// selection through [_clearTextSelection] before the text it was made in
  /// goes away.
  final FocusNode _selectionFocusNode =
      FocusNode(debugLabel: 'ZikrPage selection');

  /// The most recent text the reader had highlighted, so "Suggest a
  /// Correction" - added to the selection toolbar alongside Copy and Select
  /// All - can quote it without needing the [SelectableRegionState] the
  /// button was built from, which is gone by the time the reader actually
  /// taps it.
  String? _lastSelectedText;

  final Map<int, double> _currentTabScrollOffsets = {};
  final Map<int, double> _currentTabMaxScrollExtents = {};

  /// Each tab's scroll fraction, smoothed against the transient dips
  /// [zikrSmoothedTabFraction] guards against. Keyed separately from
  /// [_currentTabMaxScrollExtents] since the raw and smoothed values diverge
  /// mid-scroll.
  final Map<int, double> _currentTabScrollFractions = {};

  /// Per tab, the furthest share of its text that has been on screen - see
  /// [ZikrContentScrollPosition.seenFraction]. Only ever grows: scrolling
  /// back up to re-read a line does not un-read the rest. This, not
  /// [_readingProgress], is what [_maybeRecordCompletion] judges by.
  final Map<int, double> _tabSeenFractions = {};

  /// Tabs that count as recited this visit - see [zikrTabCompletionWait].
  /// The progress strip says "Completed" for exactly these.
  final Set<int> _completedTabs = {};

  /// Time spent on each tab before the one open now, so a tab's recitation
  /// time is judged by the time spent on it rather than on the page.
  final Map<int, Duration> _tabDwell = {};

  /// The tab being timed now and since when; null until the first tab change,
  /// which leaves the tab the page opened on timed from [_openedAt].
  int? _dwellTabIndex;
  DateTime? _dwellSince;

  /// Pending re-check for a reader who has reached the end of a tab before
  /// enough time has passed, and then stops scrolling - in sajdah, say - so
  /// no scroll event would ever check again.
  Timer? _completionTimer;

  /// The line a bookmark taken now would record in each tab - the first
  /// verse whose top is on screen, measured from the laid out list - so the
  /// marker lands on the first whole verse, not one cut off at the top.
  final Map<int, int> _currentTabTopLineIndexes = {};
  final ValueNotifier<double> _readingProgress = ValueNotifier<double>(0);

  /// The verse at the top of the reading, for the top bar's "Verse 255 of
  /// 286". Follows every report, not just the reader's own scrolling, so it
  /// is right from the moment the page opens at a verse.
  late final ValueNotifier<VerseKey?> _currentVerse =
      ValueNotifier(widget.initialVerse);
  bool _hasRecordedCompletion = false;
  bool _isDisposing = false;
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

  /// The last verse reported as being read, so a debounced save has something
  /// to write and repeat reports of the same verse cost nothing.
  VerseKey? _pendingProgressVerse;
  Timer? _progressSaveTimer;

  /// The lowest and highest ayah reached by genuine reading this visit, per
  /// surah touched — a juz session can cross into several. Committed to the
  /// recitation tracker on the same debounce as [_pendingProgressVerse], and
  /// flushed once more on [dispose] so the last move before leaving is never
  /// lost.
  final Map<int, (int, int)> _recitedRangesThisSession = {};

  /// One stable entry id per surah touched this visit, so repeated flushes
  /// as the reader keeps scrolling extend the same recitation-tracker entry
  /// instead of logging a fresh one every time the debounce fires.
  final Map<int, String> _recitationEntryIdsThisSession = {};

  /// Whether reaching the end has already been recorded this visit - see
  /// [_maybeMarkQuranEndReached] - and the wait before it counts, when the
  /// end was reached without scrolling.
  bool _hasMarkedQuranEnd = false;
  Timer? _quranEndTimer;

  @override
  void initState() {
    super.initState();
    // A portion spans surahs, so it has no single surah of its own; its index
    // carries one per verse instead.
    _surahNumber = widget.portion != null
        ? null
        : surahForUid(widget.item.getFirstUId());
    _counterSessionId = widget.item.getFirstUId();
    final counterState =
        ZikrCounterSessionStore.instance.read(_counterSessionId);
    _counterOffset = ValueNotifier(counterState.offset);
    _showCounter = ValueNotifier(counterState.isVisible);
    _counterCount = ValueNotifier(counterState.count);
    _loadSavedBookmark();
    if (widget.portion == null && !_isQuran) {
      // Bookmarks sync, so one can be moved on another device while this
      // page is open, and the marker follows it.
      ZikrBookmarksManager.instance.addListener(_handleBookmarksChanged);
    }
    _loadSavedVerses();
    if (_isQuran) {
      // Saved verses sync, so they can arrive after the page opens - loaded
      // late, or saved on another device - and the marks follow them.
      SavedVersesManager.instance.addListener(_handleSavedVersesChanged);
      unawaited(SavedVersesManager.instance.loadSavedVerses());
    }
    // The one place a zikr open is counted, so every entry point lands in the
    // same bucket exactly once.
    _openedAt = DateTime.now();
    RatingPromptService.readerOpened();
    unawaited(trackScreen('Zikr Page'));
    unawaited(AnalyticsService.zikrView(
      uid: widget.item.getUId(),
      title: widget.item.getTitle(),
      source: widget.source,
    ));
    _readingProgress.addListener(_maybeRecordCompletion);
    _readingProgress.addListener(_maybeMarkQuranEndReached);
    ZikrTranslations.instance.addListener(_loadTranslation);
    _initializePageData();
    _scheduleChromeIdleHide();
  }

  /// Rebuilds the page, deferred to the end of the frame when asked mid-build
  /// or mid-layout - progress can be reported from either.
  void _markNeedsRebuild() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  /// The tab whose time is running now.
  int get _dwellTab => _dwellTabIndex ?? _selectedZikrTabIndex;

  /// Time spent on [tabIndex] this visit.
  Duration _tabElapsed(int tabIndex) {
    final before = _tabDwell[tabIndex] ?? Duration.zero;
    final since = _dwellSince ?? _openedAt;
    if (tabIndex != _dwellTab || since == null) return before;
    return before + DateTime.now().difference(since);
  }

  /// Stops [_dwellTab]'s clock and starts [tabIndex]'s.
  void _startTabDwell(int tabIndex) {
    final current = _dwellTab;
    if (current == tabIndex && _dwellTabIndex != null) return;
    _tabDwell[current] = _tabElapsed(current);
    _dwellTabIndex = tabIndex;
    _dwellSince = DateTime.now();
  }

  /// Marks each tab that now counts as recited, and records the zikr as
  /// recited - at most once. Opening a zikr and reciting one are different
  /// things and the dashboard should not conflate them.
  ///
  /// A tab counts as recited once 90% of it has been on screen and the reader
  /// has stayed on it for 40% of its estimated recitation time (see
  /// [zikrTabCompletionWait]). Scroll position alone is not enough: a dua
  /// short enough to fit on screen is "fully seen" the moment it lays out,
  /// so a stray tap would outrank a real recitation.
  void _maybeRecordCompletion() {
    if (_openedAt == null || !mounted) return;

    Duration? pendingWait;
    var newlyCompleted = false;
    _tabSeenFractions.forEach((tabIndex, seen) {
      if (_completedTabs.contains(tabIndex)) return;
      final tabs = _readingStats.tabs;
      final wait = zikrTabCompletionWait(
        seenFraction: seen,
        tab: tabIndex >= 0 && tabIndex < tabs.length ? tabs[tabIndex] : null,
        elapsed: _tabElapsed(tabIndex),
      );
      if (wait == null) return;
      if (wait == Duration.zero) {
        _completedTabs.add(tabIndex);
        newlyCompleted = true;
      } else if (tabIndex == _dwellTab) {
        // Only the open tab's clock is running; any other has to be
        // returned to before it can finish.
        pendingWait = wait;
      }
    });

    _completionTimer?.cancel();
    final wait = pendingWait;
    if (wait != null) {
      _completionTimer = Timer(wait, () {
        if (mounted) _maybeRecordCompletion();
      });
    }
    if (!newlyCompleted) return;
    // The progress strip's label reads [_completedTabs]. Skipped on the way
    // out - [dispose] calls this too.
    if (!_isDisposing) _markNeedsRebuild();

    if (_hasRecordedCompletion) return;
    _hasRecordedCompletion = true;
    unawaited(AnalyticsService.zikrCompleted(
      uid: widget.item.getUId(),
      title: widget.item.getTitle(),
    ));
    // Only leaves an ask pending: the reader is still on the closing lines.
    // It is put to them once they leave this page - see [dispose].
    unawaited(RatingPromptService.recordZikrCompleted());
    unawaited(
        ActivityStatsStore.instance.recordZikrCompleted(widget.item.getUId()));
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
    if (position.verse.ayah != null) _currentVerse.value = position.verse;
    if (!position.fromUserScroll) return;
    final ayah = position.verse.ayah;
    if (ayah == null) return;
    if (position.verse == _pendingProgressVerse) return;

    _pendingProgressVerse = position.verse;
    _extendRecitedRange(position.verse.surah, ayah, ayah);
    // Reading on past the end marker's gate - scrolling counts as reading.
    _maybeMarkQuranEndReached();
  }

  /// Widens this visit's recited range for [surah] to cover [from]–[to], and
  /// queues the tracker write.
  void _extendRecitedRange(int surah, int from, int to) {
    final existingRange = _recitedRangesThisSession[surah];
    _recitedRangesThisSession[surah] = existingRange == null
        ? (from, to)
        : (
            math.min(existingRange.$1, from),
            math.max(existingRange.$2, to),
          );

    // Scrolling reports continuously; logging per frame would be pointless
    // churn, so wait for the reader to settle. Still only on the device -
    // the remote sync waits for the reader to leave, see [dispose].
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer(
      const Duration(seconds: 1),
      () => _flushRecitationProgress(syncRemote: false),
    );
  }

  /// The last verse of what is open - a surah's final ayah, or a juz's.
  VerseKey? get _quranEndVerse {
    final portion = widget.portion;
    if (portion != null) {
      final spans = portion.index.spans;
      for (var i = spans.length - 1; i >= 0; i--) {
        final verse = spans[i].verse;
        if (verse != null) return verse;
      }
      return null;
    }
    final surah = _surahNumber;
    final info = surah == null ? null : surahInfoFor(surah);
    return info == null ? null : VerseKey(info.number, info.ayahCount);
  }

  /// The first ayah of [surah] this document holds - 1 for a surah, but a
  /// juz can open part-way through one.
  int _firstAyahInDocument(int surah) {
    final portion = widget.portion;
    if (portion == null) return 1;
    for (final span in portion.index.spans) {
      final verse = span.verse;
      if (verse != null && verse.surah == surah) return verse.ayah ?? 1;
    }
    return 1;
  }

  /// Marks the closing verses as recited once the reader reaches the end.
  ///
  /// The per-scroll report only ever sees the verse at the *top* of the view,
  /// so on its own it can never reach the last verses of a surah - they are
  /// on screen at the bottom when the list stops - and it records nothing at
  /// all for a surah short enough to fit without scrolling (al-Fatihah on a
  /// desktop browser), which is why a new track could sit on al-Fatihah
  /// forever. Reaching the end fills that in: straight away if the reader
  /// scrolled there, otherwise once they have stayed about as long as the
  /// text takes to recite, so a glance at a short surah is not a recitation.
  void _maybeMarkQuranEndReached() {
    if (_hasMarkedQuranEnd || !_isQuran || !mounted) return;
    if (_readingProgress.value < 0.98) {
      _quranEndTimer?.cancel();
      _quranEndTimer = null;
      return;
    }

    final end = _quranEndVerse;
    final endAyah = end?.ayah;
    final openedAt = _openedAt;
    if (end == null || endAyah == null || openedAt == null) return;

    final readByScrolling = _recitedRangesThisSession.isNotEmpty;
    if (!readByScrolling) {
      final required = Duration(
        seconds: math.max(10, _readingStats.duration.inSeconds ~/ 2),
      );
      final elapsed = DateTime.now().difference(openedAt);
      if (elapsed < required) {
        _quranEndTimer ??= Timer(
          required - elapsed + const Duration(milliseconds: 200),
          () {
            _quranEndTimer = null;
            _maybeMarkQuranEndReached();
          },
        );
        return;
      }
    }

    _hasMarkedQuranEnd = true;
    _quranEndTimer?.cancel();
    _quranEndTimer = null;
    final opening = _initialVerse;
    final from = _recitedRangesThisSession[end.surah]?.$1 ??
        (opening != null && opening.surah == end.surah && opening.ayah != null
            ? opening.ayah!
            : _firstAyahInDocument(end.surah));
    _extendRecitedRange(end.surah, from, endAyah);
  }

  /// Commits every surah's range touched by genuine reading this visit to
  /// the recitation tracker, under [ZikrPage.recitationLabel] or, absent one,
  /// [unlabeledRecitationLabel].
  ///
  /// Also called from [dispose], because leaving the page is the most likely
  /// moment for a debounced write to still be waiting - closing a surah right
  /// after reading a verse is the ordinary way to finish, and losing that
  /// last move is exactly the place someone would notice. Each surah keeps
  /// the same entry id for the life of this page, so a flush mid-session
  /// extends that entry rather than logging a new one, and this is safe to
  /// call repeatedly - an unchanged range is a no-op in the manager.
  void _flushRecitationProgress({bool syncRemote = true}) {
    if (_recitedRangesThisSession.isEmpty) return;

    for (final touched in _recitedRangesThisSession.entries) {
      final surah = touched.key;
      final (fromAyah, toAyah) = touched.value;
      final id = _recitationEntryIdsThisSession.putIfAbsent(
        surah,
        () =>
            'auto_${_openedAt?.microsecondsSinceEpoch ?? DateTime.now().microsecondsSinceEpoch}_$surah',
      );
      unawaited(RecitationTrackerManager.instance.logRecitation(
        id: id,
        label: widget.recitationLabel ?? unlabeledRecitationLabel,
        surah: surah,
        fromAyah: fromAyah,
        toAyah: toAyah,
        readInJuz: widget.portion != null,
        syncRemote: syncRemote,
      ));
    }
  }

  /// "Previous" / "Next" at the end of a surah or a juz, so reading straight
  /// through the Quran never means going back to a list. Null for anything
  /// that is not Quran.
  Widget? _buildQuranSequenceFooter() {
    final juz = widget.portion?.juz;
    final surah = _surahNumber;
    if (juz == null && surah == null) return null;

    final String? previousLabel;
    final String? nextLabel;
    if (juz != null) {
      previousLabel = juz > 1 ? context.l10n.quranJuzNumber(juz - 1) : null;
      nextLabel =
          juz < allJuz().length ? context.l10n.quranJuzNumber(juz + 1) : null;
    } else {
      previousLabel = _surahSequenceLabel(surah! - 1);
      nextLabel = _surahSequenceLabel(surah + 1);
    }

    return QuranSequenceFooter(
      unit: juz != null ? null : context.l10n.quranUnitSurah,
      previousLabel: previousLabel,
      nextLabel: nextLabel,
      onPrevious: () => _openQuranSequenceStep(-1),
      onNext: () => _openQuranSequenceStep(1),
    );
  }

  String? _surahSequenceLabel(int surah) {
    final info = surahInfoFor(surah);
    return info?.englishName;
  }

  Future<void> _openQuranSequenceStep(int delta) async {
    final juz = widget.portion?.juz;
    final returnUri = _previousBrowserUri;
    unawaited(AnalyticsService.feature(
      juz != null ? 'quran_juz_step' : 'quran_surah_step',
      label:
          juz != null ? 'Quran next/previous juz' : 'Quran next/previous surah',
      parameters: {'direction': delta > 0 ? 'next' : 'previous'},
    ));
    if (juz != null) {
      await openQuranJuz(
        context,
        juz + delta,
        source: widget.source,
        recitationLabel: widget.recitationLabel,
        replace: true,
        returnBrowserUri: returnUri,
      );
      return;
    }
    final surah = _surahNumber;
    if (surah == null) return;
    await openQuranVerse(
      context,
      VerseKey(surah + delta),
      source: widget.source,
      recitationLabel: widget.recitationLabel,
      replace: true,
      returnBrowserUri: returnUri,
    );
  }

  /// A sideways swipe across a surah or a juz steps to the next one (a swipe
  /// towards the start of the line) or the previous one, as the footer's
  /// buttons do. Touch only: a mouse dragging sideways is selecting text.
  /// Left alone where there are tabs, whose pager the swipe already turns.
  Widget _withQuranSwipe({required bool hasTabs, required Widget child}) {
    if (!_isQuran || hasTabs) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      supportedDevices: const {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < _quranSwipeMinVelocity) return;
        final towardsStart = Directionality.of(context) == TextDirection.ltr
            ? velocity < 0
            : velocity > 0;
        final delta = towardsStart ? 1 : -1;
        if (!_hasQuranSequenceStep(delta)) return;
        _clearTextSelection();
        unawaited(_openQuranSequenceStep(delta));
      },
      child: child,
    );
  }

  /// How fast a sideways swipe has to end to turn the surah, so a slow,
  /// slightly diagonal scroll never does.
  static const double _quranSwipeMinVelocity = 350;

  bool _hasQuranSequenceStep(int delta) {
    final juz = widget.portion?.juz;
    if (juz != null) {
      final next = juz + delta;
      return next >= 1 && next <= allJuz().length;
    }
    final surah = _surahNumber;
    return surah != null && surahInfoFor(surah + delta) != null;
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

    final colors = ShiaColors.of(context);
    Widget action(
      BuildContext sheetContext, {
      required OutlineGlyph glyph,
      required String label,
      required VoidCallback onTap,
      bool filled = false,
      bool first = false,
      bool last = false,
    }) =>
        CardListRow(
          first: first,
          last: last,
          leading: OutlineIcon(glyph,
              size: 22, color: colors.accent, strokeWidth: 1.9, filled: filled),
          title: Text(label),
          onTap: () {
            Navigator.pop(sheetContext);
            onTap();
          },
        );

    await showAdaptiveSheet<void>(
      context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, SheetPresentation.inDialogOf(sheetContext) ? 20 : 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  '${surahInfoFor(surah)?.englishName ?? surahTitle} $verse',
                  style: ShiaText.sectionTitle.copyWith(color: colors.text),
                ),
              ),
              // In paragraph mode there is no per-verse seal to long-press,
              // so the menu is where a verse's Imam Ali (as) or Imam
              // al-Mahdi (atfs) note is shown.
              if ((request.aliNote ?? request.mahdiNote) case final note?)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    note,
                    style: ShiaText.caption
                        .copyWith(fontSize: 14, color: colors.textMuted),
                  ),
                ),
              const SizedBox(height: 10),
              CardList(children: [
                action(
                  sheetContext,
                  first: true,
                  glyph: OutlineGlyph.bookmark,
                  filled: isSaved,
                  label: isSaved
                      ? context.l10n.quranRemoveFromSaved
                      : context.l10n.quranSaveVerse,
                  onTap: () => unawaited(_toggleSavedVerse(verse, text)),
                ),
                action(
                  sheetContext,
                  glyph: OutlineGlyph.copy,
                  label: context.l10n.quranCopyVerse,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text(context.l10n.quranCopiedVerse('$verse'))),
                    );
                  },
                ),
                action(
                  sheetContext,
                  glyph: OutlineGlyph.link,
                  label: context.l10n.quranCopyLink,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.quranLinkCopied)),
                    );
                  },
                ),
                action(
                  sheetContext,
                  last: true,
                  glyph: OutlineGlyph.share,
                  label: context.l10n.quranShareVerse,
                  onTap: () => unawaited(
                    SharePlus.instance
                        .share(ShareParams(text: '$text\n\n$link'))
                        .then((result) => _recordShareResult(result, 'verse')),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// Keeps [verse], or lets it go if it was already kept.
  ///
  /// A collection rather than a marker: saving a second verse of a surah does
  /// not displace the first, which is exactly what a [ZikrBookmark] would have
  /// done. Where the reader left off is tracked separately, per recitation
  /// track, by the recitation tracker.
  Future<void> _toggleSavedVerse(VerseKey verse, String text) async {
    final ayah = verse.ayah;
    if (ayah == null) return;

    final savedVerses = SavedVersesManager.instance;
    final wasSaved = _savedVerses.contains(verse);

    if (wasSaved) {
      await savedVerses.unsave(verse);
    } else {
      await savedVerses.save(
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
      RatingPromptService.recordPositiveAction('save_verse');
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
      SnackBar(
          content: Text(wasSaved
              ? context.l10n.quranRemovedVerse('$verse')
              : context.l10n.quranSavedVerse('$verse'))),
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
    ZikrTranslations.instance.removeListener(_loadTranslation);
    SavedVersesManager.instance.removeListener(_handleSavedVersesChanged);
    ZikrBookmarksManager.instance.removeListener(_handleBookmarksChanged);
    _progressSaveTimer?.cancel();
    _quranEndTimer?.cancel();
    _flushRecitationProgress();
    if (_pageRoute != null) {
      routeObserver.unsubscribe(this);
    }
    _counterOffset.dispose();
    _showCounter.dispose();
    _counterCount.dispose();
    _chromeIdleTimer?.cancel();
    _chromeVisible.dispose();
    _selectionFocusNode.dispose();
    _isDisposing = true;
    _maybeRecordCompletion();
    _completionTimer?.cancel();
    _readingProgress.removeListener(_maybeRecordCompletion);
    _readingProgress.removeListener(_maybeMarkQuranEndReached);
    _readingProgress.dispose();
    _currentVerse.dispose();
    syncZikrWakelockPreference(owner: this, isActive: false);
    // After _maybeRecordCompletion above, so a completion recorded on the way
    // out is already pending when leaving the reader puts it to the user.
    RatingPromptService.readerClosed();
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

  /// Rebuilds only when the set of verses changed, not for a re-save that
  /// only refreshed an excerpt.
  void _handleSavedVersesChanged() {
    if (!mounted) return;
    final previous = _savedVerses;
    _loadSavedVerses();
    if (!setEquals(previous, _savedVerses)) setState(() {});
  }

  void _loadSavedVerses() {
    if (!_isQuran) return;
    _savedVerses = {
      for (final saved in SavedVersesManager.instance.state.verses.values)
        saved.verse,
    };
  }

  void _loadSavedBookmark() {
    // A portion is not a document bookmarks can be stored against.
    if (widget.portion != null) return;

    // Opened with somewhere to go - a track's resume card, a verse link - a
    // surah leaves any bookmark alone: see [_consumeLegacyQuranBookmark].
    if (_isQuran && _initialVerse != null) return;

    final bookmark = ZikrBookmarksManager.instance.bookmarkFor(_bookmarkUid);
    if (bookmark == null) return;

    _savedBookmark = bookmark;
    if (_isQuran) _consumeLegacyQuranBookmark();

    _selectedZikrTabIndex = bookmark.tabIndex;
    _currentTabScrollOffsets[bookmark.tabIndex] = bookmark.scrollOffset;
  }

  /// Retires a bookmark left on a surah from before it opened in Quran mode.
  ///
  /// Quran mode has no bookmark button - a recitation track keeps the place on
  /// its own - so a bookmark carried over from the flat reader could be drawn
  /// but never moved or removed. It is honoured once instead: this visit lands
  /// on it and shows the marker, and the stored record is deleted, so reading
  /// on from there is tracked like any other and the marker never comes back.
  ///
  /// Only reached on a plain open. Opened for a specific verse, the bookmark
  /// would be neither landed on nor noticed, so it is kept for a later visit.
  void _consumeLegacyQuranBookmark() {
    unawaited(ZikrBookmarksManager.instance.remove(_bookmarkUid));
  }

  /// Follows the bookmark when it changes from outside this page - moved,
  /// placed or removed on another device, or arriving once bookmarks finish
  /// loading. Only the marker follows: the page stays where the reader is.
  void _handleBookmarksChanged() {
    if (!mounted) return;
    final next = ZikrBookmarksManager.instance.bookmarkFor(_bookmarkUid);
    final current = _savedBookmark;
    if (next?.updatedAt == current?.updatedAt &&
        next?.lineIndex == current?.lineIndex &&
        next?.tabIndex == current?.tabIndex) {
      return;
    }
    setState(() {
      _savedBookmark = next;
    });
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

  /// Accumulates scroll deltas so the chrome only moves on a scroll the
  /// reader meant; see [ZikrChromeScrollTracker].
  final ZikrChromeScrollTracker _chromeScrollTracker =
      ZikrChromeScrollTracker();

  /// Slides the chrome away as the reader moves down the text and back when
  /// they scroll up. Held open while the player is showing: hiding transport
  /// controls part-way through a half-hour recitation would strand them.
  ///
  /// Driven by [ScrollUpdateNotification]'s deltas rather than
  /// [UserScrollNotification]'s direction, which reverses on the smallest
  /// wobble and so made the bars flicker mid-read.
  ///
  /// The reading content is a [ListView] nested inside the tab [PageView], so
  /// its scroll notifications arrive here having already bubbled past the
  /// PageView - which, being itself a [Scrollable], bumps [depth] to 1 on the
  /// way through. Gating on `depth == 0` (as the counter FAB's old idle timer
  /// effectively assumed nothing nested) discarded every one of them, so the
  /// chrome never moved on a real read. The tracker gates on axis instead,
  /// which reads correctly regardless of nesting and as a side effect also
  /// ignores the PageView's own horizontal swipes between tabs.
  bool _handleScrollNotification(ScrollNotification notification) {
    // Ahead of the chrome logic and its guards: a selection has to be dropped
    // on every scroll the reader drives, not only the ones that also move the
    // bars.
    if (notification is UserScrollNotification &&
        shouldClearSelectionForScroll(notification.direction)) {
      _clearTextSelection();
    }

    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      _chromeScrollTracker.reset();
      return false;
    }
    if (notification is! ScrollUpdateNotification) return false;
    if (_showAudioPlayer || !_focusModeEnabled) return false;

    final delta = notification.scrollDelta;
    if (delta == null) return false;

    final visible = _chromeScrollTracker.update(
      axis: notification.metrics.axis,
      delta: delta,
      outOfRange: notification.metrics.outOfRange,
      chromeVisible: _chromeVisible.value,
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

  /// Drops any live text selection.
  ///
  /// A [SelectionArea] holds its handles and its toolbar against the
  /// [Selectable]s the selection was made in, and asks them for their geometry
  /// again on every rebuild of the overlay. The reading column is a lazily
  /// built [ListView] inside the tab [PageView], so those Selectables are
  /// disposed the moment their line leaves the list's cache or their tab is
  /// swiped away - and a selection that outlives them leaves the overlay
  /// reading an edge that is no longer in the tree, which is where the
  /// framework's null checks fire (flutter/flutter#124078, #123378). Dropping
  /// the selection wherever the text under it is about to change keeps the two
  /// in step.
  ///
  /// Unfocusing rather than reaching into the region's state: losing focus is
  /// already how [SelectableRegion] clears itself, and the focus manager
  /// applies the change in a microtask, so this is safe to call from a scroll
  /// notification that arrives mid-layout.
  void _clearTextSelection() {
    if (!_selectionFocusNode.hasFocus) return;
    _selectionFocusNode.unfocus();
  }

  /// Brings the chrome back and restarts the idle clock - called on any tap
  /// on the page, not just on either bar itself, so a reader is never left
  /// having to guess where to tap to get it back.
  void _revealChrome() {
    _setChromeVisible(true);
    _scheduleChromeIdleHide();
  }

  /// Where the current touch went down, and whether it has since travelled
  /// far enough to be a scroll rather than a tap. Tracked by hand instead of
  /// with a [GestureDetector]: the reading text is inside a [SelectionArea],
  /// whose own recognisers would compete for the tap in the arena and swallow
  /// it, and this listener must never take a gesture away from them.
  Offset? _chromePointerDownPosition;
  bool _chromePointerMoved = false;

  void _handleChromePointerDown(PointerDownEvent event) {
    _chromePointerDownPosition = event.position;
    _chromePointerMoved = false;
  }

  void _handleChromePointerMove(PointerMoveEvent event) {
    final downPosition = _chromePointerDownPosition;
    if (downPosition == null || _chromePointerMoved) return;
    if ((event.position - downPosition).distance > kTouchSlop) {
      _chromePointerMoved = true;
    }
  }

  void _handleChromePointerCancel(PointerCancelEvent event) {
    _chromePointerDownPosition = null;
    _chromePointerMoved = false;
  }

  /// True when the touch that just ended was a tap in place rather than the
  /// beginning of a scroll. Clears the tracking either way.
  bool _consumeChromeTap() {
    final wasTap = _chromePointerDownPosition != null && !_chromePointerMoved;
    _chromePointerDownPosition = null;
    _chromePointerMoved = false;
    return wasTap;
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
        onClose: () => _setCounterVisibility(false),
      ),
    );
  }

  String _currentWebRoutePath() {
    final dataSlug = normalizeSlug(zikrData?['slug']?.toString() ?? '');
    final cachedSlug = itemSlugs[widget.item.uid];

    return buildZikrDeepLinkPath(
      uid: widget.item.uid,
      slug: dataSlug.isNotEmpty ? dataSlug : cachedSlug,
    );
  }

  String? _currentShareSlug() {
    final dataSlug = normalizeSlug(zikrData?['slug']?.toString() ?? '');
    final cachedSlug = itemSlugs[widget.item.uid];

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

  /// Vertical space the tools capsule reserves, when it exists at all - its
  /// own height and its offset from the bottom, plus a small gap so the
  /// counter panel does not sit flush against it.
  double _counterBottomInset(BuildContext context, bool showActionBar) {
    if (!showActionBar) return 0;
    return floatingBottomOffset(context) + ZikrActionBar.barHeight + 8;
  }

  Future<void> _initializePageData() async {
    final portion = widget.portion;
    if (portion != null) {
      // Already assembled in memory - there is nothing to fetch, and nothing
      // to write back either.
      _applyZikrData(portion.toZikrData());
      return;
    }

    final loaded = await _loadZikrDataFromAssets();
    if (!loaded) _markZikrDataUnavailable();
  }

  /// Loads this zikr's translation into the reader's translation language,
  /// and again whenever that language changes. A juz has no single content
  /// file to translate, so it stays in English.
  Future<void> _loadTranslation() async {
    if (widget.portion != null) return;
    final translation = await ZikrTranslations.instance
        .documentFor(_contentUid, DefaultAssetBundle.of(context));
    if (!mounted) return;
    // Rebuilt even when the document is unchanged: the title comes from the
    // language's index, which may have changed on its own.
    setState(() => _translation = translation);
  }

  void _applyZikrData(Map<String, dynamic> data) {
    setState(() {
      _didFailToLoadZikrData = false;
      zikrData = data;
    });
    _scheduleCurrentWebRouteSync(replace: true);
  }

  Future<bool> _loadZikrDataFromAssets() async {
    // A retired uid (dropped from the corpus, usually for duplicating
    // another entry) has no assets/zikr/<uid> file of its own any more, but
    // a favorite or shared link saved before the retirement still carries
    // its bare uid - see retired_zikr_redirects.dart. Load the uid it was
    // folded into instead of failing outright, and land on the specific tab
    // its content now lives in, if any.
    final redirect = retiredZikrRedirects[widget.item.getFirstUId()];
    final assetUid = _contentUid;
    try {
      final bundle = DefaultAssetBundle.of(context);
      // Recordings live in their own index, not the content file; have it
      // ready by the time the page first draws, so Listen does not pop in.
      final audioLoaded = ZikrAudioIndex.instance.load(bundle);
      final translationLoaded = _loadTranslation();
      final raw = await bundle.loadString('assets/zikr/$assetUid');
      await audioLoaded;
      await translationLoaded;
      final decoded = json.decode(raw);
      if (decoded is! Map) {
        return false;
      }

      final document = await applyQuranScript(
          assetUid, Map<String, dynamic>.from(decoded), bundle);
      if (!mounted) return true;
      _applyZikrData(document);
      if (redirect?.tabIndex != null) {
        _selectedZikrTabIndex = redirect!.tabIndex! + 1;
      }
      return true;
    } catch (e) {
      debugPrint('Error loading zikr from assets: $e');
      return false;
    }
  }

  /// Swaps a surah or juz into the script the current [arabicFont] calls for,
  /// when it was loaded under another font: the reader has just switched
  /// fonts, and the text has to follow.
  Future<void> _reloadQuranScriptIfStale() async {
    final data = zikrData;
    if (data == null || data[quranScriptFontKey] == arabicFont) return;

    final portion = widget.portion;
    if (portion != null) {
      final reloaded =
          await loadJuzPortion(portion.juz, DefaultAssetBundle.of(context));
      if (!mounted || reloaded == null) return;
      _applyZikrData(reloaded.toZikrData());
      return;
    }

    if (surahForUid(_contentUid) == null) return;
    await _loadZikrDataFromAssets();
  }

  /// The uid whose content (and recordings) this page shows: the target of
  /// an alias key or of a retired uid's redirect.
  String get _contentUid {
    final uid = widget.item.getFirstUId();
    return retiredZikrRedirects[uid]?.targetUid ?? uid;
  }

  void _markZikrDataUnavailable() {
    if (!mounted || zikrData != null) return;
    setState(() {
      _didFailToLoadZikrData = true;
    });
  }

  /// The title shown in the app bar and used for a new reminder's default
  /// text — translated into the reader's translation language when it has
  /// been, the English title otherwise.
  String _currentDisplayTitle() =>
      ZikrTranslations.instance.titleFor(widget.item.uid) ?? _englishTitle();

  /// The zikr's English title — the saved zikr's own title, falling back to
  /// what the caller opened this page with. What gets stored and reported,
  /// so a bookmark or correction names the zikr the same way whatever
  /// language it was made in.
  String _englishTitle() {
    final savedTitle = zikrData?['title']?.toString().trim() ?? '';
    return savedTitle.isNotEmpty ? savedTitle : widget.item.title;
  }

  /// The merits note, in the reader's translation language when it has been
  /// translated.
  String _merits() {
    final translated = _translation?.merits?.trim();
    if (translated != null && translated.isNotEmpty) return translated;
    return zikrData?['merits']?.toString().trim() ?? '';
  }

  Future<void> _openReminderForm() async {
    unawaited(AnalyticsService.feature(
      'zikr_reminder_entry_point_opened',
      label: 'Set Reminder opened from a zikr',
      parameters: {'zikr_uid': _bookmarkUid},
    ));
    await pushPageRoute(
      context,
      ZikrReminderFormPage(
        initialZikrUid: _bookmarkUid,
        initialTitle: _currentDisplayTitle(),
      ),
    );
  }

  void _showMeritsSheet() {
    final merits = _merits();
    final meritsDirection = _translation?.merits?.trim().isNotEmpty == true
        ? _translation!.language.textDirection
        : TextDirection.ltr;
    if (merits.isEmpty) return;

    // The revamp's sheet on a phone, a centred dialog from tablet width up.
    showRevampSheet<void>(
      context,
      title: context.l10n.zikrMerits,
      builder: (context) {
        final colors = ShiaColors.of(context);
        final style = ShiaText.body.copyWith(height: 1.45, color: colors.text);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SelectableText.rich(
            textDirection: meritsDirection,
            buildZikrTextSpanWithLinks(
              rawLine: merits,
              baseStyle: style,
              linkStyle: style.copyWith(
                color: colors.accent,
                decoration: TextDecoration.underline,
              ),
              onLinkTap: (href) => _handleZikrLinkTap(href),
            ),
          ),
        );
      },
    );
  }

  List<String> _buildVisibleTabContents() {
    final primary = zikrData?['data']?.toString() ?? '';
    final rawTabs = zikrData?['tabs'];
    final extraTabs = rawTabs is List
        ? rawTabs.map((tab) => tab?.toString() ?? '')
        : const <String>[];

    return buildVisibleZikrTabContents(
      primary: primary,
      extraTabs: extraTabs,
    );
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
      final header = _translation?.lineFor(lines.first) ?? lines.first;
      return ZikrContentParser.parseLineSegments(header)
          .map((segment) => segment.text)
          .join()
          .trim();
    }
    return context.l10n.zikrPartNumber(index + 1);
  }

  /// Copy, for a surah in QuranWBW's script: its pause marks and medallions
  /// are private-use glyphs that paste as boxes anywhere but the reader.
  void _copyQuranWbwSelection(SelectableRegionState selectableRegionState) {
    final text = (_lastSelectedText ?? '')
        .split('\n')
        .map(indoPakPlainText)
        .join('\n');
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    selectableRegionState.hideToolbar();
  }

  Future<void> _shareZikrText({
    required String title,
    required String deepLink,
    required Rect sharePositionOrigin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        text: '$title\n$deepLink',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    _recordShareResult(result, 'zikr');
  }

  /// Only a share that actually went somewhere counts as a positive action -
  /// backing out of the share sheet says nothing about the app.
  void _recordShareResult(ShareResult result, String what) {
    if (result.status != ShareResultStatus.success) return;
    RatingPromptService.recordPositiveAction('share_$what');
  }

  Future<void> _shareCurrentZikr() async {
    if (_isSharingZikr) return;

    final title = zikrData?['title']?.toString().trim().isNotEmpty == true
        ? zikrData!['title'].toString().trim()
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
          arabicFontFamily: arabicFontFamilyOf(zikrData),
          translation: _translation,
          titleDirection: ZikrTranslations.instance.titleFor(widget.item.uid) ==
                  null
              ? TextDirection.ltr
              : ZikrTranslations.instance.language.textDirection,
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

      final result = await SharePlus.instance.share(
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
      _recordShareResult(result, 'zikr');
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
    final tabIndex = position.tabIndex;
    final previousScrollOffset = _currentTabScrollOffsets[tabIndex];
    _currentTabScrollOffsets[tabIndex] = position.scrollOffset;
    _currentTabMaxScrollExtents[tabIndex] = position.maxScrollExtent;
    final lineIndex = position.bookmarkLineIndex ?? position.lineIndex;
    if (lineIndex != null) {
      _currentTabTopLineIndexes[tabIndex] = lineIndex;
    }

    // Measured by words where the viewer could lay the tab out, by pixels
    // only as a fallback - see [zikrContentFractionAbove].
    final seen = position.seenFraction ??
        zikrTabSeenFraction(
          scrollOffset: position.scrollOffset,
          maxScrollExtent: position.maxScrollExtent,
          viewportDimension: position.viewportDimension,
        );
    if (seen > (_tabSeenFractions[tabIndex] ?? 0)) {
      _tabSeenFractions[tabIndex] = seen;
      _maybeRecordCompletion();
    }

    _currentTabScrollFractions[tabIndex] = zikrSmoothedTabFraction(
      rawFraction: position.progressFraction ??
          zikrTabScrollFraction(
            scrollOffset: position.scrollOffset,
            maxScrollExtent: position.maxScrollExtent,
          ),
      scrollOffset: position.scrollOffset,
      previousScrollOffset: previousScrollOffset,
      previousDisplayedFraction: _currentTabScrollFractions[tabIndex],
    );
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
    // A surah's bookmark has already been retired - writing it back would
    // bring it back on the next visit.
    if (_isQuran) return;
    unawaited(ZikrBookmarksManager.instance.save(upgraded));
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

  /// Progress through the open tab alone.
  ///
  /// Not through the whole zikr: a multi-tab zikr is usually alternatives
  /// (forms of a ziyarah, one taqeeb per prayer) or independent steps, so
  /// counting every tab before this one as read put someone opening the
  /// fourth form of a ziyarah at 75% before they had read a word, and left
  /// someone who had recited the first form at 25% - never "Completed" -
  /// although [_maybeRecordCompletion] had counted it as recited.
  double _computeReadingProgress() {
    final tabCount = _readingStats.tabs.length;
    if (tabCount == 0) return 0;

    final tabIndex = _selectedZikrTabIndex.clamp(0, tabCount - 1);
    // An unmeasured tab has not been laid out yet, so nothing is read.
    return _currentTabMaxScrollExtents.containsKey(tabIndex)
        ? (_currentTabScrollFractions[tabIndex] ?? 0.0)
        : 0.0;
  }

  /// Moves the bookmark to [lineIndex] of the tab it is already in, after
  /// the reader dragged its "Bookmarked" label there.
  Future<void> _handleBookmarkMoved(int lineIndex) async {
    final existing = _savedBookmark;
    if (existing == null || existing.lineIndex == lineIndex) return;

    final moved = existing.movedTo(
      lineIndex: lineIndex,
      updatedAt: DateTime.now().toUtc(),
    );
    setState(() {
      _savedBookmark = moved;
    });
    await ZikrBookmarksManager.instance.save(moved);
    unawaited(ZikrBookmarkStore.instance.markMoveHintSeen());
    unawaited(AnalyticsService.feature(
      'zikr_bookmark_moved',
      label: 'Bookmark moved',
      parameters: {'zikr_uid': _bookmarkUid},
    ));
  }

  /// Tells the reader, the first time they save a bookmark, that its label
  /// can be dragged to move it - and never again after that.
  ///
  /// Held back, without using up the one showing, in Arabic-only paragraph
  /// view: the marker there is an icon inside the text with no handle to
  /// drag, so the tip would point at nothing.
  Future<void> _showBookmarkMoveHintOnce() async {
    if (isArabicOnlyReadingView) return;
    if (!await ZikrBookmarkStore.instance.claimMoveHint()) return;
    if (!mounted) return;
    final color = Theme.of(context).colorScheme.onInverseSurface;
    // The drag-handle icon sits mid-sentence, wherever a translation puts it.
    const iconMarker = '\u0000';
    final hint = context.l10n.zikrBookmarkMoveHint(iconMarker).split(iconMarker);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: hint.first),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.drag_indicator, size: 18, color: color),
              ),
              if (hint.length > 1) TextSpan(text: hint.sublist(1).join()),
            ],
          ),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _toggleBookmark({
    required String pageTitle,
    required List<String> tabContents,
    required int selectedTabIndex,
  }) async {
    final existingBookmark = _savedBookmark;
    if (existingBookmark != null) {
      await ZikrBookmarksManager.instance.remove(_bookmarkUid);
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

    await ZikrBookmarksManager.instance.save(bookmark);
    if (!mounted) return;
    setState(() {
      _savedBookmark = bookmark;
    });
    RatingPromptService.recordPositiveAction('bookmark');
    await _showBookmarkMoveHintOnce();
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
    _previousBrowserUri ??= widget.returnBrowserUri ?? Uri.base;
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
    // The selection toolbar lives in the enclosing Overlay, so it would
    // otherwise float over the route that just covered this one.
    _clearTextSelection();
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

  /// Asks for an optional note, then files a mistake report quoting whatever
  /// the reader had selected when they tapped context.l10n.zikrSuggestCorrection in the
  /// selection toolbar - the same place Copy and Select All live, so
  /// flagging a typo needs nothing more than the press-and-hold a reader
  /// already reaches for to copy the text in the first place.
  Future<void> _reportZikrMistake() async {
    final selection = _lastSelectedText?.trim() ?? '';
    final note = await _promptForMistakeNote(selection);
    if (note == null || !mounted) return; // Cancelled.

    unawaited(AnalyticsService.feature(
      'zikr_mistake_reported',
      label: 'Correction suggested',
      parameters: {'zikr_uid': widget.item.getFirstUId()},
    ));

    final submitted = await MistakeReportService.submit(
      zikrUid: widget.item.getFirstUId(),
      zikrTitle: _englishTitle(),
      selectedText: selection,
      note: note,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(submitted
            ? context.l10n.zikrReportThanks
            : context.l10n.zikrReportFailed),
      ),
    );
  }

  /// The dialog itself: shows what was selected, if anything, and a box for
  /// an optional note on what's actually wrong with it. Returns the note
  /// text on Submit (empty string counts as "no note"), or null on Cancel -
  /// distinct from an empty note, which is what tells [_reportZikrMistake]
  /// whether to file the report at all.
  Future<String?> _promptForMistakeNote(String selection) {
    final noteController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.zikrSuggestCorrection),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selection.isNotEmpty) ...[
                Text(
                  context.l10n.zikrSelectedText,
                  style: Theme.of(dialogContext).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogContext)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    selection,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: noteController,
                autofocus: true,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.l10n.zikrCorrectionHint,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(noteController.text.trim()),
            child: Text(context.l10n.commonSubmit),
          ),
        ],
      ),
    );
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

  /// The top bar, sliding up as one with the rest of the reading chrome
  /// whenever [_chromeVisible] hides it. Like every other bar it floats over
  /// the reading list, so hiding it only uncovers text.
  ///
  /// The status bar band stays put on the reader's ground, so the system
  /// icons never end up over the reading text; the bar slides up beneath it.
  Widget _buildTopChrome(Widget bar) {
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    const slideExtent = ReaderTopBar.barHeight;
    return ValueListenableBuilder<bool>(
      valueListenable: _chromeVisible,
      builder: (context, visible, child) => TweenAnimationBuilder<double>(
        tween: Tween(end: visible ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, shown, _) => SizedBox(
          height: statusBarHeight + slideExtent,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: statusBarHeight - slideExtent * (1 - shown),
                // Fully hidden, the bar must not take taps meant for the
                // text now showing where it was.
                child: IgnorePointer(ignoring: shown == 0, child: child),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: statusBarHeight,
                child: const ReaderGlassBand(child: SizedBox.expand()),
              ),
            ],
          ),
        ),
      ),
      child: bar,
    );
  }

  /// What the top bar's sub-line says: where the reader is in a surah and
  /// which reading track it counts towards ("Verse 255 of 286 · My
  /// reading"), which part of a multi-part zikr is open ("Part 3 of 4"), or
  /// how far through a zikr they are ("12% read" - before they start, how
  /// long it takes).
  Widget _buildSubtitle({
    required int tabCount,
    required int selectedTabIndex,
    required String readingTimeLabel,
  }) {
    final l10n = context.l10n;
    if (_isQuran) {
      final label = widget.recitationLabel?.trim();
      final track = label == null ||
              label.isEmpty ||
              label == unlabeledRecitationLabel
          ? l10n.quranMyReading
          : label;
      return ValueListenableBuilder<VerseKey?>(
        valueListenable: _currentVerse,
        builder: (context, verse, _) {
          final ayah = verse?.ayah;
          final count = _surahNumber == null ? null : ayahCountOf(_surahNumber!);
          final String position;
          if (ayah != null && widget.portion == null && count != null) {
            position = l10n.readerVerseOf(ayah, count);
          } else if (ayah != null) {
            position = l10n.readerVerse('$verse');
          } else if (count != null) {
            position = l10n.quranVerseCount(count);
          } else {
            return Text(track);
          }
          return Text(l10n.readerSubtitleWithTrack(position, track));
        },
      );
    }
    if (tabCount > 1) {
      return Text(l10n.readerPartOf(selectedTabIndex + 1, tabCount));
    }
    return ValueListenableBuilder<double>(
      valueListenable: _readingProgress,
      builder: (context, progress, _) {
        if (_completedTabs.contains(selectedTabIndex)) {
          return Text(l10n.zikrProgressCompleted);
        }
        final percent = (progress.clamp(0.0, 1.0) * 100).floor();
        return Text(
            percent == 0 ? readingTimeLabel : l10n.readerPercentRead(percent));
      },
    );
  }

  /// What the top bar's heart keeps on web: the zikr or surah as the lists
  /// name it. None for a juz, which is not one entry of any list.
  UniversalData? get _favoriteData {
    if (widget.portion != null) return null;
    return UniversalData(widget.item.uid, widget.item.title, 0);
  }

  /// The top bar's round action on the right: the reminder bell, which
  /// replaced the heart there (favourites are still kept from the lists'
  /// own hearts) and is the reader's one way to set a reminder.
  ///
  /// The heart on web: ZikrReminderService.rescheduleAll() no-ops under
  /// kIsWeb (flutter_local_notifications has no web target), so a reminder
  /// set there would silently never fire. Settings hides its whole "Zikr
  /// Reminders" entry point on web for the same reason.
  Widget? _buildTopBarAction(BuildContext context) {
    if (kIsWeb) {
      final favorite = _favoriteData;
      return favorite == null
          ? null
          : FavoriteHeartButton(favorite: favorite, round: true);
    }
    return RoundIconButton(
      label: context.l10n.readerSetReminder,
      icon: OutlineIcon(OutlineGlyph.bell,
          size: 20, color: ShiaColors.of(context).accent),
      onPressed: () => unawaited(_openReminderForm()),
    );
  }

  /// The Text & reading sheet.
  void _openTextSheet() {
    unawaited(showReaderTextSheet(context, onChanged: refreshState));
  }

  @override
  Widget build(BuildContext context) {
    final hasMerits = _merits().isNotEmpty;
    final tabContents = _buildVisibleTabContents();
    final pageTitle = _currentDisplayTitle();
    final hasAnyContent =
        tabContents.any((content) => content.trim().isNotEmpty);
    final selectedTabIndex = _clampedSelectedTabIndex(tabContents);
    _refreshReadingStats(
      tabContents,
      hideHeaderLine: tabContents.length > 1,
    );
    final audioTracks = widget.portion != null
        ? const <ZikrAudioTrack>[]
        : ZikrAudioIndex.instance.tracksFor(_contentUid);
    final showActionBar = zikrData != null;
    final hasTabs = tabContents.length > 1;
    // Independent of showActionBar - a zikr with no estimable reading time
    // (still loading) can lack one while the other still applies.
    final showProgressBar = _readingStats.hasContent;
    // The open tab's time, like the progress beside it - see
    // [_computeReadingProgress].
    final readingTimeLabel = zikrReadingTimeLabel(
      _readingStats.tabs.length > 1 &&
              selectedTabIndex < _readingStats.tabs.length
          ? _readingStats.tabs[selectedTabIndex].duration
          : _readingStats.duration,
    );
    final colors = ShiaColors.of(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    final statusBarHeight = mediaPadding.top;
    final bottomOffset = floatingBottomOffset(context);
    // How far the chrome reaches in from each edge while it is showing.
    final topChromeExtent = statusBarHeight + ReaderTopBar.barHeight;
    final bottomChromeExtent =
        showActionBar ? bottomOffset + ZikrActionBar.barHeight : mediaPadding.bottom;

    return SelectionArea(
      focusNode: _selectionFocusNode,
      onSelectionChanged: (content) => _lastSelectedText = content?.plainText,
      contextMenuBuilder: (context, selectableRegionState) {
        final buttonItems = <ContextMenuButtonItem>[
          for (final item in selectableRegionState.contextMenuButtonItems)
            if (item.type == ContextMenuButtonType.copy &&
                arabicFontFamilyOf(zikrData) == quranWbwFontFamily)
              item.copyWith(
                onPressed: () => _copyQuranWbwSelection(selectableRegionState),
              )
            else
              item,
          ContextMenuButtonItem(
            label: context.l10n.zikrSuggestCorrection,
            onPressed: () {
              selectableRegionState.hideToolbar();
              unawaited(_reportZikrMistake());
            },
          ),
        ];
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: buttonItems,
        );
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: colors.readerGround,
        body: Listener(
          // Covers the whole reading area, not just either bar: after the
          // idle timeout has hidden the chrome, the reader should not have to
          // hunt for exactly where to tap to get it back.
          //
          // On the finished tap, not on pointer-down: a scroll starts with a
          // pointer-down too, so revealing there flashed both bars onto the
          // screen at the start of every single scroll gesture, for the
          // scroll itself to slide them straight back out.
          onPointerDown: _handleChromePointerDown,
          onPointerMove: _handleChromePointerMove,
          onPointerCancel: _handleChromePointerCancel,
          onPointerUp: (_) {
            if (_consumeChromeTap()) _revealChrome();
          },
          behavior: HitTestBehavior.translucent,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: Stack(
              children: [
                // The reading list runs the full height of the screen, and
                // every bar - app bar, progress strip, action bar, tab strip -
                // floats over it. What keeps the text clear of them is
                // scrolling padding inside the list, not a fixed inset
                // around it, so showing or hiding the chrome only covers or
                // uncovers text at the edges and never relays the list out:
                // the line being read stays exactly where it is.
                Positioned.fill(
                  child: zikrData == null
                      ? Padding(
                          padding: EdgeInsets.only(top: topChromeExtent),
                          child: Center(
                            child: _didFailToLoadZikrData
                                ? Text(context.l10n.zikrUnableToOpen)
                                : const CircularProgressIndicator(),
                          ),
                        )
                      : !hasAnyContent
                          ? Padding(
                              padding: EdgeInsets.only(top: topChromeExtent),
                              child:
                                  Center(child: Text(context.l10n.zikrComingSoon)),
                            )
                          : _withQuranSwipe(
                              hasTabs: tabContents.length > 1,
                              child: ResponsiveContent(
                                maxWidth: readerColumnWidth(context),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: ZikrContentViewerWidget(
                                  translation: _translation,
                                  tabContents: tabContents,
                                  selectedTabIndex: selectedTabIndex,
                                  onTabChanged: (index) {
                                    // A swiped tab change is already
                                    // covered by the scroll handler; this
                                    // is the tab header being tapped,
                                    // which animates the pager without
                                    // ever reporting a user scroll.
                                    _clearTextSelection();
                                    _startTabDwell(index);
                                    setState(() {
                                      _selectedZikrTabIndex = index;
                                    });
                                    _updateReadingProgress();
                                    _maybeRecordCompletion();
                                  },
                                  hasMerits: hasMerits,
                                  onShowMerits: _showMeritsSheet,
                                  onLinkTap: _handleZikrLinkTap,
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
                                  onAyahAction:
                                      _isQuran ? _showAyahActions : null,
                                  arabicFontFamily: arabicFontFamilyOf(zikrData),
                                  onBookmarkLineResolved:
                                      _handleBookmarkLineResolved,
                                  onBookmarkMoved:
                                      _isQuran ? null : _handleBookmarkMoved,
                                  footer: _buildQuranSequenceFooter(),
                                  listPadding: EdgeInsets.only(
                                    top: topChromeExtent + 16,
                                    bottom: bottomChromeExtent + 16,
                                  ),
                                  tabStripTop: topChromeExtent,
                                  collapsedTopInset: statusBarHeight,
                                  chromeVisible: _chromeVisible,
                                  tabStripFooter: hasTabs && showProgressBar
                                      ? ReaderProgressLine(
                                          progress: _readingProgress)
                                      : null,
                                ),
                              ),
                            ),
                ),
                // The counter keeps the area below the top bar as its frame,
                // as it had when an app bar of the same height sat above the
                // body, so a position saved before still means the same
                // place.
                Positioned(
                  left: 0,
                  right: 0,
                  top: topChromeExtent,
                  bottom: 0,
                  child: LayoutBuilder(
                    builder: (context, bodyConstraints) => Stack(
                      children: [
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
                                      child: _buildCounterCard(),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (showActionBar)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _chromeVisible,
                      builder: (context, visible, child) => AnimatedSlide(
                        // Slides out of frame rather than collapsing: the
                        // capsule floats over the reading area, so its size
                        // never affects the text's layout either way.
                        offset: visible ? Offset.zero : const Offset(0, 1),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: child,
                      ),
                      child: SizedBox(
                        height: bottomOffset + ZikrActionBar.barHeight + 62,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: BottomFade(readerGround: true),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: bottomOffset,
                              child: ValueListenableBuilder<bool>(
                                valueListenable: _showCounter,
                                builder: (context, counterVisible, _) =>
                                    ZikrActionBar(
                                  hasAudio: audioTracks.isNotEmpty,
                                  // Reading Quran there is no place to mark:
                                  // a recitation track resumes on its own,
                                  // and keeping a verse is the per-verse
                                  // menu's job.
                                  showBookmark: !_isQuran,
                                  canBookmark: hasAnyContent,
                                  isBookmarked: _savedBookmark != null,
                                  canShare: !_isSharingZikr,
                                  isCounterVisible: counterVisible,
                                  onBookmark: () => _toggleBookmark(
                                    pageTitle: pageTitle,
                                    tabContents: tabContents,
                                    selectedTabIndex: selectedTabIndex,
                                  ),
                                  onShare: _shareFromActionBar,
                                  onListen: _openAudioPlayer,
                                  onText: _openTextSheet,
                                  onCounter: _toggleCounterFromActionBar,
                                  player: _showAudioPlayer &&
                                          audioTracks.isNotEmpty
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
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _buildTopChrome(
                    ReaderTopBar(
                      title: pageTitle,
                      subtitle: zikrData == null
                          ? null
                          : _buildSubtitle(
                              tabCount: tabContents.length,
                              selectedTabIndex: selectedTabIndex,
                              readingTimeLabel: readingTimeLabel,
                            ),
                      trailing: _buildTopBarAction(context),
                      // With parts, the line runs under their chips instead.
                      progress: showProgressBar && !hasTabs
                          ? _readingProgress
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void refreshState() {
    // Reading settings - font, size, transliteration - relay every line of the
    // column out from under whatever was selected in it.
    _clearTextSelection();
    syncZikrWakelockPreference(owner: this, isActive: _isCurrentRoute);
    _applyFocusModePreference();
    setState(() {});
    unawaited(_reloadQuranScriptIfStale());
  }
}
