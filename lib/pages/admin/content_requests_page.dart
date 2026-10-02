import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../services/analytics_service.dart';
import '../../services/content_request_service.dart';
import '../../widgets/responsive_content.dart';

/// Which half of the queue is showing. Resolved requests stay in Firestore,
/// the same as resolved mistake reports, so there's a record of what was
/// added.
enum _RequestFilter {
  open('Open'),
  resolved('Resolved');

  const _RequestFilter(this.label);

  final String label;
}

/// The admin-only queue of "Request a Zikr or Book" submissions - see
/// [ContentRequestService]. Lets an admin mark a request resolved once the
/// content has been added (or ruled out).
class ContentRequestsPage extends StatefulWidget {
  const ContentRequestsPage({super.key});

  @override
  State<ContentRequestsPage> createState() => _ContentRequestsPageState();
}

class _ContentRequestsPageState extends State<ContentRequestsPage> {
  _RequestFilter _filter = _RequestFilter.open;
  late final Stream<List<ContentRequest>> _requests;

  static final DateFormat _dateFormat = DateFormat('MMM d, h:mm a');

  @override
  void initState() {
    super.initState();
    trackScreen('Content Requests Page');
    _requests = ContentRequestService.watchRequests();
  }

  Future<void> _setResolved(ContentRequest request, bool resolved) async {
    unawaited(AnalyticsService.feature(
      resolved ? 'content_request_resolved' : 'content_request_reopened',
      label: resolved ? 'Content request resolved' : 'Content request reopened',
    ));
    await ContentRequestService.setResolved(request.id, resolved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content Requests')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SegmentedButton<_RequestFilter>(
              segments: [
                for (final filter in _RequestFilter.values)
                  ButtonSegment(value: filter, label: Text(filter.label)),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) =>
                  setState(() => _filter = selection.first),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ContentRequest>>(
              stream: _requests,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child:
                          Text('Could not load requests: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final resolved = _filter == _RequestFilter.resolved;
                final rows = snapshot.data!
                    .where((request) => request.isResolved == resolved)
                    .toList();

                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      resolved
                          ? 'No resolved requests yet.'
                          : 'No open requests.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final request in rows)
                      ResponsiveContent(
                        maxWidth: listContentWidth,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: _ContentRequestCard(
                          request: request,
                          dateFormat: _dateFormat,
                          onToggleResolved: () =>
                              _setResolved(request, !request.isResolved),
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

class _ContentRequestCard extends StatelessWidget {
  const _ContentRequestCard({
    required this.request,
    required this.dateFormat,
    required this.onToggleResolved,
  });

  final ContentRequest request;
  final DateFormat dateFormat;
  final VoidCallback onToggleResolved;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final createdAt = request.createdAt;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  request.type == ContentRequestType.book
                      ? Icons.local_library_outlined
                      : Icons.menu_book_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  request.type.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                ),
                const Spacer(),
                if (createdAt != null)
                  Text(
                    dateFormat.format(createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              request.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (request.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(request.details),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onToggleResolved,
                icon: Icon(
                  request.isResolved
                      ? Icons.replay
                      : Icons.check_circle_outline,
                  size: 18,
                ),
                label: Text(request.isResolved ? 'Reopen' : 'Resolve'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
