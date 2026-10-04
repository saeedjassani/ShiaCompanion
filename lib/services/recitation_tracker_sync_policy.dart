import 'package:flutter/foundation.dart';

import '../models/recitation_tracker_state.dart';

enum RecitationOperationKind { add, remove, addLabel, setTrackSettings }

extension RecitationOperationKindInfo on RecitationOperationKind {
  String get key => switch (this) {
        RecitationOperationKind.add => 'add',
        RecitationOperationKind.remove => 'remove',
        RecitationOperationKind.addLabel => 'add_label',
        RecitationOperationKind.setTrackSettings => 'set_track_settings',
      };
}

RecitationOperationKind? recitationOperationKindFromKey(String key) {
  for (final kind in RecitationOperationKind.values) {
    if (kind.key == key) return kind;
  }
  return null;
}

/// A mutation queued while offline (or while a Firestore write is in
/// flight), replayed against the remote doc once it succeeds.
///
/// Every kind is naturally idempotent: an [add] replayed twice just sets the
/// same entry id twice, a [remove] replayed against an id that is already
/// gone is a no-op, [addLabel] replayed twice unions into the same set
/// entry, and [setTrackSettings] replayed twice writes the same settings. So unlike the qaza tracker's delta queue, this one needs
/// no separate merge arithmetic.
class PendingRecitationOperation {
  const PendingRecitationOperation({
    required this.id,
    required this.kind,
    this.entryId,
    this.entry,
    this.labelName,
    this.settings,
  });

  factory PendingRecitationOperation.add(RecitationEntry entry) {
    return PendingRecitationOperation(
      id: entry.id,
      kind: RecitationOperationKind.add,
      entryId: entry.id,
      entry: entry,
    );
  }

  factory PendingRecitationOperation.remove(String entryId) {
    return PendingRecitationOperation(
      id: '${entryId}_remove',
      kind: RecitationOperationKind.remove,
      entryId: entryId,
    );
  }

  factory PendingRecitationOperation.addLabel(String labelName) {
    return PendingRecitationOperation(
      id: 'add_label_$labelName',
      kind: RecitationOperationKind.addLabel,
      labelName: labelName,
    );
  }

  /// One queued per track - a newer change replaces an older one still
  /// waiting, since only the latest settings matter.
  factory PendingRecitationOperation.setTrackSettings(
    String labelName,
    RecitationTrackSettings settings,
  ) {
    return PendingRecitationOperation(
      id: 'track_settings_$labelName',
      kind: RecitationOperationKind.setTrackSettings,
      labelName: labelName,
      settings: settings,
    );
  }

  final String id;
  final RecitationOperationKind kind;
  final String? entryId;
  final RecitationEntry? entry;
  final String? labelName;
  final RecitationTrackSettings? settings;

  Map<String, Object> toJson() => {
        'id': id,
        'kind': kind.key,
        if (entryId != null) 'entryId': entryId!,
        if (entry != null) 'entry': entry!.toJson(),
        if (labelName != null) 'labelName': labelName!,
        if (settings != null) 'settings': settings!.toJson(),
      };

  static PendingRecitationOperation? fromJson(dynamic value) {
    if (value is! Map) return null;

    final id = value['id']?.toString().trim() ?? '';
    final kind =
        recitationOperationKindFromKey(value['kind']?.toString() ?? '');
    if (id.isEmpty || kind == null) return null;

    switch (kind) {
      case RecitationOperationKind.add:
        final entry = RecitationEntry.fromJson(value['entry']);
        if (entry == null) return null;
        return PendingRecitationOperation.add(entry);
      case RecitationOperationKind.remove:
        final entryId = value['entryId']?.toString().trim() ?? '';
        if (entryId.isEmpty) return null;
        return PendingRecitationOperation.remove(entryId);
      case RecitationOperationKind.addLabel:
        final labelName = value['labelName']?.toString().trim() ?? '';
        if (labelName.isEmpty) return null;
        return PendingRecitationOperation.addLabel(labelName);
      case RecitationOperationKind.setTrackSettings:
        final labelName = value['labelName']?.toString().trim() ?? '';
        final settings = RecitationTrackSettings.fromJson(value['settings']);
        if (labelName.isEmpty || settings == null) return null;
        return PendingRecitationOperation.setTrackSettings(labelName, settings);
    }
  }
}

