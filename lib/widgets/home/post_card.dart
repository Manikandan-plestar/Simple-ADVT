import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/post_service.dart';
import '../business/cycling_post_image.dart';

class PostCard extends StatelessWidget {
  final PostItem item;
  final bool isOwner;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleSave;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onBusinessTap;
  final Function(String imageUrl)? onImageLongPress;

  PostCard({
    super.key,
    PostItem? post,
    PostItem? item,
    this.isOwner = false,
    this.onView,
    this.onEdit,
    this.onDelete,
    this.onToggleSave,
    this.onBookmarkTap,
    this.onBusinessTap,
    this.onImageLongPress,
  }) : item = (post ?? item)!;

  void _openFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Post Image', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: imageUrl.startsWith('http')
                  ? Image.network(imageUrl, fit: BoxFit.contain)
                  : (imageUrl.startsWith('assets/')
                      ? Image.asset(imageUrl, fit: BoxFit.contain)
                      : Image.file(File(imageUrl), fit: BoxFit.contain)),
            ),
          ),
        ),
      ),
    );
  }

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
          // 1. Post Header: Target Location on Left, Three-dot Menu on Right (if Owner)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Target Location on Left
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        item.displayLocation.isNotEmpty ? item.displayLocation : 'Target Location',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Three-Dot Menu on Right (Visible to Business Owner)
                if (isOwner && (onEdit != null || onDelete != null))
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF6B7280), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'edit' && onEdit != null) {
                        onEdit!();
                      } else if (value == 'delete' && onDelete != null) {
                        onDelete!();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4F46E5)),
                              SizedBox(width: 10),
                              Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                              SizedBox(width: 10),
                              Text('Delete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          // 2. Fixed-Height Post Image Container with Long Press for Fullscreen
          GestureDetector(
            onTap: onView,
            onLongPress: () {
              final activeImg = item.images.isNotEmpty ? item.images.first : (item.brandLogo ?? '');
              if (onImageLongPress != null && activeImg.isNotEmpty) {
                onImageLongPress!(activeImg);
              } else if (activeImg.isNotEmpty) {
                _openFullScreenImage(context, activeImg);
              }
            },
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: item.images.isNotEmpty
                  ? CyclingPostImage(
                      images: item.images,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.zero,
                      interval: const Duration(seconds: 5),
                      emptyWidget: _buildPostCardPlaceholder(),
                    )
                  : (item.brandLogo != null && item.brandLogo!.isNotEmpty
                      ? CyclingPostImage(
                          images: [item.brandLogo!],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.zero,
                          emptyWidget: _buildPostCardPlaceholder(),
                        )
                      : _buildPostCardPlaceholder()),
            ),
          ),

          // 3. Post Content (Title, Description)
          if (item.displayTitle.isNotEmpty || item.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.displayTitle.isNotEmpty)
                    Text(
                      item.displayTitle,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF4B5563),
                        height: 1.35,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

          // 4. Post Footer: Posted Time + [Owner Metrics OR Viewer Save Button]
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Posted Time on Left
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(
                          item.timeAgo,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Owned Profile: Show Analytics (Clicks & Saved Count)
                    if (isOwner) ...[
                      // More Info Click Count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 4),
                            Text(
                              '${item.moreInfoClickCount}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Saved Count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bookmark_outline_rounded,
                              size: 14,
                              color: Color(0xFF4B5563),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${item.savedCount}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Viewer Side: Interactive Save / Bookmark Option
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onToggleSave ?? onBookmarkTap,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.isSaved ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: item.isSaved ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  size: 15,
                                  color: item.isSaved ? const Color(0xFF059669) : const Color(0xFF4B5563),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.isSaved ? 'Saved' : 'Save',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: item.isSaved ? const Color(0xFF059669) : const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCardPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_rounded, color: Color(0xFF4F46E5), size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              item.displayBizName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4F46E5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
