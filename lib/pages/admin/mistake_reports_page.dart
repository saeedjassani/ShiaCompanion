import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../data/universal_data.dart';
import '../../services/analytics_service.dart';
import '../../services/mistake_report_service.dart';
import '../../widgets/responsive_content.dart';

/// Which half of the queue is showing. Resolved reports stay in Firestore
/// rather than being deleted, so there is always a record of what was fixed -
/// this is just which half [_MistakeReportsPageState] filters the live list
/// down to.
enum _ReportFilter {
  open('Open'),
  resolved('Resolved');

  const _ReportFilter(this.label);

  final String label;
}

/// The admin-only queue of "Report Mistake" submissions filed from the zikr
/// reading page's selection toolbar - see [MistakeReportService]. Lets an
/// admin open the zikr a report points at, and mark the report resolved once
/// it has been acted on.
class MistakeReportsPage extends StatefulWidget {
  const MistakeReportsPage({super.key});

  @override
  State<MistakeReportsPage> createState() => _MistakeReportsPageState();
}

class _MistakeReportsPageState extends State<MistakeReportsPage> {
  _ReportFilter _filter = _ReportFilter.open;
  late final Stream<List<MistakeReport>> _reports;

  static final DateFormat _dateFormat = DateFormat('MMM d, h:mm a');

  @override
  void initState() {
    super.initState();
    trackScreen('Mistake Reports Page');
    _reports = MistakeReportService.watchReports();
  }

  Future<void> _openZikr(MistakeReport report) async {
    await handleUniversalDataClick(
      context,
      UniversalData(report.zikrUid, report.zikrTitle, 0),
      source: ZikrOpenSource.admin,
    );
  }

  Future<void> _setResolved(MistakeReport report, bool resolved) async {
    unawaited(AnalyticsService.feature(
      resolved ? 'mistake_report_resolved' : 'mistake_report_reopened',
      label: resolved ? 'Mistake report resolved' : 'Mistake report reopened',
    ));
    await MistakeReportService.setResolved(report.id, resolved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mistake Reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SegmentedButton<_ReportFilter>(
              segments: [
                for (final filter in _ReportFilter.values)
                  ButtonSegment(value: filter, label: Text(filter.label)),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) =>
                  setState(() => _filter = selection.first),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MistakeReport>>(
              stream: _reports,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Could not load reports: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final resolved = _filter == _ReportFilter.resolved;
                final rows = snapshot.data!
                    .where((report) => report.isResolved == resolved)
                    .toList();

                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      resolved
                          ? 'No resolved reports yet.'
                          : 'No open reports.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final report in rows)
                      ResponsiveContent(
                        maxWidth: listContentWidth,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: _MistakeReportCard(
                          report: report,
                          dateFormat: _dateFormat,
                          onOpenZikr: () => _openZikr(report),
                          onToggleResolved: () =>
                              _setResolved(report, !report.isResolved),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MistakeReportCard extends StatelessWidget {
  const _MistakeReportCard({
    required this.report,
    required this.dateFormat,
    required this.onOpenZikr,
    required this.onToggleResolved,
  });

  final MistakeReport report;
  final DateFormat dateFormat;
  final VoidCallback onOpenZikr;
  final VoidCallback onToggleResolved;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final createdAt = report.createdAt;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.zikrTitle.isEmpty
                        ? report.zikrUid
                        : report.zikrTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (createdAt != null)
                  Text(
                    dateFormat.format(createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
            if (report.selectedText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(report.selectedText),
              ),
            ],
            if (report.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(report.note),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onOpenZikr,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open zikr'),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: onToggleResolved,
                  icon: Icon(
                    report.isResolved
                        ? Icons.replay
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(report.isResolved ? 'Reopen' : 'Resolve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
