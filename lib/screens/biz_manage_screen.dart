import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/target_location_model.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../services/post_service.dart';
import '../widgets/business/create_post_modal.dart';
import '../widgets/business/cycling_post_image.dart';
import '../config/post_pricing_config.dart';
import '../services/in_app_purchase_service.dart';
import '../widgets/business/payment_success_dialog.dart';

class BizManageScreen extends StatefulWidget {
  const BizManageScreen({super.key});

  @override
  State<BizManageScreen> createState() => _BizManageScreenState();
}

class _BizManageScreenState extends State<BizManageScreen> {
  bool _isInitialLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialLoaded) {
      _isInitialLoaded = true;
      final bizService = Provider.of<BusinessService>(context, listen: false);
      final postService = Provider.of<PostService>(context, listen: false);
      final activeBiz = bizService.activeBusiness;
      if (activeBiz != null) {
        postService.fetchPosts(businessId: activeBiz.businessProfileId);
      }
    }
  }

  void _openCreatePostModal(BuildContext context, String bizId, String bizName) {
    final postService = Provider.of<PostService>(context, listen: false);
    final bizService = Provider.of<BusinessService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreatePostModal(
        onSubmit: ({
          required String title,
          required String subtitle,
          required String description,
          required String targetLocation,
          required int durationDays,
          required PostDurationOption durationOption,
          List<TargetLocationModel>? targetLocations,
          List<String>? images,
        }) async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  SizedBox(width: 12),
                  Text('Preparing secure post payment...'),
                ],
              ),
              backgroundColor: Color(0xFF4F46E5),
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // 1. Create pending post
          final pendingPost = await postService.createPendingPost(
            businessProfileId: bizId,
            bizName: bizName,
            title: title,
            subtitle: subtitle,
            description: description,
            durationDays: durationDays,
            targetLocation: targetLocation,
            targetLocationItems: targetLocations,
            images: images,
            authToken: authService.currentUser.authToken,
            userId: authService.currentUser.userId,
            userEmail: authService.currentUser.email,
          );

          // 2. Start IAP flow
          final purchaseResult = await InAppPurchaseService().buyPostSharing(
            option: durationOption,
            businessId: bizId,
            pendingPostId: pendingPost.postId,
            authToken: authService.currentUser.authToken ?? '',
            userId: authService.currentUser.userId,
            userEmail: authService.currentUser.email,
          );

          if (!mounted) return;

          if (purchaseResult.success) {
            final PostItem activePost = (purchaseResult.serverResponse != null && purchaseResult.serverResponse!['post'] != null)
                ? PostItem.fromJson(purchaseResult.serverResponse!['post'] as Map<String, dynamic>)
                : pendingPost;

            bizService.addPostToBusiness(bizId, activePost);
            postService.fetchPosts(businessId: bizId);

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dCtx) => PaymentSuccessDialog(
                post: activePost,
                transactionId: purchaseResult.transactionId,
                onDismiss: () {
                  postService.fetchPosts(businessId: bizId);
                },
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(purchaseResult.message ?? 'Payment failed or was cancelled. Post was not published.'),
                backgroundColor: purchaseResult.isCancelled ? const Color(0xFF4B5563) : const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDeletePost(BuildContext context, PostItem post, String bizId) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final postService = Provider.of<PostService>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to delete "${post.displayTitle}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await postService.deletePost(
                post.postId,
                callerBusinessProfileId: bizId,
                authToken: authService.currentUser.authToken,
                userId: authService.currentUser.userId,
                userEmail: authService.currentUser.email,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Post deleted successfully.' : 'Failed to delete post.'),
                    backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bizService = Provider.of<BusinessService>(context);
    final postService = Provider.of<PostService>(context);
    final activeBiz = bizService.activeBusiness;

    if (activeBiz == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Business Management')),
        body: const Center(child: Text('No active business selected')),
      );
    }

    // Refresh posts dynamically from postService to ensure deleted posts disappear immediately
    final cleanActiveBizId = activeBiz.businessProfileId.replaceAll(RegExp(r'[^0-9]'), '');
    final bizPosts = postService.allPosts.where((p) {
      final pBizNum = p.numericBusinessId?.toString();
      final pBizId = p.businessProfileId.replaceAll(RegExp(r'[^0-9]'), '');
      return p.businessProfileId == activeBiz.businessProfileId ||
          (cleanActiveBizId.isNotEmpty && pBizId == cleanActiveBizId) ||
          (cleanActiveBizId.isNotEmpty && pBizNum == cleanActiveBizId);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeBiz.displayName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            Text(
              '${activeBiz.displayCategory} • ${activeBiz.displayLocation}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF4F46E5)),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.pushNamed(context, '/edit-biz', arguments: activeBiz.businessProfileId);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await postService.fetchPosts(businessId: activeBiz.businessProfileId);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Single "+ New Post" Creation Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _openCreatePostModal(context, activeBiz.businessProfileId, activeBiz.name),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Post', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'ACTIVE LISTINGS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),

              if (bizPosts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'No active postings',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Use the buttons above to post job vacancies, discounts, or coupons.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bizPosts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final post = bizPosts[index];
                    final isJob = post.type == 'job';
                    final isCoupon = post.type == 'coupon';

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pushNamed(context, '/post-details', arguments: post.postId);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x04000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // If post has images, display cycling post images with 5s interval
                            if (post.images.isNotEmpty)
                              CyclingPostImage(
                                images: post.images,
                                height: 140,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                interval: const Duration(seconds: 5),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: isJob
                                              ? const Color(0xFFEEF2FF)
                                              : (isCoupon ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB)),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isJob ? 'JOB' : (isCoupon ? 'COUPON' : 'OFFER'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isJob
                                                ? const Color(0xFF4F46E5)
                                                : (isCoupon ? const Color(0xFF047857) : const Color(0xFFD97706)),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF9CA3AF)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Delete Post',
                                        onPressed: () => _confirmDeletePost(context, post, activeBiz.businessProfileId),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    post.displayTitle,
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    post.displaySubtitle,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    post.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF4B5563), height: 1.3),
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                                  const SizedBox(height: 8),

                                  // Bottom Footer: Target Location (left) + Post Time (bottom-right corner)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      if (post.targetLocation != null && post.targetLocation!.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF9CA3AF)),
                                            const SizedBox(width: 3),
                                            Text(
                                              post.displayLocation,
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        )
                                      else
                                        const SizedBox.shrink(),
                                      Text(
                                        post.formattedPostTime,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF9CA3AF),
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
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
