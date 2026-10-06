import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../constants.dart';
import '../services/activity_stats_store.dart';
import '../services/account_service.dart';
import '../services/analytics_service.dart';
import '../services/content_request_service.dart';
import '../services/audio_download_store.dart';
import '../services/favorites_manager.dart';
import '../services/home_screen_widget_service.dart';
import '../services/location_service.dart';
import '../services/prayer_preferences_sync_service.dart';
import '../services/preferences_sync_service.dart';
import '../services/qaza_tracker_manager.dart';
import '../services/recitation_tracker_manager.dart';
import '../services/saved_verses_manager.dart';
import '../services/rating_prompt_service.dart';
import '../services/session_refresh_service.dart';
import '../services/zikr_bookmarks_manager.dart';
import '../utils/app_text_scale.dart';
import '../utils/external_launch.dart';
import '../utils/shared_preferences.dart';
import '../utils/theme_mode.dart';
import '../utils/widget_prayer_time_selection.dart';
import 'prayer_notifications_page.dart';
import '../widgets/content_request_dialog.dart';
import '../widgets/language_settings.dart';
import '../widgets/responsive_content.dart';
import '../widgets/theme_mode_picker.dart';
import '../widgets/widget_prayer_times_dialog.dart';
import '../widgets/zikr_reading_preferences.dart';
import 'about_page.dart';
import 'city_picker.dart';
import 'downloaded_audio_page.dart';
import 'account_page.dart';
import 'scheduled_notifications_page.dart';
import 'zikr_reminders_page.dart';
import '../l10n/l10n.dart';

class SettingsPage extends StatefulWidget {
  SettingsPage();

