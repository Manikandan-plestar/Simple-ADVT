import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/skeleton/skeleton_loader.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isInitialLoaded = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialLoaded) {
      _isInitialLoaded = true;
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final notifService = Provider.of<NotificationService>(context, listen: false);
    final user = authService.currentUser;

    if (user.userId.isNotEmpty) {
      await notifService.fetchNotifications(
        authToken: user.authToken,
        userId: user.userId,
        userEmail: user.email,
      );
    }
  }

  void _toggleSelection(String notificationId) {
    setState(() {
      if (_selectedIds.contains(notificationId)) {
        _selectedIds.remove(notificationId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(notificationId);
      }
    });
  }

  void _selectAll(List<NotificationItem> notifications) {
    setState(() {
      if (_selectedIds.length == notifications.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.clear();
        for (var n in notifications) {
          _selectedIds.add(n.notificationId);
        }
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<bool> _showDeleteConfirmDialog({
    required BuildContext context,
    required bool isMultiple,
    int count = 1,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isMultiple ? 'Delete Notifications' : 'Delete Notification',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        content: Text(
          isMultiple
              ? 'Are you sure you want to delete the selected notifications?'
              : 'Are you sure you want to delete this notification?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _handleDeleteSingle(NotificationItem item) async {
    final confirmed = await _showDeleteConfirmDialog(
      context: context,
      isMultiple: false,
    );

    if (confirmed && mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notifService = Provider.of<NotificationService>(context, listen: false);
      final user = authService.currentUser;

      await notifService.deleteNotification(
        item.notificationId,
        authToken: user.authToken,
        userId: user.userId,
        userEmail: user.email,
      );
    }
  }

  Future<void> _handleDeleteMultiple() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await _showDeleteConfirmDialog(
      context: context,
      isMultiple: true,
      count: _selectedIds.length,
    );

    if (confirmed && mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notifService = Provider.of<NotificationService>(context, listen: false);
      final user = authService.currentUser;

      final idsToDelete = _selectedIds.toList();
      _exitSelectionMode();

      await notifService.deleteNotifications(
        idsToDelete,
        authToken: user.authToken,
        userId: user.userId,
        userEmail: user.email,
      );
    }
  }

  void _handleNotificationTap(NotificationItem notif) {
    if (_isSelectionMode) {
      _toggleSelection(notif.notificationId);
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final notifService = Provider.of<NotificationService>(context, listen: false);
    final user = authService.currentUser;

    // Mark as read if unread
    if (!notif.isRead) {
      notifService.markAsRead(
        notif.notificationId,
        authToken: user.authToken,
        userId: user.userId,
        userEmail: user.email,
      );
    }

    // Post / Business Navigation: open corresponding Business Details
    final targetBizId = notif.businessProfileId ?? notif.businessId;
    if (targetBizId != null && targetBizId.isNotEmpty) {
      Navigator.pushNamed(
        context,
        '/business-details',
        arguments: targetBizId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifService = Provider.of<NotificationService>(context);
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final notifications = notifService.notifications;
    final isLoading = notifService.isLoading;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _isSelectionMode
            ? AppBar(
                backgroundColor: const Color(0xFF4F46E5),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: _exitSelectionMode,
                ),
                title: Text(
                  '${_selectedIds.length} Selected',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      _selectedIds.length == notifications.length
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                      color: Colors.white,
                    ),
                    tooltip: _selectedIds.length == notifications.length ? 'Deselect All' : 'Select All',
                    onPressed: () => _selectAll(notifications),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                    tooltip: 'Delete Selected',
                    onPressed: _selectedIds.isNotEmpty ? _handleDeleteMultiple : null,
                  ),
                ],
              )
            : AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                actions: [
                  if (notifService.unreadCount > 0)
                    TextButton(
                      onPressed: () {
                        notifService.markAllAsRead(
                          authToken: user.authToken,
                          userId: user.userId,
                          userEmail: user.email,
                        );
                      },
                      child: const Text(
                        'Mark read',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                      ),
                    ),
                ],
              ),
        body: RefreshIndicator(
          onRefresh: () => notifService.refreshNotifications(
            authToken: user.authToken,
            userId: user.userId,
            userEmail: user.email,
          ),
          color: const Color(0xFF4F46E5),
          child: isLoading && notifications.isEmpty
              ? _buildSkeletonLoading()
              : notifications.isEmpty
                  ? _buildEmptyState()
                  : _buildNotificationList(notifications),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonLoader.circular(size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonLoader(
                        width: 140,
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      SkeletonLoader(
                        width: 50,
                        height: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SkeletonLoader(
                    width: double.infinity,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  SkeletonLoader(
                    width: 180,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 100),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 56,
                color: Color(0xFF9CA3AF),
              ),
              SizedBox(height: 16),
              Text(
                'No notifications yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'When businesses you follow post updates, they will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationList(List<NotificationItem> notifications) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final notif = notifications[index];
        final isSelected = _selectedIds.contains(notif.notificationId);

        // In selection mode, tapping selects; swipe is disabled
        if (_isSelectionMode) {
          return _buildNotificationCard(notif, isSelected: isSelected);
        }

        // Swipe-to-Delete from left to right with confirmation dialog
        return Dismissible(
          key: ValueKey(notif.notificationId),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (direction) async {
            return await _showDeleteConfirmDialog(
              context: context,
              isMultiple: false,
            );
          },
          onDismissed: (direction) {
            final authService = Provider.of<AuthService>(context, listen: false);
            final notifService = Provider.of<NotificationService>(context, listen: false);
            final user = authService.currentUser;

            notifService.deleteNotification(
              notif.notificationId,
              authToken: user.authToken,
              userId: user.userId,
              userEmail: user.email,
            );
          },
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'Delete',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          child: _buildNotificationCard(notif, isSelected: false),
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationItem notif, {required bool isSelected}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNotificationTap(notif),
        onLongPress: () {
          if (!_isSelectionMode) {
            setState(() {
              _isSelectionMode = true;
              _selectedIds.add(notif.notificationId);
            });
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFEEF2FF)
                : (notif.isRead ? Colors.white : const Color(0xFFEEF2FF)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF3F4F6),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (_) => _toggleSelection(notif.notificationId),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF4F46E5), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          notif.timeAgo,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.message,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563), height: 1.3),
                    ),
                  ],
                ),
              ),
              if (!notif.isRead && !_isSelectionMode) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4F46E5),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
