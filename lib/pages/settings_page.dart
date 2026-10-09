import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../services/activity_stats_store.dart';
import '../services/analytics_service.dart';
import '../services/audio_download_store.dart';
import '../services/content_request_service.dart';
import '../services/favorites_manager.dart';
import '../services/home_screen_widget_service.dart';
import '../services/location_service.dart';
import '../services/prayer_preferences_sync_service.dart';
import '../services/preferences_sync_service.dart';
import '../services/qaza_tracker_manager.dart';
import '../services/rating_prompt_service.dart';
import '../services/recitation_tracker_manager.dart';
import '../services/saved_verses_manager.dart';
import '../services/session_refresh_service.dart';
import '../services/zikr_bookmarks_manager.dart';
import '../theme/shia_colors.dart';
import '../utils/app_text_scale.dart';
import '../utils/external_launch.dart';
import '../utils/font_preferences.dart';
import '../utils/shared_preferences.dart';
import '../utils/sign_in_flow.dart';
import '../utils/theme_mode.dart';
import '../utils/widget_prayer_time_selection.dart';
import '../widgets/arabic_runs.dart';
import '../widgets/choice_sheet.dart';
import '../widgets/content_request_dialog.dart';
import '../services/zikr_translations.dart';
import '../widgets/language_settings.dart';
import '../widgets/outline_icon.dart';
import '../widgets/page_chrome.dart';
import '../widgets/reader_text_sheet.dart';
import '../widgets/theme_mode_picker.dart';
import '../widgets/widget_prayer_times_dialog.dart';
import '../widgets/zikr_reading_preferences.dart';
import 'about_page.dart';
import 'account_page.dart';
import 'city_picker.dart';
import 'downloaded_audio_page.dart';
import 'prayer_notifications_page.dart';
import 'scheduled_notifications_page.dart';
import 'zikr_reminders_page.dart';
import '../widgets/app_toast.dart';

