import 'package:flutter/material.dart';

class FollowButton extends StatelessWidget {
  final bool isFollowed;
  final VoidCallback onTap;

  const FollowButton({
    super.key,
    required this.isFollowed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isFollowed ? const Color(0xFFF3F4F6) : const Color(0xFFEEF2FF),
        foregroundColor: isFollowed ? const Color(0xFF374151) : const Color(0xFF4F46E5),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        isFollowed ? '✓ Following' : '+ Follow',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isFollowed ? const Color(0xFF374151) : const Color(0xFF4F46E5),
        ),
      ),
    );
  }
}
