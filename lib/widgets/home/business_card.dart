import 'package:flutter/material.dart';
import '../../services/business_service.dart';

class BusinessCard extends StatelessWidget {
  final BusinessProfile business;
  final VoidCallback onTap;
  final Widget? trailing;

  const BusinessCard({
    super.key,
    required this.business,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildBusinessImage(business.image),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              business.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Color(0xFF3B82F6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${business.displayCategory} • ${business.displayLocation}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ?? const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessImage(String imageUrl) {
    if (imageUrl.trim().isEmpty) {
      return Container(
        width: 48,
        height: 48,
        color: const Color(0xFFEEF2FF),
        child: const Icon(Icons.store_rounded, color: Color(0xFF4F46E5), size: 24),
      );
    }

    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 48,
            height: 48,
            color: const Color(0xFFF3F4F6),
            child: const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4F46E5)),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          width: 48,
          height: 48,
          color: const Color(0xFFEEF2FF),
          child: const Icon(Icons.store_rounded, color: Color(0xFF4F46E5), size: 24),
        ),
      );
    }

    if (imageUrl.startsWith('assets/')) {
      return Image.asset(imageUrl, width: 48, height: 48, fit: BoxFit.cover);
    }

    return Container(
      width: 48,
      height: 48,
      color: const Color(0xFFEEF2FF),
      child: const Icon(Icons.store_rounded, color: Color(0xFF4F46E5), size: 24),
    );
  }
}