  @override
  _SettingsPageState createState() => new _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  _SettingsPageState();

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
  }

  @override
  void initState() {
    super.initState();
    trackScreen('Settings Page');
    // For the size shown on the Downloaded recitations row.
    unawaited(AudioDownloadStore.instance.load());
    // The refresh row reflects location status, which can also change from the
    // home page or an automatic refresh, so follow the service rather than
    // relying on this page's own taps to know when to redraw.
    LocationService.instance.addListener(_onLocationChanged);
    if (_showPrecisePrayerAlarmSetting) {
      unawaited(_refreshExactAlarmPermissionStatus());
    }
  }

  @override
  void dispose() {
    LocationService.instance.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  bool get _showPrecisePrayerAlarmSetting =>
      shouldShowPrecisePrayerAlarmSetting(platform: defaultTargetPlatform);

  @override
  Widget build(BuildContext context) {
    final themeModeProvider = Provider.of<ThemeModeProvider>(context);
    final textScaleProvider = Provider.of<AppTextScaleProvider>(context);
    final currentUser = user ?? _auth.currentUser;

    return ResponsiveScrollableContent(
      maxWidth: compactContentWidth,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildAccountHeader(context, currentUser),
          const SizedBox(height: 16),
          _buildSettingsSection(
            context,
            title: context.l10n.settingsSectionPrayerLocation,
            children: [
              ListTile(
                leading: const Icon(Icons.adjust),
                title: Text(context.l10n.settingsAdjustHijriDate),
                subtitle: Text(_hijriAdjustmentLabel()),
                onTap: () {
                  adjustHijriAlertDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.widgets),
                title: Text(context.l10n.settingsPrayerTimesShown),
                subtitle: Text(_widgetPrayerTimesSubtitle()),
                onTap: () async {
                  final changed = await showWidgetPrayerTimesDialog(context);
                  if (changed && mounted) setState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(context.l10n.settingsLocation),
                subtitle: Text(_locationSubtitle()),
                trailing: LocationService.instance.isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  // The picker offers both ways: a city by name, or the
                  // phone's own location (with its permission dialogs). The
                  // row redraws from the service listener.
                  await chooseCityFlow(context);
                  if (!mounted) return;
                  // Those diagnostic dialogs are all guarded on !kIsWeb, so on
                  // web a failure would otherwise look like a dead tap.
                  if (kIsWeb &&
                      LocationService.instance.status ==
                          LocationRefreshStatus.failed) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(LocationService.instance.failureMessage),
                    ));
                  }
                },
              ),
            ],
          ),
          if (!kIsWeb)
            _buildSettingsSection(
              context,
              title: context.l10n.settingsSectionNotifications,
              children: [
                // One door instead of four. "Azan Notifications", "Prayer
                // Notifications" and "Notification Sound" all wrote overlapping
                // state, and the master switch among them overwrote whatever
                // the other two had set. The sound picker and the sample
                // notification now live beside the prayers they belong to.
                ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: Text(context.l10n.settingsPrayerNotifications),
                  subtitle: Text(_prayerNotificationsSubtitle()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await showPrayerNotificationsPage(context);
                    if (mounted) setState(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(context.l10n.settingsZikrReminders),
                  subtitle: Text(
                      context.l10n.settingsZikrRemindersSubtitle),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ZikrRemindersPage(),
                      ),
                    );
                  },
                ),
                if (_showPrecisePrayerAlarmSetting)
                  ListTile(
                    leading: const Icon(Icons.alarm_on),
                    title: Text(context.l10n.settingsPrecisePrayerAlarms),
                    subtitle: Text(_precisePrayerAlarmSubtitle()),
                    onTap: _requestPrecisePrayerAlarms,
                  ),
                if (isUserAdmin)
                  ListTile(
                    leading: const Icon(Icons.notifications_active),
                    title: Text(context.l10n.settingsScheduledNotifications),
                    subtitle:
                        Text(context.l10n.settingsScheduledNotificationsSubtitle),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScheduledNotificationsPage(),
                        ),
                      );
                    },
                  ),
              ],
            ),
          _buildSettingsSection(
            context,
            title: context.l10n.settingsSectionAppearance,
            children: [
              if (AppLanguageTile.isOffered())
                const AppLanguageTile(leading: Icon(Icons.language)),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: Text(context.l10n.settingsTheme),
                subtitle: Text(ThemeModeProvider.label(
                    themeModeProvider.themeMode, context.l10n)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showThemeModePicker(context),
              ),
              ListTile(
                leading: const Icon(Icons.format_size),
                title: Text(context.l10n.settingsAppTextSize),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        context.l10n.settingsAppTextSizeSubtitle),
                    Slider(
                      activeColor: Theme.of(context).colorScheme.secondary,
                      min: AppTextScaleProvider.minScale,
                      max: AppTextScaleProvider.maxScale,
                      divisions: AppTextScaleProvider.divisions,
                      value: textScaleProvider.scale,
                      label:
                          AppTextScaleProvider.label(textScaleProvider.scale),
                      onChanged: textScaleProvider.setScale,
                      // Persist and count once per gesture, not per frame.
                      onChangeEnd: (_) {
                        unawaited(textScaleProvider.save());
                        unawaited(AnalyticsService.feature(
                          'app_text_scale_changed',
                          label: 'App text size changed',
                          parameters: {
                            'scale': AppTextScaleProvider.label(
                                textScaleProvider.scale),
                          },
                        ));
                      },
                    ),
                  ],
                ),
                trailing:
                    Text(AppTextScaleProvider.label(textScaleProvider.scale)),
              ),
            ],
          ),
          _buildSettingsSection(
            context,
            title: context.l10n.settingsSectionZikrReading,
            children: [
              ZikrReadingPreferencesControls(
                showLeadingIcons: true,
                onChanged: () {
                  if (!mounted) return;
                  setState(() {});
                },
              ),
            ],
          ),
          if (AudioDownloadStore.isSupported)
            _buildSettingsSection(
              context,
              title: context.l10n.settingsSectionOfflineAudio,
              children: [
                ListenableBuilder(
                  listenable: AudioDownloadStore.instance,
                  builder: (context, _) {
                    final bytes = AudioDownloadStore.instance.totalSavedBytes;
                    return ListTile(
                      leading: const Icon(Icons.download_for_offline_outlined),
                      title: Text(context.l10n.settingsDownloadedRecitations),
                      subtitle: Text(bytes > 0
                          ? context.l10n.settingsDownloadedRecitationsUsed(formatAudioBytes(bytes))
                          : context.l10n.settingsDownloadedRecitationsEmpty),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DownloadedAudioPage(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          _buildSettingsSection(
            context,
            title: context.l10n.settingsSectionSupport,
            children: [
              // Not gated behind RatingPromptService.shouldAsk() at all -
              // that cooldown is for the automatic pre-screen dialog on
              // launch. This is the always-available door to the store,
              // which openStoreListing() itself needs no quota for.
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.star_rate),
                  title: Text(context.l10n.settingsRateApp),
                  subtitle: Text(context.l10n.settingsRateAppSubtitle),
                  onTap: () {
                    unawaited(RatingPromptService.openStoreListing());
                    unawaited(AnalyticsService.feature(
                      'rate_us_settings',
                      label: 'Rate us opened from Settings',
                    ));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(context.l10n.settingsRequestContent),
                subtitle: Text(
                    context.l10n.settingsRequestContentSubtitle),
                onTap: () => showContentRequestDialog(
                  context,
                  initialType: ContentRequestType.zikr,
                  source: 'settings',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.feedback),
                title: Text(context.l10n.settingsFeedback),
                subtitle: Text(context.l10n.settingsFeedbackSubtitle),
                onTap: () {
                  _launchURL();
                },
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(context.l10n.settingsGithub),
                subtitle: Text(
                    context.l10n.settingsGithubSubtitle),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  unawaited(AnalyticsService.feature(
                    'github_settings',
                    label: 'GitHub opened from Settings',
                  ));
                  final launched = await launchExternalUri(githubRepoUri);
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.settingsGithubOpenFailed)),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: Text(context.l10n.settingsAboutUs),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AboutPage()),
                  );
                },
              ),
            ],
          ),
          _buildSettingsSection(
            context,
            title: context.l10n.settingsSectionAccount,
            children: _buildAccountActionTiles(currentUser),
          ),
          _buildVersionFooter(context),
        ],
      ),
    );
  }

  Widget _buildAccountHeader(BuildContext context, User? currentUser) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSignedIn = currentUser != null;

    // Signed in, the card opens Account, where logging out and deleting the
    // account live.
    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isSignedIn ? () => _openAccountPage(context) : null,
        child: Semantics(
          button: isSignedIn,
          hint: isSignedIn ? context.l10n.accountOpen : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: colorScheme.primary,
                  child: isSignedIn
                      ? Text(
                          _avatarLabel(currentUser),
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Icon(
                          Icons.account_circle,
                          color: colorScheme.onPrimary,
                          size: 30,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSignedIn
                            ? _accountTitle(currentUser)
                            : context.l10n.settingsNotSignedIn,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSignedIn
                            ? _accountSubtitle(currentUser)
                            : context.l10n.settingsSignInPrompt,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSignedIn)
                  Icon(
                    Icons.chevron_right,
                    color:
                        colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Material rather than a decorated Container: the rows inside are
          // ListTiles, which paint their background and ink splashes onto the
          // nearest Material ancestor. Behind a coloured Container those
          // effects are hidden, so taps landed with no ripple.
          Material(
            color: theme.cardColor,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              children: _withDividers(children),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    final dividedChildren = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        dividedChildren.add(const Divider(height: 1));
      }
      dividedChildren.add(children[index]);
    }
    return dividedChildren;
  }

  List<Widget> _buildAccountActionTiles(User? currentUser) {
    // Signed in, logging out and deleting the account are on Account.
    if (currentUser != null) return const [];

    return [
      ListTile(
        leading: Image.asset('assets/images/google_logo.png', height: 24.0),
        title: Text(context.l10n.settingsSignInGoogle),
        subtitle: Text(context.l10n.settingsSignInGoogleSubtitle),
        onTap: () async {
          await _signInWithGoogle();
          await _refreshAfterAuthChange();
        },
      ),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
        ListTile(
          // A flat black silhouette, so it has to be tinted rather than drawn
          // as-is: untinted it was black-on-dark and all but invisible in dark
          // mode. Apple's own guidance is the same — black mark on light
          // backgrounds, white on dark. The Google logo above is multicolour
          // and must not be recoloured, so it is left alone.
          leading: Image.asset(
            'assets/images/apple_logo.png',
            height: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          title: Text(context.l10n.settingsSignInApple),
          subtitle: Text(context.l10n.settingsSignInAppleSubtitle),
          onTap: () async {
            await _signInWithApple();
            await _refreshAfterAuthChange();
          },
        ),
    ];
  }

  Widget _buildVersionFooter(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        "$appName $appVersion",
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
        ),
      ),
    );
  }

  String _accountTitle(User? currentUser) {
    final displayName = currentUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) return email;

    return context.l10n.settingsSignedIn;
  }

  String _accountSubtitle(User? currentUser) {
    final email = currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) return email;

    return context.l10n.settingsSyncing;
  }

  String _avatarLabel(User? currentUser) {
    final displayName = currentUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      final parts = displayName
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .take(2)
          .toList();
      final initials = parts.map((part) => part.substring(0, 1)).join();
      if (initials.isNotEmpty) return initials.toUpperCase();
    }

    final email = currentUser?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }

    return "SC";
  }

  String _hijriAdjustmentLabel() {
    final adjustment = SP.prefs.getInt('adjust_hijri_date') ?? hijriDate;
    if (adjustment == 0) return context.l10n.settingsHijriNoAdjustment;

    final days = adjustment.abs();
    return adjustment > 0
        ? context.l10n.settingsHijriAhead(days)
        : context.l10n.settingsHijriBehind(days);
  }

  String _locationSubtitle() {
    final location = LocationService.instance;
    if (location.isRefreshing) {
      return context.l10n.settingsLocationUpdating;
    }
    // Survives the snackbar, and covers the paths that show no dialog at all.
    if (location.status == LocationRefreshStatus.failed) {
      return context.l10n.settingsLocationFailed(location.failureMessage);
    }

    final savedCity = city?.trim();
    if (savedCity == null || savedCity.isEmpty) {
      return context.l10n.settingsLocationUpdatePrompt;
    }
    if (location.isManual) {
      return context.l10n.settingsLocationManual(savedCity);
    }

    final updatedAt = location.updatedAt;
    if (updatedAt == null) {
      return context.l10n.settingsLocationSaved(savedCity);
    }
    return context.l10n
        .settingsLocationUpdated(savedCity, _locationAgeLabel(updatedAt));
  }

  String _locationAgeLabel(DateTime updatedAt) {
    final age = DateTime.now().difference(updatedAt);
    if (age.inMinutes < 1) return context.l10n.timeJustNow;
    if (age.inMinutes < 60) return context.l10n.timeMinutesAgo(age.inMinutes);
    if (age.inHours < 24) return context.l10n.timeHoursAgo(age.inHours);
    return context.l10n.timeDaysAgo(age.inDays);
  }

  adjustHijriAlertDialog(BuildContext context) {
    List<Widget> options = [];
    List<int> ints = [-3, -2, -1, 0, 1, 2, 3];
    int cur = SP.prefs.getInt('adjust_hijri_date') ?? 0;
    if (cur > 3 || cur < -3) {
      cur = 0;
    }

    for (int i = 0, n = ints.length; i < n; i++) {
      String option = context.l10n.settingsAdjustHijriBy(ints[i]);

      options.add(SimpleDialogOption(
        child: InkWell(
          onTap: () {
            hijriDate = ints[i];
            saveHijriDate();
            Navigator.pop(context);
          },
          child: Row(
            children: [
              Icon(
                cur == ints[i]
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(option)
            ],
          ),
        ),
      ));
    }

    SimpleDialog dialog = SimpleDialog(
      title: Text(context.l10n.settingsAdjustHijriDate),
      children: options,
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return dialog;
      },
    );
  }

  String _widgetPrayerTimesSubtitle() {
    final names =
        selectedWidgetPrayerTimes()
        .map((time) => localizedPrayerName(time.name, context.l10n))
        .join(', ');
    return context.l10n.settingsPrayerTimesShownSubtitle(names);
  }

  saveHijriDate() async {
    await SP.prefs.setInt('adjust_hijri_date', hijriDate);
    await SP.prefs.remove('prayerTimes');
    unawaited(PreferencesSyncService.instance.pushHijriDate());
    await HomeScreenWidgetService.instance.publishTodaysRecitations();
    await HomeScreenWidgetService.instance.publishCalendar();
    setState(() {});
  }

  String _prayerNotificationsSubtitle() {
    final enabled = enabledPrayerNotificationNames(kPrayerNotificationList);
    if (enabled.isEmpty) {
      return context.l10n.settingsPrayerNotificationsOff;
    }
    if (enabled.length == kPrayerNotificationList.length) {
      return context.l10n.settingsPrayerNotificationsAllOn(enabled.length);
    }
    return context.l10n.settingsPrayerNotificationsSomeOn(
        enabled.join(', '), enabled.length, kPrayerNotificationList.length);
  }

  String _precisePrayerAlarmSubtitle() {
    return canScheduleExactPrayerNotifications
        ? context.l10n.settingsPreciseAlarmsOn
        : context.l10n.settingsPreciseAlarmsOff;
  }

  Future<void> _refreshExactAlarmPermissionStatus() async {
    await refreshExactPrayerAlarmPermissionStatus();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _requestPrecisePrayerAlarms() async {
    if (flutterLocalNotificationsPlugin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsNotificationsUnavailable)),
      );
      return;
    }

    final alreadyEnabled = await refreshExactPrayerAlarmPermissionStatus();
    if (!mounted) return;
    if (alreadyEnabled) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsPreciseAlarmsAlreadyOn)),
      );
      return;
    }

    final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.l10n.settingsPreciseAlarmsDialogTitle),
            content: Text(
              context.l10n.settingsPreciseAlarmsDialogBody,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.commonCancel),
              ),
              ElevatedButton(
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted || canScheduleExactPrayerNotifications
              ? context.l10n.settingsPreciseAlarmsEnabled
              : context.l10n.settingsPreciseAlarmsNotEnabled,
        ),
      ),
    );
  }

  saveBooleanPref(String key, bool value) async {
    await SP.prefs.setBool(key, value);
    setState(() {});
  }

  saveDoublePref(String key, double value) async {
    await SP.prefs.setDouble(key, value);
    setState(() {});
  }

  Future<void> logOff() async {
    try {
      await AccountService.signOut();
      await _refreshAfterAuthChange();
    } catch (e) {
      debugPrint("Error : $e");
    }
  }

  Future<void> _launchURL() async {
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
      ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
        content: new Text(context.l10n.settingsNoEmailApp),
      ));
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        final authResult = await AccountService.signInWithGoogle();

        unawaited(AnalyticsService.feature(
          'account_signed_in',
          label: 'Signed in',
          parameters: {'method': 'google'},
        ));
        ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
          content: new Text(context.l10n.settingsLoginSuccessful),
        ));
        user = authResult.user;
        await _refreshAfterAuthChange();
      } else {
        logOff();
      }
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('User cancelled google sign-in');
        return;
      }
      debugPrint("Google sign-in failed: $error");
      _showGoogleSignInError(
          error.code == GoogleSignInExceptionCode.uiUnavailable
              ? context.l10n.settingsGoogleUnavailable
              : null);
    } on FirebaseAuthException catch (error) {
      // Web popup closed/replaced by the user - also a cancel, not a failure.
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        return;
      }
      debugPrint("Google sign-in failed: ${error.code} ${error.message}");
      _showGoogleSignInError(error.code == 'network-request-failed'
          ? context.l10n.commonNetworkError
          : null);
    } catch (error) {
      debugPrint("Google sign-in failed: $error");
      _showGoogleSignInError(null);
    }
  }

  void _showGoogleSignInError(String? message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message ??
          context.l10n.settingsGoogleFailed),
    ));
  }

  Future<void> _signInWithApple() async {
    try {
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        final rawNonce = generateNonce();
        final nonce = sha256.convert(utf8.encode(rawNonce)).toString();
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [],
          nonce: nonce,
        );
        final identityToken = appleCredential.identityToken;
        if (identityToken == null) {
          throw FirebaseAuthException(
            code: 'missing-apple-id-token',
            message: 'Apple did not return an identity token.',
          );
        }

        final credential = OAuthProvider('apple.com').credential(
          idToken: identityToken,
          rawNonce: rawNonce,
        );
        final authResult = await _auth.signInWithCredential(credential);
        unawaited(AnalyticsService.feature(
          'account_signed_in',
          label: 'Signed in',
          parameters: {'method': 'apple'},
        ));
        ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
          content: new Text(context.l10n.settingsLoginSuccessful),
        ));
        user = authResult.user;
        await _refreshAfterAuthChange();
      } else {
        logOff();
      }
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        debugPrint('User cancelled apple sign-in');
        return;
      }
      debugPrint("Apple sign-in failed: ${error.message}");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
        content: new Text(context.l10n.settingsAppleFailed),
      ));
    } catch (error) {
      debugPrint(error.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
        content: new Text(context.l10n.settingsAppleFailed),
      ));
    }
  }

  // Logging out and deleting the account live on AccountPage; deleting
  // shares its confirmation and deletion with DeleteAccountPage, the page
  // Google Play's public account-deletion link opens.
  Future<void> _openAccountPage(BuildContext context) async {
    await pushPageRoute(context, const AccountPage());
    if (!mounted) return;
    await _refreshAfterAuthChange();
  }
}
