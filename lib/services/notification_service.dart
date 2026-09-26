import 'package:flutter/foundation.dart';

class NotificationItem {
  final String notificationId;
  final String title;
  final String message;
  final String timeAgo;
  final String type; // 'job', 'offer', 'post', 'follow'
  bool isRead;

  NotificationItem({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.type,
    this.isRead = false,
  });
}

class NotificationService extends ChangeNotifier {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      notificationId: "N1",
      title: "New Job Vacancy",
      message: "Sri Balaji Electronics posted a new Flutter Developer job in Chennai.",
      timeAgo: "2 hours ago",
      type: "job",
      isRead: false,
    ),
    NotificationItem(
      notificationId: "N2",
      title: "Special Weekend Offer",
      message: "Ananya Silks & Sarees announced Flat 25% OFF on pure silk sarees.",
      timeAgo: "4 hours ago",
      type: "offer",
      isRead: false,
    ),
    NotificationItem(
      notificationId: "N3",
      title: "Store Announcement",
      message: "Chennai Roast Cafe added Head Barista opening.",
      timeAgo: "1 day ago",
      type: "post",
      isRead: true,
    ),
  ];

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Purpose: Mark all notifications as read.
  void markAllAsRead() {
    for (var item in _notifications) {
      item.isRead = true;
    }
    notifyListeners();
  }

  /// Purpose: Add a new push notification to state.
  /// Future behavior: Firebase Messaging handler (onMessage / onBackgroundMessage).
  void addNotification({
    required String title,
    required String message,
    required String type,
  }) {
    _notifications.insert(
      0,
      NotificationItem(
        notificationId: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        message: message,
        timeAgo: "Just now",
        type: type,
        isRead: false,
      ),
    );
    notifyListeners();
  }
}
