import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Universal Link association is published at both Apple endpoints', () {
    final rootAssociation = _readJson('web/apple-app-site-association');
    final wellKnownAssociation =
        _readJson('web/.well-known/apple-app-site-association');

    expect(wellKnownAssociation, rootAssociation);
    expect(
      rootAssociation,
      containsPair(
        'applinks',
        containsPair(
          'details',
          contains(
            containsPair(
              'appID',
              'F64WJ4KMVP.com.developer110.shiacompanion',
            ),
          ),
        ),
      ),
    );
  });

  test('Firebase serves both Apple association endpoints as JSON', () {
    final firebase = _readJson('firebase.json');
    final hosting = firebase['hosting'] as Map<String, dynamic>;
    final headers =
        (hosting['headers'] as List<dynamic>).cast<Map<String, dynamic>>();

    for (final source in const [
      '/apple-app-site-association',
      '/.well-known/apple-app-site-association',
    ]) {
      final rule = headers.singleWhere((entry) => entry['source'] == source);
      expect(
        rule['headers'],
        contains(
          allOf(
            containsPair('key', 'Content-Type'),
            containsPair('value', 'application/json'),
          ),
        ),
      );
    }
  });

  test('zikr SEO content stays covered until Flutter renders', () {
    final indexHtml = File('web/index.html').readAsStringSync();

    expect(indexHtml, contains("'flutter-first-frame'"));
    expect(indexHtml, contains('seoFallbackTimer'));
    expect(
      indexHtml,
      isNot(contains(
        "if (document.querySelector('.seo-zikr-content')) {\n"
        '        loadingShell.remove();',
      )),
    );
  });
}

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}
