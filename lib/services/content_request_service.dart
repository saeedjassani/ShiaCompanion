import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// What a reader is asking to have added. Stored by [name], so renaming a
/// value forks the queue - add new values rather than renaming old ones.
enum ContentRequestType {
  zikr('Zikr'),
  book('Book');

  const ContentRequestType(this.label);

  final String label;

  /// Unknown or missing values fall back to [zikr] rather than throwing, so
  /// one odd document can't break the admin queue.
  static ContentRequestType fromName(String? name) {
    for (final type in values) {
      if (type.name == name) return type;
    }
    return zikr;
  }
}

/// One "Request a Zikr or Book" submission - what the reader wants added,
/// whatever details they gave, and whether an admin has since acted on it.
@immutable
class ContentRequest {
  const ContentRequest({
    required this.id,
    required this.type,
    required this.title,
    required this.details,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final ContentRequestType type;
  final String title;
  final String details;
  final String status;

  /// Null only for the instant before the server timestamp lands, the same
  /// as [MistakeReport.createdAt].
  final DateTime? createdAt;

  bool get isResolved => status == 'resolved';

  /// Pure so it can be tested without a live [DocumentSnapshot].
  static ContentRequest fromMap(String id, Map<String, dynamic> data) {
    return ContentRequest(
      id: id,
      type: ContentRequestType.fromName(data['type']?.toString()),
      title: data['title']?.toString() ?? '',
      details: data['details']?.toString() ?? '',
      status: data['status']?.toString() ?? 'open',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static ContentRequest fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data() ?? const {});
}

/// Submits and lists readers' requests for a zikr or book the app doesn't
/// have yet (see `showContentRequestDialog`), and lets an admin mark one
/// resolved from [ContentRequestsPage].
///
/// Like [MistakeReportService], submitting is open to anyone without sign-in,
/// and `firestore.rules` enforces the shape of a request and that only an
/// admin can read the queue back or change a status.
class ContentRequestService {
  const ContentRequestService._();

  static const String _collection = 'content_requests';

  /// Widget tests render pages without standing up Firebase, so a missing
  /// app is a no-op rather than an unhandled async error.
  static bool get _isLive => Firebase.apps.isNotEmpty;

  static CollectionReference<Map<String, dynamic>> get _requests =>
      FirebaseFirestore.instance.collection(_collection);

  /// Files a request. Returns whether it actually reached Firestore, so the
  /// caller can tell the reader it was not sent rather than thanking them.
  static Future<bool> submit({
    required ContentRequestType type,
    required String title,
    String details = '',
  }) async {
    if (!_isLive) return false;
    try {
      await _requests.add({
        'type': type.name,
        'title': title,
        'details': details,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (error) {
      debugPrint('Unable to submit content request: $error');
      return false;
    }
  }

  /// The admin queue, newest first. Non-admins get a permission-denied
  /// stream error from `firestore.rules`, not an empty list.
  static Stream<List<ContentRequest>> watchRequests() {
    return _requests
        .orderBy('createdAt', descending: true)
        .limit(300)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ContentRequest.fromDoc).toList());
  }

  static Future<void> setResolved(String requestId, bool resolved) {
    return _requests.doc(requestId).update({
      'status': resolved ? 'resolved' : 'open',
      'resolvedAt': resolved ? FieldValue.serverTimestamp() : null,
    });
  }
}
