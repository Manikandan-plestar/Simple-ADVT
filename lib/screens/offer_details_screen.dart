import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/business_service.dart';
import '../widgets/business/cycling_post_image.dart';
import '../widgets/detail/route_map.dart';

class OfferDetailsScreen extends StatefulWidget {
  final String postId;

  const OfferDetailsScreen({super.key, required this.postId});

  @override
  State<OfferDetailsScreen> createState() => _OfferDetailsScreenState();
}

class _OfferDetailsScreenState extends State<OfferDetailsScreen> {
  bool _showRouteMap = false;
  bool _isBizFetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isBizFetched) {
      _isBizFetched = true;
      final postService = Provider.of<PostService>(context, listen: false);
      final bizService = Provider.of<BusinessService>(context, listen: false);
      final post = postService.getPostById(widget.postId);
      if (post != null && post.businessProfileId.isNotEmpty) {
        if (bizService.getBusinessById(post.businessProfileId) == null) {
          bizService.fetchBusinessById(post.businessProfileId);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postService = Provider.of<PostService>(context);
    final bizService = Provider.of<BusinessService>(context);

    final post = postService.getPostById(widget.postId);
    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Offer Details')),
        body: const Center(child: Text('Offer not found')),
      );
    }

    final biz = bizService.getBusinessById(post.businessProfileId);
    final bizName = (biz != null && biz.name.isNotEmpty) ? biz.name : (post.bizName.isNotEmpty ? post.bizName : 'Verified Business');
    final bizCategory = (biz != null && biz.category.isNotEmpty) ? biz.category : 'Store & Services';
    final bizLocation = (biz != null && biz.location.isNotEmpty) ? biz.location : (post.targetLocation ?? 'Nearby');
    final bizImage = (biz != null && biz.image.isNotEmpty) ? biz.image : (post.brandLogo ?? (post.images.isNotEmpty ? post.images.first : ''));
    final isFollowed = biz != null ? biz.isFollowed : bizService.followedBusinesses.any((b) => b.businessProfileId == post.businessProfileId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Offer Details',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        actions: [
          IconButton(
            onPressed: () => postService.toggleSavePost(post.postId),
            icon: Icon(
              post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: post.isSaved ? const Color(0xFF4F46E5) : const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Top Posted Profile Detail Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF3F4F6)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/business-details',
                              arguments: post.businessProfileId,
                            );
                          },
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: bizImage.isNotEmpty
                                    ? Image.network(
                                        bizImage,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 48,
                                          height: 48,
                                          color: const Color(0xFFEEF2FF),
                                          child: const Icon(Icons.store_rounded, color: Color(0xFF4F46E5), size: 24),
                                        ),
                                      )
                                    : Container(
                                        width: 48,
                                        height: 48,
                                        color: const Color(0xFFEEF2FF),
                                        child: const Icon(Icons.store_rounded, color: Color(0xFF4F46E5), size: 24),
                                      ),
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
                                            bizName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF111827),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF3B82F6)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      bizCategory,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => bizService.toggleFollow(post.businessProfileId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowed ? const Color(0xFFF3F4F6) : const Color(0xFFEEF2FF),
                          foregroundColor: isFollowed ? const Color(0xFF374151) : const Color(0xFF4F46E5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isFollowed ? '✓ Following' : '+ Follow',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFEF4444)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                bizLocation,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF4B5563)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showRouteMap = !_showRouteMap;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.navigation_rounded, size: 13),
                        label: const Text('Route', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_showRouteMap) ...[
              const SizedBox(height: 14),
              const RouteMapWidget(),
            ],

            const SizedBox(height: 16),

            // Offer Main Box
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'BUSINESS POST',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                        ),
                      ),
                      Text(
                        post.targetLocation ?? 'Tamil Nadu',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(
                    post.title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 16),

                  if (post.images.isNotEmpty) ...[
                    CyclingPostImage(
                      images: post.images,
                      height: 180,
                      borderRadius: BorderRadius.circular(16),
                      interval: const Duration(seconds: 5),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 14),

                  const Text(
                    'Offer Description & Terms',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF111827), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Action Row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Offer voucher claimed! Present this at venue.')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B), // Amber 500
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Claim / Redeem Offer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => postService.toggleSavePost(post.postId),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: Icon(
                          post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: post.isSaved ? const Color(0xFF4F46E5) : const Color(0xFF374151),
                          size: 18,
                        ),
                        label: Text(
                          post.isSaved ? 'Saved' : 'Save',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: post.isSaved ? const Color(0xFF4F46E5) : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
