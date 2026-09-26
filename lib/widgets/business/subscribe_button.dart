import 'package:flutter/material.dart';

class SubscribeButton extends StatelessWidget {
  final bool isSubscribed;
  final VoidCallback onTap;

  const SubscribeButton({
    super.key,
    required this.isSubscribed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSubscribed ? const Color(0xFFFEF3C7) : const Color(0xFFFFFBEB),
        foregroundColor: isSubscribed ? const Color(0xFFD97706) : const Color(0xFFF59E0B),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(
        isSubscribed ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
        size: 14,
      ),
      label: Text(
        isSubscribed ? 'Subscribed' : 'Subscribe',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