/// What a queue of operations changes on the remote doc, folded into the
/// field writes of a single merge write.
///
/// Every operation is keyed - an entry id or a label name - so a whole queue
/// collapses to one write with no read first: the last operation on an entry
/// id decides whether it is written or deleted, exactly as replaying the queue
/// in order would leave it, and labels are only ever added. That is what lets
/// the tracker sync a long reading session as one write instead of a
/// transaction per surah, each downloading the whole history first.
@immutable
class RecitationRemoteChanges {
  const RecitationRemoteChanges({
    required this.entries,
    required this.removedEntryIds,
    required this.labels,
    this.trackSettings = const {},
  });

  /// Entries to write, by id.
  final Map<String, RecitationEntry> entries;

  /// Entry ids to delete. Never overlaps [entries].
  final Set<String> removedEntryIds;

  /// Labels to union into the doc's label list - including those of written
  /// entries, the same way [RecitationTrackerState.setEntry] registers them.
  final Set<String> labels;

  /// Each track's latest settings, by label.
  final Map<String, RecitationTrackSettings> trackSettings;

  bool get isEmpty =>
      entries.isEmpty &&
      removedEntryIds.isEmpty &&
      labels.isEmpty &&
      trackSettings.isEmpty;
}

RecitationRemoteChanges recitationRemoteChangesFor(
  Iterable<PendingRecitationOperation> operations,
) {
  final entries = <String, RecitationEntry>{};
  final removedEntryIds = <String>{};
  final labels = <String>{};
  final trackSettings = <String, RecitationTrackSettings>{};

  void addLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed == unlabeledRecitationLabel) return;
    labels.add(trimmed);
  }

  for (final operation in operations) {
    switch (operation.kind) {
      case RecitationOperationKind.add:
        final entry = operation.entry;
        if (entry == null) continue;
        entries[entry.id] = entry;
        removedEntryIds.remove(entry.id);
        addLabel(entry.label);
      case RecitationOperationKind.remove:
        final entryId = operation.entryId;
        if (entryId == null) continue;
        entries.remove(entryId);
        removedEntryIds.add(entryId);
      case RecitationOperationKind.addLabel:
        final labelName = operation.labelName;
        if (labelName != null) addLabel(labelName);
      case RecitationOperationKind.setTrackSettings:
        final labelName = operation.labelName?.trim() ?? '';
        final settings = operation.settings;
        if (settings == null ||
            labelName.isEmpty ||
            labelName == unlabeledRecitationLabel) {
          continue;
        }
        trackSettings[labelName] = settings;
        addLabel(labelName);
    }
  }

  return RecitationRemoteChanges(
    entries: entries,
    removedEntryIds: removedEntryIds,
    labels: labels,
    trackSettings: trackSettings,
  );
}

RecitationTrackerState applyPendingRecitationOperations(
  RecitationTrackerState state,
  Iterable<PendingRecitationOperation> operations,
) {
  var nextState = state;
  for (final operation in operations) {
    nextState = applyPendingRecitationOperation(nextState, operation);
  }
  return nextState;
}

RecitationTrackerState applyPendingRecitationOperation(
  RecitationTrackerState state,
  PendingRecitationOperation operation,
) {
  return switch (operation.kind) {
    RecitationOperationKind.add =>
      operation.entry == null ? state : state.setEntry(operation.entry!),
    RecitationOperationKind.remove =>
      operation.entryId == null ? state : state.removeEntry(operation.entryId!),
    RecitationOperationKind.addLabel => operation.labelName == null
        ? state
        : state.addCustomLabel(operation.labelName!),
    RecitationOperationKind.setTrackSettings =>
      operation.labelName == null || operation.settings == null
          ? state
          : state.setTrackSettings(operation.labelName!, operation.settings!),
  };
}
