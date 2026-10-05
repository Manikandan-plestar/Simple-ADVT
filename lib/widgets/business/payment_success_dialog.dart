import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/post_service.dart';

class PaymentSuccessDialog extends StatelessWidget {
  final PostItem post;
  final String? transactionId;
  final VoidCallback? onDismiss;

  const PaymentSuccessDialog({
    super.key,
    required this.post,
    this.transactionId,
    this.onDismiss,
  });

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Active Now';
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    return formatter.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final publishedStr = _formatDateTime(post.publishedAt ?? post.createdAt);
    final expiryStr = _formatDateTime(post.expiresAt ?? post.createdAt.add(Duration(days: post.durationDays)));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Glowing Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your post is verified and now active.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 20),

            // Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.storefront_rounded,
                    label: 'Business',
                    value: post.displayBizName,
                  ),
                  const Divider(height: 18, thickness: 0.8, color: Color(0xFFE5E7EB)),
                  _buildDetailRow(
                    icon: Icons.timelapse_rounded,
                    label: 'Post Duration',
                    value: '${post.durationDays} ${post.durationDays == 1 ? 'Day' : 'Days'}',
                    valueColor: const Color(0xFF4F46E5),
                    isBold: true,
                  ),
                  const Divider(height: 18, thickness: 0.8, color: Color(0xFFE5E7EB)),
                  _buildDetailRow(
                    icon: Icons.publish_rounded,
                    label: 'Published Time',
                    value: publishedStr,
                  ),
                  const Divider(height: 18, thickness: 0.8, color: Color(0xFFE5E7EB)),
                  _buildDetailRow(
                    icon: Icons.event_busy_rounded,
                    label: 'Expires At',
                    value: expiryStr,
                    valueColor: const Color(0xFFDC2626),
                  ),
                  if (post.targetLocation != null && post.targetLocation!.isNotEmpty) ...[
                    const Divider(height: 18, thickness: 0.8, color: Color(0xFFE5E7EB)),
                    _buildDetailRow(
                      icon: Icons.location_on_rounded,
                      label: 'Target Areas',
                      value: post.displayLocation,
                    ),
                  ],
                  if (transactionId != null && transactionId!.isNotEmpty) ...[
                    const Divider(height: 18, thickness: 0.8, color: Color(0xFFE5E7EB)),
                    _buildDetailRow(
                      icon: Icons.receipt_long_rounded,
                      label: 'Transaction ID',
                      value: transactionId!,
                      valueFontSize: 11,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismiss?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'View Active Post',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
    double valueFontSize = 12,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}
