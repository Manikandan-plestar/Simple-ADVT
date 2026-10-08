import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/post_pricing_config.dart';
import '../models/target_location_model.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../services/in_app_purchase_service.dart';
import '../services/post_service.dart';
import '../widgets/business/create_post_modal.dart';
import '../widgets/business/cycling_post_image.dart';
import '../widgets/business/payment_success_dialog.dart';
import '../widgets/skeleton/skeleton_post_card.dart';
import '../utils/date_time_utils.dart';

class PostDetailsScreen extends StatefulWidget {
  final String postId;
  final PostItem? initialPost;

  const PostDetailsScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  PostItem? _post;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _activeImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _fetchPostDetails();
  }

  Future<void> _fetchPostDetails() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final postService = Provider.of<PostService>(context, listen: false);
    final user = authService.currentUser;

    setState(() {
      _isLoading = _post == null;
      _hasError = false;
    });

    try {
      final fetchedPost = await postService.fetchPostById(
        widget.postId,
        authToken: user.authToken,
        userId: user.userId.isNotEmpty ? user.userId : null,
        userEmail: user.email.isNotEmpty ? user.email : null,
      );

      if (mounted) {
        if (fetchedPost != null) {
          setState(() {
            _post = fetchedPost;
            _isLoading = false;
          });
        } else if (_post != null) {
          setState(() {
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Post not found or has expired.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_post == null) {
            _hasError = true;
            _errorMessage = 'Failed to load post details. Please try again.';
          }
        });
      }
    }
  }

  void _showImageViewer(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Post Photo', style: TextStyle(color: Colors.white, fontSize: 16)),
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

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('$label copied to clipboard'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openReshareModal(BuildContext context) {
    if (_post == null) return;
    final post = _post!;
    final postService = Provider.of<PostService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreatePostModal(
        initialPost: post,
        isReshare: true,
        modalTitle: 'Re-share Expired Post',
        submitButtonText: 'Pay & Re-share Post',
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
                  Text('Preparing secure re-share payment...'),
                ],
              ),
              backgroundColor: Color(0xFF4F46E5),
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // 1. Create new pending post with modified/retained data
          final pendingPost = await postService.createPendingPost(
            businessProfileId: post.businessProfileId,
            bizName: post.bizName,
            title: title,
            subtitle: subtitle,
            description: description,
            durationDays: durationDays,
            targetLocation: targetLocation,
            targetLocationItems: targetLocations,
            images: images ?? post.images,
            brandLogo: post.brandLogo,
            authToken: user.authToken,
            userId: user.userId,
            userEmail: user.email,
          );

          // 2. Start In-App Purchase Flow
          final purchaseResult = await InAppPurchaseService().buyPostSharing(
            option: durationOption,
            businessId: post.businessProfileId,
            pendingPostId: pendingPost.postId,
            authToken: user.authToken ?? '',
            userId: user.userId,
            userEmail: user.email,
          );

          if (!mounted) return;

          if (purchaseResult.success) {
            final PostItem activePost = (purchaseResult.serverResponse != null && purchaseResult.serverResponse!['post'] != null)
                ? PostItem.fromJson(purchaseResult.serverResponse!['post'] as Map<String, dynamic>)
                : pendingPost;

            setState(() {
              _post = activePost;
            });

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dCtx) => PaymentSuccessDialog(
                post: activePost,
                transactionId: purchaseResult.transactionId,
                onDismiss: () {
                  _fetchPostDetails();
                },
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(purchaseResult.message ?? 'Payment failed or was cancelled.'),
                backgroundColor: purchaseResult.isCancelled ? const Color(0xFF4B5563) : const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final postService = Provider.of<PostService>(context);
    final bizService = Provider.of<BusinessService>(context);

    if (_isLoading) {
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
            'Post Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: SkeletonPostCard(),
        ),
      );
    }

    if (_hasError || _post == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Post Details', style: TextStyle(color: Color(0xFF111827))),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage.isNotEmpty ? _errorMessage : 'Unable to view post.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _fetchPostDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final post = _post!;
    final isOwner = post.isOwner || post.payment != null;
    final isExpired = post.isPostExpired;
    final isSaved = post.isSaved;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // 1. App Bar Header with Post Images Carousel
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              // Save / Bookmark action for viewers
              if (!isOwner)
                CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.4),
                  child: IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: isSaved ? const Color(0xFF10B981) : Colors.white,
                      size: 20,
                    ),
                    tooltip: isSaved ? 'Saved' : 'Save Post',
                    onPressed: () {
                      postService.toggleSavePost(
                        post.postId,
                        authToken: authService.currentUser.authToken,
                        userId: authService.currentUser.userId,
                        userEmail: authService.currentUser.email,
                      );
                      setState(() {
                        post.isSaved = !post.isSaved;
                      });
                    },
                  ),
                ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (post.images.isNotEmpty)
                    PageView.builder(
                      itemCount: post.images.length,
                      onPageChanged: (idx) {
                        setState(() => _activeImageIndex = idx);
                      },
                      itemBuilder: (ctx, idx) {
                        final img = post.images[idx];
                        return GestureDetector(
                          onTap: () => _showImageViewer(context, img),
                          child: img.startsWith('http')
                              ? Image.network(img, fit: BoxFit.cover)
                              : (img.startsWith('assets/')
                                  ? Image.asset(img, fit: BoxFit.cover)
                                  : Image.file(File(img), fit: BoxFit.cover)),
                        );
                      },
                    )
                  else if (post.brandLogo != null && post.brandLogo!.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showImageViewer(context, post.brandLogo!),
                      child: Image.network(post.brandLogo!, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      color: const Color(0xFFEEF2FF),
                      child: const Center(
                        child: Icon(Icons.image_outlined, color: Color(0xFF4F46E5), size: 64),
                      ),
                    ),

                  // Gradient Scrim
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.3, 0.7, 1.0],
                          colors: [
                            Colors.black45,
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black54,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Carousel Indicators (if multiple images)
                  if (post.images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          post.images.length,
                          (idx) => Container(
                            width: _activeImageIndex == idx ? 20 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: _activeImageIndex == idx ? Colors.white : Colors.white54,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. Post Content and Information Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status & Post ID Badge Row
                  Row(
                    children: [
                      // Status Badge (Active vs Expired vs Pending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isExpired
                              ? const Color(0xFFFEE2E2)
                              : (post.status == 'active' ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isExpired
                                    ? const Color(0xFFEF4444)
                                    : (post.status == 'active' ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isExpired ? 'EXPIRED' : (post.status == 'active' ? 'ACTIVE' : 'PENDING PAYMENT'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isExpired
                                    ? const Color(0xFFDC2626)
                                    : (post.status == 'active' ? const Color(0xFF059669) : const Color(0xFFD97706)),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Post ID Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          post.postId,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Published Time
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            post.calculatedTimeAgo,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Expired Post Banner with Re-share Action (Visible to Business Owner)
                  if (isOwner && isExpired) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.history_toggle_off_rounded, color: Color(0xFFDC2626), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Post Expired',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tap Re-share to reactivate this post with your existing content.',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C), height: 1.25),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openReshareModal(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.replay_rounded, size: 16),
                            label: const Text('Re-share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Unified Post Information Card (Title, Subtitle, Description, Target Location)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Post Title
                        Text(
                          post.displayTitle,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                            height: 1.25,
                          ),
                        ),

                        // Post Subtitle (if available)
                        if (post.displaySubtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            post.displaySubtitle,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                              height: 1.3,
                            ),
                          ),
                        ],

                        // Description Section (About this Announcement)
                        if (post.description.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 12),
                          const Text(
                            'About this Announcement',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            post.description,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF334155),
                              height: 1.5,
                            ),
                          ),
                        ],

                        // Target Location below Description (Visible ONLY to Business Owner)
                        if (isOwner && post.displayLocation.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE0E7FF)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Target Audience Location',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        post.displayLocation,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E1B4B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ==========================================
                  // 3. OWNER-ONLY PAYMENT & TRANSACTION DETAILS
                  // ==========================================
                  if (isOwner) ...[
                    _buildOwnerPaymentSection(context, post),
                    const SizedBox(height: 20),
                  ],

                  // ==========================================
                  // 4. BUSINESS PROFILE CARD
                  // ==========================================
                  const Text(
                    'Published By Business',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (post.businessProfileId.isNotEmpty) {
                        Navigator.pushNamed(context, '/business-details', arguments: post.businessProfileId);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x04000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE0E7FF)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: (post.brandLogo != null && post.brandLogo!.isNotEmpty)
                                ? Image.network(post.brandLogo!, fit: BoxFit.cover)
                                : const Icon(Icons.storefront_rounded, color: Color(0xFF4F46E5), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.displayBizName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  post.businessProfileId,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Private owner-only billing and publication telemetry card
  Widget _buildOwnerPaymentSection(BuildContext context, PostItem post) {
    final payment = post.payment;
    final txId = payment?.transactionId ?? post.paymentId ?? 'N/A';
    final durationStr = '${post.durationDays} ${post.durationDays == 1 ? 'Day' : 'Days'}';
    final amountStr = payment != null
        ? '${payment.currency} ${payment.amount.toStringAsFixed(2)}'
        : 'Store Verified';
    final platformStr = payment?.platform.isNotEmpty == true
        ? payment!.platform.toUpperCase()
        : 'In-App Store';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Owner Billing & Publication Receipt',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'CONFIDENTIAL',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),

          // Details Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Published Time
                _buildReceiptRow(
                  icon: Icons.publish_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: 'Published At',
                  value: post.formattedPublishedAt,
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),

                // Expiration Time
                _buildReceiptRow(
                  icon: Icons.event_busy_rounded,
                  iconColor: post.isPostExpired ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                  label: 'Expires At',
                  value: post.formattedExpiresAt,
                  valueColor: post.isPostExpired ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                  isBold: true,
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),

                // Duration
                _buildReceiptRow(
                  icon: Icons.timelapse_rounded,
                  iconColor: const Color(0xFF4F46E5),
                  label: 'Selected Duration',
                  value: durationStr,
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),

                // Payment Status
                _buildReceiptRow(
                  icon: Icons.verified_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: 'Payment Status',
                  value: payment?.paymentStatus.toUpperCase() ?? 'COMPLETED',
                  valueColor: const Color(0xFF059669),
                  isBold: true,
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),

                // Payment Platform
                _buildReceiptRow(
                  icon: Icons.credit_card_rounded,
                  iconColor: const Color(0xFF64748B),
                  label: 'Payment Platform',
                  value: platformStr,
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),

                // Amount
                _buildReceiptRow(
                  icon: Icons.payments_outlined,
                  iconColor: const Color(0xFF059669),
                  label: 'Amount Paid',
                  value: amountStr,
                  isBold: true,
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),

                // Transaction ID with Copy Action
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.tag_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    const Text(
                      'Transaction ID',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const Spacer(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        txId,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (txId != 'N/A') ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _copyToClipboard(txId, 'Transaction ID'),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF4F46E5)),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 14),

                // Engagement Telemetry for Owner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 6),
                          Text(
                            '${post.moreInfoClickCount} Clicks',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                          ),
                        ],
                      ),
                      Container(height: 16, width: 1, color: const Color(0xFFCBD5E1)),
                      Row(
                        children: [
                          const Icon(Icons.bookmark_outline_rounded, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(
                            '${post.savedCount} Saves',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
