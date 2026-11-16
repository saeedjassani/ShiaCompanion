import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/models/recitation_tracker_state.dart';
import 'package:shia_companion/services/recitation_tracker_manager.dart';
import 'package:shia_companion/utils/quran_index.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

import 'ui/firebase_test_doubles.dart';

RecitationEntry _read(int day, int surah, int from, int to) => RecitationEntry(
  id: 'r_${day}_$surah',
  label: unlabeledRecitationLabel,
  recitedAt: DateTime(2026, 11, day, 21),
  surah: surah,
  fromAyah: from,
  toAyah: to,
);

void main() {
  // A guest who read juz 1 and on through the old "My reading" card, with
  // Ya-Sin read from the list on one of the evenings.
  final guest = RecitationTrackerState({
    for (final read in [
      _read(1, 1, 1, 7),
      _read(2, 2, 1, 80),
      _read(3, 36, 1, 83),
      _read(3, 2, 80, 141),
      _read(4, 2, 142, 200),
    ])
      read.id: read,
  });

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'recitation_tracker_guest': jsonEncode(guest.toJson()),
    });
    await SP.init();
    await setUpFirebaseForRenderTests();
  });

  test(
    'reading straight through "My reading" moves into a Khatm, once',
    () async {
      final manager = RecitationTrackerManager.instance;
      await manager.loadRecitations(force: true);
      var state = manager.state;

      expect(state.labels, ['My reading']);
      final target = state.resumeTargetFor('My reading');
      expect(target.verse, const VerseKey(2, 201));
      expect(target.inJuz, isFalse);
      // Its progress is what was read in order - not Ya-Sin.
      expect(state.trackIncludes('My reading', const VerseKey(2, 141)), isTrue);
      expect(state.trackIncludes('My reading', const VerseKey(36, 1)), isFalse);
      // The everyday reading keeps all of its history.
      expect(state.sessionsByLabel[unlabeledRecitationLabel], 5);
      expect(manager.myReadingPortNotice, 'My reading');

      // Loading again moves nothing twice.
      await manager.dismissMyReadingPortNotice();
      await manager.loadRecitations(force: true);
      state = manager.state;
      expect(state.labels, ['My reading']);
      expect(manager.myReadingPortNotice, isNull);
    },
  );

  test('Undo deletes the Khatm, and it is not made again', () async {
    final manager = RecitationTrackerManager.instance;
    await SP.prefs.setString(
      RecitationTrackerManager.myReadingPortNoticeKey,
      'My reading',
    );
    expect(manager.myReadingPortNotice, 'My reading');

    await manager.dismissMyReadingPortNotice(undo: true);
    expect(manager.state.labels, isEmpty);
    expect(manager.state.sessionsByLabel[unlabeledRecitationLabel], 5);

    await manager.loadRecitations(force: true);
    expect(manager.state.labels, isEmpty);
  });

  test(
    'once read in, Undo is gone: it would take that reading with it',
    () async {
      final manager = RecitationTrackerManager.instance;
      await manager.updateTrackSettings(
        'Kept',
        const RecitationTrackSettings(startAt: VerseKey(2, 201)),
      );
      await SP.prefs.setString(
        RecitationTrackerManager.myReadingPortNoticeKey,
        'Kept',
      );
      expect(manager.canUndoMyReadingPort('Kept'), isTrue);

      await manager.logRecitation(
        label: 'Kept',
        surah: 2,
        fromAyah: 201,
        toAyah: 220,
      );
      expect(manager.canUndoMyReadingPort('Kept'), isFalse);

      await manager.dismissMyReadingPortNotice(undo: true);
      expect(manager.myReadingPortNotice, isNull);
      expect(manager.state.labels, ['Kept']);
      expect(
        manager.state.resumeTargetFor('Kept').verse,
        const VerseKey(2, 220),
      );
    },
  );
}
