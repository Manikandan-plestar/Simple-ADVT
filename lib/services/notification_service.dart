import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../utils/text_utils.dart';
import '../utils/date_time_utils.dart';

class NotificationItem {
  final String notificationId;
  final int? numericId;
  final String? userId;
  final String? businessId;
  final String? businessProfileId;
  final String? businessName;
  final String? businessProfileImage;
  final String? postId;
  final int? numericPostId;
  final String type; // e.g. 'new_business_post'
  final String title;
  final String message;
  final String timeAgo;
  final DateTime createdAt;
  bool isRead;

  NotificationItem({
    required this.notificationId,
    this.numericId,
    this.userId,
    this.businessId,
    this.businessProfileId,
    this.businessName,
    this.businessProfileImage,
    this.postId,
    this.numericPostId,
    this.type = 'new_business_post',
    required this.title,
    required this.message,
    required this.timeAgo,
    DateTime? createdAt,
    this.isRead = false,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayTitle => TextUtils.capitalizeWords(title);
  String get displayBizName => businessName != null ? TextUtils.capitalizeWords(businessName!) : '';

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['notification_id'] ?? json['notificationId'] ?? 0;
    final int? numId = rawId is int
        ? rawId
        : int.tryParse(rawId.toString().replaceAll(RegExp(r'[^0-9]'), ''));
    final formattedId = json['notificationId'] as String? ??
        json['notification_id'] as String? ??
        (numId != null ? 'N${numId.toString().padLeft(3, '0')}' : rawId.toString());

    final rawPostId = json['post_id'] ?? json['postId'];
    final int? numPostId = rawPostId is int
        ? rawPostId
        : (rawPostId != null ? int.tryParse(rawPostId.toString().replaceAll(RegExp(r'[^0-9]'), '')) : null);
    final formattedPostId = json['postId'] as String? ??
        (numPostId != null ? 'P${numPostId.toString().padLeft(3, '0')}' : rawPostId?.toString());

    final rawBizId = json['business_id'] ?? json['businessProfileId'];
    final int? numBizId = rawBizId is int
        ? rawBizId
        : (rawBizId != null ? int.tryParse(rawBizId.toString().replaceAll(RegExp(r'[^0-9]'), '')) : null);
    final formattedBizId = json['businessProfileId'] as String? ??
        (numBizId != null ? 'BP${numBizId.toString().padLeft(3, '0')}' : rawBizId?.toString());

    final bool readState = json['is_read'] == true ||
        json['is_read'] == 1 ||
        json['isRead'] == true ||
        json['isRead'] == 1;

    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    final DateTime parsedDate = DateTimeUtils.parseUtc(rawCreatedAt) ?? DateTime.now().toUtc();

    return NotificationItem(
      notificationId: formattedId,
      numericId: numId,
      userId: json['user_id']?.toString() ?? json['userId']?.toString(),
      businessId: rawBizId?.toString(),
      businessProfileId: formattedBizId,
      businessName: json['business_name'] ?? json['businessName'],
      businessProfileImage: json['business_profile_image'] ?? json['brandLogo'] ?? json['brand_logo'],
      postId: formattedPostId,
      numericPostId: numPostId,
      type: json['type'] ?? 'new_business_post',
      title: json['title'] ?? 'Notification',
      message: json['message'] ?? '',
      timeAgo: DateTimeUtils.calculateTimeAgo(parsedDate),
      createdAt: parsedDate,
      isRead: readState,
    );
  }
}

class NotificationService extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Fetch notifications for the authenticated user from the backend
  Future<void> fetchNotifications({
    String? authToken,
    String? userId,
    String? userEmail,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (authToken != null) _apiClient.setAuthToken(authToken);
    if (userId != null || userEmail != null) {
      _apiClient.setCurrentUser(userId: userId, email: userEmail);
    }

    try {
      final response = await _apiClient.get('/api/notifications');

      if (response != null && response is Map<String, dynamic> && response['success'] == true) {
        final List rawList = response['notifications'] as List? ?? [];
        _notifications = rawList
            .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _errorMessage = null;
      } else {
        _errorMessage = response is Map ? response['message'] : 'Failed to load notifications';
      }
    } catch (e) {
      debugPrint('[NotificationService] Fetch error: $e');
      _errorMessage = 'Unable to connect to notification server';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark a single notification as read on the backend
  Future<bool> markAsRead(
    String notificationId, {
    String? authToken,
    String? userId,
    String? userEmail,
  }) async {
    final cleanId = notificationId.replaceAll(RegExp(r'[^0-9]'), '');

    // Optimistic UI update
    final index = _notifications.indexWhere((n) =>
        n.notificationId == notificationId ||
        (n.numericId != null && n.numericId.toString() == cleanId));
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();
    }

    if (authToken != null) _apiClient.setAuthToken(authToken);
    if (userId != null || userEmail != null) {
      _apiClient.setCurrentUser(userId: userId, email: userEmail);
    }

    try {
      final response = await _apiClient.put('/api/notifications/$cleanId/read', {});
      return response != null && response is Map && response['success'] == true;
    } catch (e) {
      debugPrint('[NotificationService] Mark as read error: $e');
      return false;
    }
  }

  /// Mark all notifications as read for current user
  Future<bool> markAllAsRead({
    String? authToken,
    String? userId,
    String? userEmail,
  }) async {
    // Optimistic UI update
    for (var item in _notifications) {
      item.isRead = true;
    }
    notifyListeners();

    if (authToken != null) _apiClient.setAuthToken(authToken);
    if (userId != null || userEmail != null) {
      _apiClient.setCurrentUser(userId: userId, email: userEmail);
    }

    try {
      final response = await _apiClient.put('/api/notifications/mark-all-read', {});
      return response != null && response is Map && response['success'] == true;
    } catch (e) {
      debugPrint('[NotificationService] Mark all read error: $e');
      return false;
    }
  }

  /// Delete a single notification from the database
  Future<bool> deleteNotification(
    String notificationId, {
    String? authToken,
    String? userId,
    String? userEmail,
  }) async {
    final cleanId = notificationId.replaceAll(RegExp(r'[^0-9]'), '');

    // Optimistic removal
    final previousList = List<NotificationItem>.from(_notifications);
    _notifications.removeWhere((n) =>
        n.notificationId == notificationId ||
        (n.numericId != null && n.numericId.toString() == cleanId));
    notifyListeners();

    if (authToken != null) _apiClient.setAuthToken(authToken);
    if (userId != null || userEmail != null) {
      _apiClient.setCurrentUser(userId: userId, email: userEmail);
    }

    try {
      final response = await _apiClient.delete('/api/notifications/$cleanId');
      if (response != null && response is Map && response['success'] == true) {
        return true;
      } else {
        // Rollback on failure
        _notifications = previousList;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[NotificationService] Delete error: $e');
      _notifications = previousList;
      notifyListeners();
      return false;
    }
  }

  /// Delete multiple notifications in batch from the database
  Future<bool> deleteNotifications(
    List<String> notificationIds, {
    String? authToken,
    String? userId,
    String? userEmail,
  }) async {
    if (notificationIds.isEmpty) return true;

    final cleanIds = notificationIds
        .map((id) => id.replaceAll(RegExp(r'[^0-9]'), ''))
        .where((id) => id.isNotEmpty)
        .toList();

    // Optimistic removal
    final previousList = List<NotificationItem>.from(_notifications);
    _notifications.removeWhere((n) =>
        notificationIds.contains(n.notificationId) ||
        (n.numericId != null && cleanIds.contains(n.numericId.toString())));
    notifyListeners();

    if (authToken != null) _apiClient.setAuthToken(authToken);
    if (userId != null || userEmail != null) {
      _apiClient.setCurrentUser(userId: userId, email: userEmail);
    }

    try {
      final response = await _apiClient.delete('/api/notifications', {'ids': cleanIds});
      if (response != null && response is Map && response['success'] == true) {
        return true;
      } else {
        // Rollback on failure
        _notifications = previousList;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[NotificationService] Batch delete error: $e');
      _notifications = previousList;
      notifyListeners();
      return false;
    }
  }

  /// Refresh notifications
  Future<void> refreshNotifications({
    String? authToken,
    String? userId,
    String? userEmail,
  }) async {
    await fetchNotifications(
      authToken: authToken,
      userId: userId,
      userEmail: userEmail,
    );
  }
}
