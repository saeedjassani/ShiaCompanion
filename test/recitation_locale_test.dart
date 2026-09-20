import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/services/recitation_recognizer.dart';

void main() {
  group('on a device, which really does enumerate its locales', () {
    test('prefers ar-SA, the variety closest to what is recited', () {
      expect(
        chooseArabicLocale(['en_US', 'ar_EG', 'ar_SA', 'fr_FR'], onWeb: false),
        'ar_SA',
      );
    });

    test('matches ar-SA however the platform punctuates and cases it', () {
      expect(chooseArabicLocale(['ar-SA'], onWeb: false), 'ar-SA');
      expect(chooseArabicLocale(['AR_sa'], onWeb: false), 'AR_sa');
    });

    test('takes any Arabic when ar-SA is not installed', () {
      // Better than English by a wide margin: an Arabic recogniser anywhere
      // still knows Quranic vocabulary.
      expect(chooseArabicLocale(['en_US', 'ar_EG'], onWeb: false), 'ar_EG');
      expect(chooseArabicLocale(['ar'], onWeb: false), 'ar');
    });

    test('says there is no Arabic rather than listening in another language',
        () {
      // Recitation transcribed as English matches nothing, so this has to be
      // reported, not papered over.
      expect(chooseArabicLocale(['en_US', 'fr_FR'], onWeb: false), isNull);
      expect(chooseArabicLocale([], onWeb: false), isNull);
    });

    test('is not fooled by a language that merely starts with the letters ar',
        () {
      expect(chooseArabicLocale(['arn_CL'], onWeb: false), isNull);
    });
  });

  group('on web, where there is nothing to enumerate', () {
    test('asserts ar-SA even though the browser lists no locales', () {
      // The Web Speech API has no locale list; the plugin returns at most the
      // browser's current lang. Scanning it for Arabic told every web user their
      // device had no Arabic recognition.
      expect(chooseArabicLocale([], onWeb: true), preferredArabicLocale);
    });

    test('asserts ar-SA over whatever single locale the browser reports', () {
      expect(chooseArabicLocale(['en-US'], onWeb: true), preferredArabicLocale);
    });

    test('asks for a tag the Web Speech API accepts', () {
      // lang takes a BCP-47 tag, which is hyphenated - not the underscored form
      // Android reports.
      expect(preferredArabicLocale, 'ar-SA');
      expect(preferredArabicLocale, isNot(contains('_')));
    });
  });

  group('the listen window', () {
    test('runs for at least thirty seconds', () {
      // Accuracy on recitation climbs steeply with clip length, and a reciter
      // should not have to hurry.
      expect(recitationListenFor.inSeconds, greaterThanOrEqualTo(30));
    });

    test('stays inside the session length iOS allows', () {
      expect(recitationListenFor.inSeconds, lessThan(60));
    });

    test('never ends on silence before the session does', () {
      // The Android footgun this guards: `pauseFor` is
      // EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, and the plugin only
      // sets that extra when it is non-null. Shortening this - or "tidying" it
      // to null, which hands endpointing back to Android's own sub-second
      // default - cuts reciters off mid-ayah.
      expect(
        recitationPauseFor.inMilliseconds,
        greaterThanOrEqualTo(recitationListenFor.inMilliseconds),
      );
    });
  });
}
