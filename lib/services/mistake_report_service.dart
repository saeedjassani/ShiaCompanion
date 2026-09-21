import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// One "Report Mistake" submission from the zikr reading page's selection
/// toolbar - the reader's highlighted text, whatever note they added, and
/// whether an admin has since acted on it.
@immutable
class MistakeReport {
  const MistakeReport({
    required this.id,
    required this.zikrUid,
    required this.zikrTitle,
    required this.selectedText,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String zikrUid;
  final String zikrTitle;
  final String selectedText;
  final String note;
  final String status;

  /// Null only for the instant between submitting and the server timestamp
  /// landing - `watchReports` never surfaces that window, since it reads
  /// back from Firestore rather than an optimistic local write.
  final DateTime? createdAt;

  bool get isResolved => status == 'resolved';

  /// Pure so it can be tested without a live [DocumentSnapshot]; [fromDoc]
  /// just unwraps one into the id/map pair this reads.
  static MistakeReport fromMap(String id, Map<String, dynamic> data) {
    return MistakeReport(
      id: id,
      zikrUid: data['zikrUid']?.toString() ?? '',
      zikrTitle: data['zikrTitle']?.toString() ?? '',
      selectedText: data['selectedText']?.toString() ?? '',
      note: data['note']?.toString() ?? '',
      status: data['status']?.toString() ?? 'open',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static MistakeReport fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data() ?? const {});
}

/// Submits and lists the reports readers file from the zikr page's selection
/// toolbar (see `ZikrPage._reportZikrMistake`), and lets an admin mark one
/// resolved from [MistakeReportsPage].
///
/// Reporting stays open to anyone rather than requiring sign-in: most readers
/// are never authenticated, the same reason `database.rules.json`'s usage
/// counters accept unauthenticated writes. `firestore.rules` is what actually
/// enforces the shape of a report and that only an admin can read the queue
/// back or change a status - this class trusts nothing about its own caller.
class MistakeReportService {
  const MistakeReportService._();

  static const String _collection = 'mistake_reports';

  /// Widget tests render pages without standing up Firebase; every entry
  /// point funnels through here so a missing app is a no-op rather than an
  /// unhandled async error, the same convention as [AnalyticsService].
  static bool get _isLive => Firebase.apps.isNotEmpty;

  static CollectionReference<Map<String, dynamic>> get _reports =>
      FirebaseFirestore.instance.collection(_collection);

  /// Files a report. Returns whether it actually reached Firestore, so the
  /// caller can tell the reader their report was not sent rather than
  /// thanking them for one that silently failed.
  static Future<bool> submit({
    required String zikrUid,
    required String zikrTitle,
    required String selectedText,
    String note = '',
  }) async {
    if (!_isLive) return false;
    try {
      await _reports.add({
        'zikrUid': zikrUid,
        'zikrTitle': zikrTitle,
        'selectedText': selectedText,
        'note': note,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (error) {
      debugPrint('Unable to submit mistake report: $error');
      return false;
    }
  }

  /// The admin queue, newest first. `firestore.rules` denies this entirely to
  /// anyone without the admin claim, so a non-admin listening here just gets
  /// a permission-denied stream error rather than an empty list.
  static Stream<List<MistakeReport>> watchReports() {
    return _reports
        .orderBy('createdAt', descending: true)
        .limit(300)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(MistakeReport.fromDoc).toList());
  }

  static Future<void> setResolved(String reportId, bool resolved) {
    return _reports.doc(reportId).update({
      'status': resolved ? 'resolved' : 'open',
      'resolvedAt': resolved ? FieldValue.serverTimestamp() : null,
    });
  }
}
