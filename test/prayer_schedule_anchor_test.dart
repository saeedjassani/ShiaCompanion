import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/timezone_database.dart';
import 'package:timezone/timezone.dart' as tz;

/// The schedule anchor decides when up to twelve days of azan notifications get
/// torn down and rebuilt, so what counts as "moved" matters more here than
/// anywhere else in the app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    // The fingerprint names the local zone, which is otherwise uninitialised
    // outside the app.
    ensureTimeZoneDatabaseInitialized();
    tz.setLocalLocation(tz.UTC);
    lat = null;
    long = null;
  });

  Future<void> anchorAt(double latitude, double longitude) async {
    await SP.prefs.setDouble('prayer_schedule_anchor_lat', latitude);
    await SP.prefs.setDouble('prayer_schedule_anchor_long', longitude);
  }

  test('no location means nothing to reschedule for', () {
    expect(hasPrayerScheduleLocationMoved(), isFalse);
  });

  test('a first fix with no anchor counts as a move', () {
    lat = 32.6;
    long = 44.0;

    expect(hasPrayerScheduleLocationMoved(), isTrue);
  });

  test('GPS jitter is not a move', () async {
    await anchorAt(32.6, 44.0);
    // ~11 m, which used to trigger a full reschedule.
    lat = 32.6001;
    long = 44.0001;

    expect(hasPrayerScheduleLocationMoved(), isFalse);
  });

  test('jitter across a rounding boundary is still not a move', () async {
    // The bug a bucketed fingerprint would reintroduce: 32.604 and 32.606 round
    // to different 2dp buckets while being 200 m apart.
    await anchorAt(32.604, 44.0);
    lat = 32.606;
    long = 44.0;

    expect(hasPrayerScheduleLocationMoved(), isFalse);
  });

  test('jitter never accumulates into a move', () async {
    await anchorAt(32.6, 44.0);

    // Repeated readings drifting around the anchor are each compared to the
    // anchor, not to the previous reading, so they cannot ratchet.
    for (final drift in [0.002, -0.003, 0.004, -0.001, 0.003]) {
      lat = 32.6 + drift;
      long = 44.0 + drift;
      expect(hasPrayerScheduleLocationMoved(), isFalse);
    }
  });

  test('travelling far enough is a move', () async {
    await anchorAt(32.6, 44.0);
    // ~5 km north.
    lat = 32.645;
    long = 44.0;

    expect(hasPrayerScheduleLocationMoved(), isTrue);
  });

  test('the fingerprint no longer carries raw coordinates', () async {
    lat = 32.6;
    long = 44.0;
    final atOrigin = buildPrayerNotificationScheduleFingerprint();

    // Coordinates are tracked by the anchor and its distance threshold, so a
    // small move must not flip the fingerprint on its own.
    lat = 32.6001;
    long = 44.0001;

    expect(buildPrayerNotificationScheduleFingerprint(), atOrigin);
  });

  test('a stale schedule is detected when the device has really moved',
      () async {
    lat = 32.6;
    long = 44.0;
    await SP.prefs.setString(
      prayerNotificationScheduleFingerprintKey,
      buildPrayerNotificationScheduleFingerprint(),
    );
    await anchorAt(32.6, 44.0);

    expect(shouldRefreshPrayerNotificationSchedule(const []), isFalse);

    lat = 33.6;
    expect(shouldRefreshPrayerNotificationSchedule(const []), isTrue);
  });
}
