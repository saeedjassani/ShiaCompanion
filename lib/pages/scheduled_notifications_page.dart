import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../widgets/responsive_content.dart';

class ScheduledNotificationsPage extends StatefulWidget {
  @override
  State<ScheduledNotificationsPage> createState() =>
      _ScheduledNotificationsPageState();
}

class _ScheduledNotificationsPageState
    extends State<ScheduledNotificationsPage> {
  late Future<List<PendingNotificationRequest>> _scheduledNotifications;

  @override
  void initState() {
    super.initState();
    _scheduledNotifications = _loadScheduledNotifications();
  }

  Future<List<PendingNotificationRequest>> _loadScheduledNotifications() async {
    final requests =
        await flutterLocalNotificationsPlugin?.pendingNotificationRequests() ??
            <PendingNotificationRequest>[];
    requests.sort((a, b) {
      final aDate = _scheduledDate(a);
      final bDate = _scheduledDate(b);
      if (aDate == null && bDate == null) return a.id.compareTo(b.id);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return requests;
  }

  DateTime? _scheduledDate(PendingNotificationRequest request) {
    final payload = request.payload;
    if (payload == null || payload.isEmpty) return null;
    return DateTime.tryParse(payload);
  }

  String _titleFor(PendingNotificationRequest request) {
    final scheduledDate = _scheduledDate(request);
    if (scheduledDate != null) {
      return DateFormat('EEE, MMM d - h:mm a').format(scheduledDate);
    }
    return request.title ?? 'Scheduled notification';
  }

  String _subtitleFor(PendingNotificationRequest request) {
    final parts = <String>[];
    if (request.title != null && _scheduledDate(request) != null) {
      parts.add(request.title!);
    }
    if (request.body != null && request.body!.isNotEmpty) {
      parts.add(request.body!);
    }
    parts.add('ID ${request.id}');
    return parts.join('\n');
  }

  Future<void> _refresh() async {
    setState(() {
      _scheduledNotifications = _loadScheduledNotifications();
    });
    await _scheduledNotifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scheduled Notifications'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<PendingNotificationRequest>>(
        future: _scheduledNotifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator());
          }

          final requests =
              snapshot.data ?? const <PendingNotificationRequest>[];
          if (requests.isEmpty) {
            return Center(child: Text('No scheduled notifications.'));
          }

          return ResponsiveContent(
            maxWidth: listContentWidth,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: requests.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final request = requests[index];
                return ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text(_titleFor(request)),
                  subtitle: Text(_subtitleFor(request)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
