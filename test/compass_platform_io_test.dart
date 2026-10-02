import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/compass_reading.dart';
import 'package:shia_companion/services/compass_platform_io.dart';

void main() {
  group('iosHeadingEventToReading', () {
    test('uses true north when Core Location has it', () {
      final reading = iosHeadingEventToReading([280.0, 281.5, 15.0])!;
      expect(reading.reference, NorthReference.geographic);
      expect(reading.headingDegrees, 281.5);
      expect(reading.accuracyDegrees, 15.0);
    });

    test('falls back to magnetic north when true heading is -1', () {
      // What an iPhone reports when its location manager is not also running
      // location updates — every sample, before the fix for issue #62.
      final reading = iosHeadingEventToReading([272.0, -1.0, 20.0])!;
      expect(reading.reference, NorthReference.magnetic);
      expect(reading.headingDegrees, 272.0);
    });

    test('drops samples Core Location marks invalid', () {
      expect(iosHeadingEventToReading([272.0, 273.0, -1.0]), isNull);
    });

    test('treats a zero accuracy as unknown rather than perfect', () {
      expect(
          iosHeadingEventToReading([10.0, 11.0, 0.0])!.accuracyDegrees, isNull);
    });

    test('accepts integers off the channel', () {
      final reading = iosHeadingEventToReading([90, -1, 10])!;
      expect(reading.headingDegrees, 90.0);
    });

    test('ignores malformed events', () {
      expect(iosHeadingEventToReading(null), isNull);
      expect(iosHeadingEventToReading(42), isNull);
      expect(iosHeadingEventToReading([1.0, 2.0]), isNull);
      expect(iosHeadingEventToReading([-1.0, -1.0, 5.0]), isNull);
      expect(iosHeadingEventToReading([double.nan, -1.0, 5.0]), isNull);
    });
  });

  group('androidCompassEventToReading', () {
    test('normalizes signed westerly headings', () {
      final reading = androidCompassEventToReading(
        CompassEvent.fromList([-90.0, -90.0, 3.0]),
      )!;
      expect(reading.reference, NorthReference.magnetic);
      expect(reading.headingDegrees, 270.0);
      expect(reading.accuracyDegrees, 3.0);
    });

    test('drops a missing heading', () {
      expect(
        androidCompassEventToReading(CompassEvent.fromList(null)),
        isNull,
      );
    });
  });
}
