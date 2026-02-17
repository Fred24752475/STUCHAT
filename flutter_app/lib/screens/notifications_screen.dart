import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  final String userId;

  const NotificationsScreen({super.key, required this.userId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    try {
      final data = await ApiService.getNotifications(widget.userId);
      setState(() {
        notifications = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await ApiService.markNotificationAsRead(notificationId);
    loadNotifications();
  }

  Future<void> markAllAsRead() async {
    await ApiService.markAllNotificationsAsRead(widget.userId);
    loadNotifications();
  }

  IconData getIconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'message':
        return Icons.message;
      case 'event':
        return Icons.event;
      default:
        return Icons.notifications;
    }
  }

  Color getColorForType(String type) {
    switch (type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blue;
      case 'follow':
        return Colors.green;
      case 'message':
        return Colors.purple;
      case 'event':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    final isRead = notif['is_read'] == 1;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: getColorForType(notif['type']),
                        child: Icon(
                          getIconForType(notif['type']),
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        notif['content'],
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        _formatTime(notif['created_at']),
                        style: const TextStyle(fontSize: 12),
                      ),
                      tileColor: isRead ? null : Colors.blue.withValues(alpha: 0.1),
                      onTap: () => markAsRead(notif['id'].toString()),
                    );
                  },
                ),
    );
  }

  String _formatTime(String timestamp) {
    final time = DateTime.parse(timestamp);
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