/// Settings (docs/DESIGN_SPEC.md, "Settings"; mockups `Settings-A` and
/// `Settings-A-signedin`): the sign-in card first (what is at stake and the
/// sign-in buttons, or who is signed in and whether the backup is up to
/// date), then Appearance, Prayer times, Notifications, Reading, Offline
/// audio and Support as card lists of rows, each showing its current value.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.profile, this.checkBackup});

  /// Who is signed in; read from the signed-in Firebase user when null.
  final AccountProfile? profile;

  /// Resolves true once everything written so far has reached the backup.
  /// Asks Firestore when null; see [AccountPage.firestoreBackedUp].
  final Future<bool> Function()? checkBackup;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SignInProvider? _signingIn;

  /// Whether the signed-in user's backup is up to date; null while
  /// checking, or while signed out.
  bool? _backedUp;

  Future<void> _refreshAfterAuthChange() async {
    await SessionRefreshService.refreshSessionState();
    await FavoritesManager.instance.loadFavorites(force: true);
    await QazaTrackerManager.instance.loadQaza(force: true);
    await RecitationTrackerManager.instance.loadRecitations(force: true);
    await SavedVersesManager.instance.loadSavedVerses(force: true);
    await ZikrBookmarksManager.instance.loadBookmarks(force: true);
    await PreferencesSyncService.instance.pullOrSeed();
    await PrayerPreferencesSyncService.instance.pullOrSeed();
    // Not awaited: stats are already correct on this device, and a Firestore
    // write only completes once the server acknowledges it - on a slow
    // connection that would hold up this screen for nothing.
    unawaited(ActivityStatsStore.instance.pullAndMerge());
    await HomeScreenWidgetService.instance.publishAll();
    if (!mounted) return;
    setState(() {});
    unawaited(_checkBackup());
  }

  @override
  void initState() {
    super.initState();
    trackScreen('Settings Page');
    // For the size shown on the Downloaded recitations row.
    unawaited(AudioDownloadStore.instance.load());
    // The Location row reflects location status, which can also change from
    // the home page or an automatic refresh, so follow the service rather
    // than relying on this page's own taps to know when to redraw.
    LocationService.instance.addListener(_onLocationChanged);
    if (_showPrecisePrayerAlarmSetting) {
      unawaited(_refreshExactAlarmPermissionStatus());
    }
    unawaited(_checkBackup());
  }

  @override
  void dispose() {
    LocationService.instance.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  User? get _currentUser {
    try {
      return user ?? FirebaseAuth.instance.currentUser;
    } catch (_) {
      // No Firebase app (a test, or a web build that failed to start it).
      return user;
    }
  }

  Future<void> _checkBackup() async {
    if (widget.profile == null && _currentUser == null) return;
    setState(() => _backedUp = null);
    final backedUp =
        await (widget.checkBackup ?? AccountPage.firestoreBackedUp)();
    if (mounted) setState(() => _backedUp = backedUp);
  }

  bool get _showPrecisePrayerAlarmSetting =>
      shouldShowPrecisePrayerAlarmSetting(platform: defaultTargetPlatform);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final themeMode = context.watch<ThemeModeProvider>().themeMode;
    final textScale = context.watch<AppTextScaleProvider>().scale;
    final currentUser = _currentUser;
    final profile = widget.profile ??
        (currentUser == null ? null : AccountProfile.of(currentUser, l10n));
    final gutter = pageGutter(context, maxWidth: widePageWidth);

    // Account and the settings people come for first on the left, the
    // rest on the right, once a desktop has room for both.
    return LargeTitlePage(
      title: l10n.actionSettings,
      maxWidth: widePageWidth,
      slivers: [
        SliverPadding(
          padding: gutter.copyWith(bottom: 22),
          sliver: SliverToBoxAdapter(
            child: WideColumns(
              start: [
                profile == null
                    ? _SignInCard(signingIn: _signingIn, onSignIn: _signIn)
                    : _SignedInCard(
                        profile: profile,
                        backedUp: _backedUp,
                        onTap: _openAccountPage,
                      ),
                _SettingsGroup(
                  label: l10n.settingsSectionAppearance,
                  rows: [
                    if (appLanguageOffered())
                      _SettingsRow(
                        icon: const _RowGlyph(OutlineGlyph.globe),
                        title: l10n.settingsAppLanguage,
                        value: appLanguageValue(context),
                        onTap: () => pickAppLanguage(context),
                      ),
                    _SettingsRow(
                      icon: const _RowGlyph(OutlineGlyph.moon),
                      title: l10n.settingsTheme,
                      value: ThemeModeProvider.label(themeMode, l10n),
                      onTap: () => showThemeModePicker(context),
                    ),
                    _SettingsRow(
                      icon: const _RowLetters('ع', fontSize: 15),
                      title: l10n.settingsArabicFont,
                      subtitle: Text(
                        _bismillah,
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: arabicFont,
                          fontSize: 20,
                          height: 1.8,
                          color: ShiaColors.of(context).translation,
                        ),
                      ),
                      value: arabicFont,
                      onTap: _pickArabicFont,
                    ),
                    _SettingsRow(
                      icon: _RowLetters(l10n.textSizeGlyph, fontSize: 14),
                      title: l10n.settingsAppTextSize,
                      value: AppTextScaleProvider.label(textScale),
                      onTap: () => showAppTextSizeSheet(context),
                    ),
                  ],
                ),
                _SettingsGroup(
                  label: l10n.settingsSectionPrayerTimes,
                  rows: [
                    _SettingsRow(
                      icon: const _RowGlyph(OutlineGlyph.pin),
                      title: l10n.settingsLocation,
                      value: _locationValue(),
                      subtitle: _locationNote(),
                      busy: LocationService.instance.isRefreshing,
                      onTap: _chooseLocation,
                    ),
                    // Prayer notifications can't fire on the web.
                    if (!kIsWeb)
                      _SettingsRow(
                        icon: const _RowGlyph(OutlineGlyph.bell),
                        title: l10n.settingsAzan,
                        value: l10n.settingsAzanValue(
                            enabledPrayerNotificationNames(
                                    kPrayerNotificationList)
                                .length),
                        onTap: () async {
                          await showPrayerNotificationsPage(context);
                          if (mounted) setState(() {});
                        },
                      ),
                    _SettingsRow(
                      icon: const _RowGlyph(OutlineGlyph.calendar),
                      title: l10n.settingsAdjustHijriDate,
                      value: _hijriAdjustmentLabel(_savedHijriAdjustment()),
                      onTap: _pickHijriAdjustment,
                    ),
                    _SettingsRow(
                      icon: const _RowGlyph(OutlineGlyph.eye),
                      title: l10n.settingsPrayerTimesShown,
                      value: l10n.settingsPrayerTimesShownValue(
                          selectedWidgetPrayerTimes().length),
                      onTap: () async {
                        final changed =
                            await showWidgetPrayerTimesDialog(context);
                        if (changed && mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              ],
              end: [
                if (!kIsWeb)
                  _SettingsGroup(
                    label: l10n.settingsSectionNotifications,
                    rows: [
                      _SettingsRow(
                        icon: const _RowGlyph(OutlineGlyph.clock),
                        title: l10n.settingsZikrReminders,
                        onTap: () =>
                            pushPageRoute(context, const ZikrRemindersPage()),
                      ),
                      if (_showPrecisePrayerAlarmSetting)
                        _SettingsRow(
                          icon: const _RowGlyph(OutlineGlyph.alarm),
                          title: l10n.settingsPrecisePrayerAlarms,
                          value: canScheduleExactPrayerNotifications
                              ? l10n.settingsOn
                              : l10n.settingsOff,
                          subtitle: canScheduleExactPrayerNotifications
                              ? null
                              : Text(l10n.settingsPreciseAlarmsOff),
                          onTap: _requestPrecisePrayerAlarms,
                        ),
                      if (isUserAdmin)
                        _SettingsRow(
                          icon: const _RowGlyph(OutlineGlyph.bell),
                          title: l10n.settingsScheduledNotifications,
                          onTap: () => pushPageRoute(
                              context, ScheduledNotificationsPage()),
                        ),
                    ],
                  ),
                _SettingsGroup(
                  label: l10n.settingsSectionReading,
                  rows: [
                    _SettingsRow(
                      icon: const _RowGlyph(OutlineGlyph.lines),
                      title: l10n.readerTextSheetTitle,
                      subtitle: Text(_readingSummary(l10n)),
                      onTap: () => showReaderTextSheet(
                        context,
                        onChanged: () {
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                if (AudioDownloadStore.isSupported)
                  _SettingsGroup(
                    label: l10n.settingsSectionOfflineAudio,
                    rows: [
                      _SettingsRow(
                        icon: const _RowGlyph(OutlineGlyph.download),
                        title: l10n.settingsDownloadedRecitations,
                        valueListenable: AudioDownloadStore.instance,
                        valueBuilder: () {
                          final bytes =
                              AudioDownloadStore.instance.totalSavedBytes;
                          return bytes > 0 ? formatAudioBytes(bytes) : null;
                        },
                        onTap: () =>
                            pushPageRoute(context, const DownloadedAudioPage()),
                      ),
                    ],
                  ),
                _SettingsGroup(
                  label: l10n.settingsSectionSupport,
                  rows: [
                    // Not gated behind RatingPromptService.shouldAsk() at all -
                    // that cooldown is for the automatic pre-screen dialog on
                    // launch. This is the always-available door to the store,
                    // which openStoreListing() itself needs no quota for.
                    if (!kIsWeb)
                      _SettingsRow(
                        icon: const _RowGlyph(OutlineGlyph.star),
                        title: l10n.settingsRateApp,
                        onTap: () {
                          unawaited(RatingPromptService.openStoreListing());
                          unawaited(AnalyticsService.feature(
                            'rate_us_settings',
                            label: 'Rate us opened from Settings',
                          ));
                        },
                      ),
                    _SettingsRow(
                      icon: const _RowGlyph(OutlineGlyph.plus),
                      title: l10n.settingsRequestContent,
                      onTap: () => showContentRequestDialog(
                        context,
                        initialType: ContentRequestType.zikr,
                        source: 'settings',
                      ),
                    ),
                    _SettingsRow(
                      icon: const _RowGlyph(OutlineGlyph.mail),
                      title: l10n.settingsFeedback,
                      onTap: _sendFeedback,
                    ),
                    _SettingsRow(
                      icon: const _RowGlyph(OutlineGlyph.code),
                      title: l10n.settingsGithub,
                      onTap: _openGithub,
                    ),
                    _SettingsRow(
                      icon: const _RowGlyph(OutlineGlyph.info),
                      title: l10n.settingsAboutUs,
                      onTap: () => pushPageRoute(context, AboutPage()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: gutter,
          sliver: SliverToBoxAdapter(
            child: Text(
              '$appName $appVersion',
              textAlign: TextAlign.center,
              style: ShiaText.caption
                  .copyWith(color: ShiaColors.of(context).textMuted),
            ),
          ),
        ),
      ],
    );
  }

  static const String _bismillah = 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيْمِ';

  Future<void> _pickArabicFont() async {
    final l10n = context.l10n;
    final colors = ShiaColors.of(context);
    final picked = await showChoiceSheet<String>(
      context,
      title: l10n.settingsArabicFont,
      current: arabicFont,
      choices: [
        for (final font in FontPreferences.validFonts)
          Choice(
            font,
            font,
            sample: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(font == 'Scheherazade'
                    ? l10n.setupFontScheherazadeHint
                    : l10n.setupFontQalamHint),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    _bismillah,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: 24,
                      height: 1.9,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (picked == null || picked == arabicFont) return;
    await saveArabicFontChoice(picked);
    if (mounted) setState(() {});
  }

  String _readingSummary(AppLocalizations l10n) {
    final aids = [
      if (ReadingSwitch.transliteration.value &&
          ZikrTranslations.instance.isEnglish)
        l10n.readerTransliteration,
      if (ReadingSwitch.translation.value) l10n.readerTranslation,
    ];
    return l10n.settingsReadingSummary(
      arabicFontSize.toInt(),
      englishFontSize.toInt(),
      aids.isEmpty ? l10n.settingsReadingArabicOnly : aids.join(', '),
    );
  }

  Future<void> _chooseLocation() async {
    // The picker offers both ways: a city by name, or the phone's own
    // location (with its permission dialogs). The row redraws from the
    // service listener.
    await chooseCityFlow(context);
    if (!mounted) return;
    // Those diagnostic dialogs are all guarded on !kIsWeb, so on web a
    // failure would otherwise look like a dead tap.
    if (kIsWeb &&
        LocationService.instance.status == LocationRefreshStatus.failed) {
      showToast(LocationService.instance.failureMessage);
    }
  }

  String? _locationValue() {
    final savedCity = city?.trim();
    return savedCity == null || savedCity.isEmpty ? null : savedCity;
  }

  /// A line under Location only when something needs saying: it is
  /// updating, the last update failed, or there is no location yet.
  Widget? _locationNote() {
    final location = LocationService.instance;
    final l10n = context.l10n;
    if (location.isRefreshing) return Text(l10n.settingsLocationUpdating);
    // Survives the snackbar, and covers the paths that show no dialog at all.
    if (location.status == LocationRefreshStatus.failed) {
      return Text(l10n.settingsLocationFailed(location.failureMessage));
    }
    if (_locationValue() == null) {
      return Text(l10n.settingsLocationUpdatePrompt);
    }
    return null;
  }

  int _savedHijriAdjustment() {
    final adjustment = SP.prefs.getInt('adjust_hijri_date') ?? hijriDate;
    return adjustment.clamp(-3, 3);
  }

  String _hijriAdjustmentLabel(int adjustment) {
    final l10n = context.l10n;
    if (adjustment == 0) return l10n.settingsHijriNone;
    final days = adjustment.abs();
    return adjustment > 0
        ? l10n.settingsHijriAhead(days)
        : l10n.settingsHijriBehind(days);
  }

  Future<void> _pickHijriAdjustment() async {
    final picked = await showChoiceSheet<int>(
      context,
      title: context.l10n.settingsAdjustHijriDate,
      body: context.l10n.settingsHijriBody,
      current: _savedHijriAdjustment(),
      choices: [
        for (var days = -3; days <= 3; days++)
          Choice(days, _hijriAdjustmentLabel(days)),
      ],
    );
    if (picked == null || picked == _savedHijriAdjustment()) return;
    hijriDate = picked;
    await SP.prefs.setInt('adjust_hijri_date', hijriDate);
    await SP.prefs.remove('prayerTimes');
    unawaited(PreferencesSyncService.instance.pushHijriDate());
    await HomeScreenWidgetService.instance.publishTodaysRecitations();
    await HomeScreenWidgetService.instance.publishCalendar();
    if (mounted) setState(() {});
  }

  Future<void> _refreshExactAlarmPermissionStatus() async {
    await refreshExactPrayerAlarmPermissionStatus();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _requestPrecisePrayerAlarms() async {
    if (flutterLocalNotificationsPlugin == null) {
      showToast(context.l10n.settingsNotificationsUnavailable);
      return;
    }

    final alreadyEnabled = await refreshExactPrayerAlarmPermissionStatus();
    if (!mounted) return;
    if (alreadyEnabled) {
      setState(() {});
      showToast(context.l10n.settingsPreciseAlarmsAlreadyOn);
      return;
    }

    final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.l10n.settingsPreciseAlarmsDialogTitle),
            content: Text(context.l10n.settingsPreciseAlarmsDialogBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.commonOpenSettings),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldOpenSettings) return;

    final granted = await requestExactPrayerAlarmPermissionIfNeeded();
    await refreshExactPrayerAlarmPermissionStatus();
    if (canScheduleExactPrayerNotifications) {
      await setUpNotifications();
    }

    if (!mounted) return;
    setState(() {});
    showToast(granted || canScheduleExactPrayerNotifications
        ? context.l10n.settingsPreciseAlarmsEnabled
        : context.l10n.settingsPreciseAlarmsNotEnabled);
  }

  Future<void> _sendFeedback() async {
    final launched =
        await launchSupportEmail(subject: "Shia Companion | Feedback");
    if (launched) {
      unawaited(AnalyticsService.feature(
        'feedback_email_opened',
        label: 'Feedback email opened',
      ));
      return;
    }
    if (mounted) {
      showToast(context.l10n.settingsNoEmailApp);
    }
  }

  Future<void> _openGithub() async {
    unawaited(AnalyticsService.feature(
      'github_settings',
      label: 'GitHub opened from Settings',
    ));
    final launched = await launchExternalUri(githubRepoUri);
    if (!launched && mounted) {
      showToast(context.l10n.settingsGithubOpenFailed);
    }
  }

  Future<void> _signIn(SignInProvider provider) async {
    if (_signingIn != null) return;
    setState(() => _signingIn = provider);
    final signedIn = await signInFromButton(context, provider);
    if (signedIn != null) user = signedIn;
    if (mounted) setState(() => _signingIn = null);
    await _refreshAfterAuthChange();
  }

  // Logging out and deleting the account live on AccountPage; deleting
  // shares its confirmation and deletion with DeleteAccountPage, the page
  // Google Play's public account-deletion link opens.
  Future<void> _openAccountPage() async {
    await pushPageRoute(context, const AccountPage());
    if (!mounted) return;
    await _refreshAfterAuthChange();
  }
}

/// Opens the App text size sheet: a slider from 80% to 150%, applied to
/// every page as it moves and saved once it is let go.
Future<void> showAppTextSizeSheet(BuildContext context) {
  final l10n = context.l10n;
  return showRevampSheet<void>(
    context,
    title: l10n.settingsAppTextSize,
    builder: (context) {
      final provider = context.watch<AppTextScaleProvider>();
      final colors = ShiaColors.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(SliverCardList.radius),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.settingsAppTextSizeSubtitle,
                  style: ShiaText.body.copyWith(color: colors.text),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Text(l10n.textSizeLetter,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textMuted)),
                    ),
                    Expanded(
                      child: Slider(
                        min: AppTextScaleProvider.minScale,
                        max: AppTextScaleProvider.maxScale,
                        divisions: AppTextScaleProvider.divisions,
                        value: provider.scale,
                        label: AppTextScaleProvider.label(provider.scale),
                        semanticFormatterCallback: AppTextScaleProvider.label,
                        onChanged: provider.setScale,
                        // Persist and count once per gesture, not per frame.
                        onChangeEnd: (_) {
                          unawaited(provider.save());
                          unawaited(AnalyticsService.feature(
                            'app_text_scale_changed',
                            label: 'App text size changed',
                            parameters: {
                              'scale':
                                  AppTextScaleProvider.label(provider.scale),
                            },
                          ));
                        },
                      ),
                    ),
                    ExcludeSemantics(
                      child: Text(l10n.textSizeLetter,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: colors.textMuted)),
                    ),
                  ],
                ),
                Text(
                  AppTextScaleProvider.label(provider.scale),
                  textAlign: TextAlign.center,
                  style: ShiaText.secondary.copyWith(
                      fontWeight: FontWeight.w600, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// One group of rows under a small upper-case label.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.label, required this.rows});

  final String label;
  final List<_SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: GroupLabel(label),
        ),
        const SizedBox(height: 8),
        CardList(
          children: [
            for (final (i, row) in rows.indexed)
              _RowDivider(last: i == rows.length - 1, child: row),
          ],
        ),
      ],
    );
  }
}

/// The divider under a settings row, indented past its icon tile.
class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.last, required this.child});

  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (last) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 56),
          child: Container(height: 1, color: ShiaColors.of(context).divider),
        ),
      ],
    );
  }
}

/// A settings row: the 30 px icon tile, the title (and a line under it
/// where there is something to say), the current value in muted text and a
/// chevron. At least 52 px tall.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.subtitle,
    this.busy = false,
    this.valueListenable,
    this.valueBuilder,
  });

  final Widget icon;
  final String title;
  final VoidCallback onTap;
  final String? value;
  final Widget? subtitle;

  /// Shows a small spinner in place of the chevron.
  final bool busy;

  /// For a value that changes on its own (the downloads' size): rebuilt
  /// from [valueBuilder] whenever this notifies.
  final Listenable? valueListenable;
  final String? Function()? valueBuilder;

  @override
  Widget build(BuildContext context) {
    final valueListenable = this.valueListenable;
    if (valueListenable == null) return _row(context, value);
    return ListenableBuilder(
      listenable: valueListenable,
      builder: (context, _) => _row(context, valueBuilder?.call()),
    );
  }

  Widget _row(BuildContext context, String? value) {
    final colors = ShiaColors.of(context);
    final valueStyle = ShiaText.body.copyWith(color: colors.textMuted);

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 12, 6),
              child: Row(
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(
                    // The value keeps to one line whenever the title leaves
                    // it room, and is never squeezed below half the row;
                    // the title takes the rest and wraps only beside a long
                    // value.
                    child: LayoutBuilder(builder: (context, constraints) {
                      double valueWidth = 0;
                      if (value != null) {
                        // Measured in the styles the Text widgets end up
                        // with - merged over the inherited DefaultTextStyle,
                        // whose letter spacing ShiaText leaves alone - or the
                        // value comes out a hair too narrow and breaks
                        // mid-word ("Ligh/t").
                        final inherited = DefaultTextStyle.of(context).style;
                        double natural(String text, TextStyle style) {
                          final painter = TextPainter(
                            text: TextSpan(
                                text: text, style: inherited.merge(style)),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                            locale: Localizations.maybeLocaleOf(context),
                            maxLines: 1,
                          )..layout();
                          final width = painter.width.ceilToDouble() + 1;
                          painter.dispose();
                          return width;
                        }

                        final full = constraints.maxWidth;
                        final titleWidth = natural(title, ShiaText.body);
                        final room = full - 8 - titleWidth;
                        valueWidth = natural(value, valueStyle)
                            .clamp(0, room > full / 2 ? room : full / 2)
                            .clamp(0, full - 8)
                            .toDouble();
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(title,
                                    style: ShiaText.body
                                        .copyWith(color: colors.text)),
                                if (subtitle != null)
                                  DefaultTextStyle.merge(
                                    style: ShiaText.caption
                                        .copyWith(color: colors.textMuted),
                                    child: subtitle!,
                                  ),
                              ],
                            ),
                          ),
                          if (value != null) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: valueWidth,
                              child: Text(
                                value,
                                textAlign: TextAlign.end,
                                // One word too long for its room is cut
                                // short rather than split across lines.
                                maxLines: value.contains(' ') ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: valueStyle,
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                  ),
                  const SizedBox(width: 6),
                  SizedBox.square(
                    dimension: 16,
                    child: busy
                        ? CircularProgressIndicator(
                            strokeWidth: 2, color: colors.accent)
                        : OutlineIcon(OutlineGlyph.chevronRight,
                            size: 16, color: colors.chevron, strokeWidth: 2.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A settings row's tile: a 30 px rounded square in the accent with a
/// glyph in it.
class _RowGlyph extends StatelessWidget {
  const _RowGlyph(this.glyph);

  final OutlineGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return _RowTile(
      child:
          OutlineIcon(glyph, size: 18, color: colors.onAccent, strokeWidth: 2),
    );
  }
}

/// A settings row's tile with letters in it: "ع" for the Arabic font, "Aa"
/// (in the app language's own letters) for text size.
class _RowLetters extends StatelessWidget {
  const _RowLetters(this.letters, {required this.fontSize});

  final String letters;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return _RowTile(
      child: ExcludeSemantics(
        child: Text(
          letters,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: fontSize,
            height: 1,
            fontWeight: FontWeight.w700,
            color: colors.onAccent,
            // Qalam has Latin letters, so it would draw "Aa" as well.
            fontFamilyFallback:
                arabicRunSpans(letters) == null ? null : const ['Qalam'],
          ),
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ShiaColors.of(context).accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

/// Signed out: what is at stake, and the sign-in buttons.
class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.signingIn, required this.onSignIn});

  /// Which provider is signing in; null while neither is.
  final SignInProvider? signingIn;
  final ValueChanged<SignInProvider> onSignIn;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final busy = signingIn != null;
    // Apple's own guidance: a black button on light grounds, white on dark.
    final appleBackground = dark ? Colors.white : Colors.black;
    final appleForeground = dark ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.well,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: OutlineIcon(OutlineGlyph.cloudCheck,
                    size: 28, color: colors.accent, strokeWidth: 1.7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.settingsBackupTitle,
                    style: ShiaText.sectionTitle
                        .copyWith(height: 25 / 20, color: colors.text),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.settingsBackupBody,
            style: ShiaText.secondary
                .copyWith(height: 21 / 15, color: colors.translation),
          ),
          const SizedBox(height: 12),
          _SignInButton(
            label: l10n.setupContinueWithGoogle,
            busy: signingIn == SignInProvider.google,
            onPressed: busy ? null : () => onSignIn(SignInProvider.google),
            background: colors.surface,
            foreground: colors.text,
            outline: Color.lerp(colors.line, colors.chevron, 0.35),
            logo: Image.asset('assets/images/google_logo.png',
                width: 20, height: 20, excludeFromSemantics: true),
          ),
          if (appleSignInOffered) ...[
            const SizedBox(height: 12),
            _SignInButton(
              label: l10n.setupContinueWithApple,
              busy: signingIn == SignInProvider.apple,
              onPressed: busy ? null : () => onSignIn(SignInProvider.apple),
              background: appleBackground,
              foreground: appleForeground,
              logo: Image.asset('assets/images/apple_logo.png',
                  width: 20,
                  height: 20,
                  color: appleForeground,
                  excludeFromSemantics: true),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.settingsBackupFree,
            textAlign: TextAlign.center,
            style: ShiaText.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.logo,
    this.outline,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final Widget logo;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background,
        disabledForegroundColor: foreground.withValues(alpha: 0.6),
        elevation: 0,
        shape: StadiumBorder(
          side: outline == null ? BorderSide.none : BorderSide(color: outline!),
        ),
        textStyle: buttonTextStyle(context, ShiaText.body)
            .copyWith(fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            SizedBox.square(
              dimension: 20,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: foreground),
            )
          else
            logo,
          const SizedBox(width: 10),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

/// Signed in: who, and whether the backup is up to date. Opens Account.
class _SignedInCard extends StatelessWidget {
  const _SignedInCard({
    required this.profile,
    required this.backedUp,
    required this.onTap,
  });

  final AccountProfile profile;
  final bool? backedUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    final l10n = context.l10n;
    final backedUp = this.backedUp;
    final statusColor = backedUp == true ? colors.success : colors.textMuted;
    final email = profile.email;

    return Semantics(
      button: true,
      hint: l10n.accountOpen,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AccountAvatar(initials: profile.initials),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: ShiaText.cardTitle.copyWith(
                          fontSize: 19,
                          height: 24 / 19,
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                      if (email != null && email != profile.name) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: ShiaText.secondary
                              .copyWith(color: colors.textMuted),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          OutlineIcon(
                            backedUp == true
                                ? OutlineGlyph.cloudCheck
                                : OutlineGlyph.cloud,
                            size: 18,
                            color: statusColor,
                            strokeWidth: 1.9,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              switch (backedUp) {
                                null => l10n.accountBackupChecking,
                                true => l10n.accountBackedUp,
                                false => l10n.accountBackupOffline,
                              },
                              style: ShiaText.caption.copyWith(
                                fontSize: 14,
                                height: 18 / 14,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlineIcon(OutlineGlyph.chevronRight,
                    size: 16, color: colors.chevron, strokeWidth: 2.4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
