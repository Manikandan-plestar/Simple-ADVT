import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/post_service.dart';
import '../business/cycling_post_image.dart';

class PostCard extends StatelessWidget {
  final PostItem item;
  final VoidCallback? onView;
  final VoidCallback? onToggleSave;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onBusinessTap;

  PostCard({
    super.key,
    PostItem? post,
    PostItem? item,
    this.onView,
    this.onToggleSave,
    this.onBookmarkTap,
    this.onBusinessTap,
  }) : item = (post ?? item)!;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Publisher Business Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBusinessTap ?? onView,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE0E7FF), width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (item.brandLogo != null && item.brandLogo!.isNotEmpty)
                        ? (item.brandLogo!.startsWith('/') || !item.brandLogo!.startsWith('http')
                            ? Image.file(
                                File(item.brandLogo!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildDefaultLogo(),
                              )
                            : Image.network(
                                item.brandLogo!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildDefaultLogo(),
                              ))
                        : _buildDefaultLogo(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onBusinessTap ?? onView,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayBizName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.displaySubtitle.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            item.displaySubtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (item.displayLocation.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 3),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            item.displayLocation,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F46E5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 2. Post Image(s) with Cycling Carousel
          if (item.images.isNotEmpty)
            GestureDetector(
              onTap: onView,
              child: CyclingPostImage(
                images: item.images,
                height: 200,
                borderRadius: BorderRadius.zero,
                interval: const Duration(seconds: 5),
                emptyWidget: Container(
                  height: 160,
                  width: double.infinity,
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: Icon(Icons.image_outlined, color: Color(0xFF9CA3AF), size: 36),
                  ),
                ),
              ),
            ),

          // 3. Post Content (Title, Description, Time & Save Button)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onView,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                          height: 1.3,
                        ),
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4B5563),
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),

                // Bottom Row: Post Time on Left, Save Action on Right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(
                          item.timeAgo,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (onView != null) ...[
                          OutlinedButton(
                            onPressed: onView,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              side: const BorderSide(color: Color(0xFFE0E7FF), width: 1.2),
                              backgroundColor: const Color(0xFFFAFAFA),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'View Details',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          onPressed: onToggleSave ?? onBookmarkTap,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            item.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            size: 22,
                            color: item.isSaved ? const Color(0xFF4F46E5) : const Color(0xFF6B7280),
                          ),
                          tooltip: item.isSaved ? 'Saved' : 'Save',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultLogo() {
    return Center(
      child: Text(
        item.bizName.isNotEmpty ? item.bizName[0].toUpperCase() : 'B',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }
}
