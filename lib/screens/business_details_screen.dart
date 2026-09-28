import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/target_location_model.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../services/post_service.dart';
import '../widgets/business/cycling_business_image.dart';
import '../widgets/business/create_post_modal.dart';
import '../widgets/home/post_card.dart';
import '../widgets/skeleton/skeleton_post_card.dart';

class BusinessDetailsScreen extends StatefulWidget {
  final String businessProfileId;

  const BusinessDetailsScreen({
    super.key,
    required this.businessProfileId,
  });

  @override
  State<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isInitialLoaded = false;
  bool _showStickyHeader = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialLoaded) {
      _isInitialLoaded = true;
      _loadData();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 200;
    if (_showStickyHeader != show) {
      setState(() {
        _showStickyHeader = show;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final bizService = Provider.of<BusinessService>(context, listen: false);
    final postService = Provider.of<PostService>(context, listen: false);

    // 1. Fetch this business profile
    await bizService.fetchBusinessById(widget.businessProfileId);

    // 2. Fetch user's businesses if logged in (for ownership)
    if (authService.currentUser.userId.isNotEmpty) {
      await bizService.fetchUserBusinesses(
        userId: authService.currentUser.userId,
        authToken: authService.currentUser.authToken,
        userEmail: authService.currentUser.email,
      );
    }

    // 3. Fetch posts for this business
    await postService.fetchPosts(businessId: widget.businessProfileId);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool _checkIsOwner(BusinessProfile biz, UserProfile user) {
    if (user.userId.isEmpty) return false;
    if (biz.ownerUserId == user.userId) return true;
    final bNum = int.tryParse(biz.ownerUserId.replaceAll(RegExp(r'[^0-9]'), ''));
    final uNum = int.tryParse(user.userId.replaceAll(RegExp(r'[^0-9]'), ''));
    if (bNum != null && uNum != null && bNum == uNum) return true;
    return false;
  }

  void _openCreatePostModal(BuildContext context, BusinessProfile biz) {
    final postService = Provider.of<PostService>(context, listen: false);
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
          List<TargetLocationModel>? targetLocations,
          List<String>? images,
        }) async {
          await postService.createPost(
            businessProfileId: biz.businessProfileId,
            bizName: biz.name,
            title: title,
            subtitle: subtitle,
            description: description,
            targetLocation: targetLocation,
            targetLocationItems: targetLocations,
            images: images,
            brandLogo: biz.image,
            authToken: authService.currentUser.authToken,
            userId: authService.currentUser.userId,
            userEmail: authService.currentUser.email,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Post published successfully!'),
                backgroundColor: Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _loadData();
          }
        },
      ),
    );
  }

  void _confirmDeleteBusiness(BuildContext context, BusinessProfile biz) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final bizService = Provider.of<BusinessService>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Business Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to permanently delete "${biz.name}" and all its posts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await bizService.deleteBusinessProfile(
                biz.businessProfileId,
                callerUserId: authService.currentUser.userId,
                authToken: authService.currentUser.authToken,
                userEmail: authService.currentUser.email,
              );
              if (mounted) {
                if (success) {
                  Navigator.pop(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showOwnerActionsModal(BuildContext context, BusinessProfile biz) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      biz.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_outlined, color: Color(0xFF4F46E5), size: 20),
                ),
                title: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
                subtitle: const Text(
                  'Update business details, photos, and contact info',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/edit-biz', arguments: biz.businessProfileId);
                },
              ),
              const Divider(height: 16, color: Color(0xFFF3F4F6)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981), size: 20),
                ),
                title: const Text(
                  'New Post',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
                subtitle: const Text(
                  'Create and publish a new announcement or post',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openCreatePostModal(context, biz);
                },
              ),
              const Divider(height: 16, color: Color(0xFFF3F4F6)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
                ),
                subtitle: const Text(
                  'Permanently remove this business profile and all posts',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFEF4444)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteBusiness(context, biz);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageViewer(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: imageUrl.startsWith('http')
                  ? Image.network(imageUrl, fit: BoxFit.contain)
                  : Image.file(File(imageUrl), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final bizService = Provider.of<BusinessService>(context);
    final postService = Provider.of<PostService>(context);

    final biz = bizService.getBusinessById(widget.businessProfileId) ??
        BusinessProfile(
          businessProfileId: widget.businessProfileId,
          ownerUserId: "U001",
          name: "Business Profile",
          category: "Store",
          location: "Palayamkottai, Tirunelveli",
          image: "https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=600&q=80",
          about: "",
        );

    final isOwner = _checkIsOwner(biz, authService.currentUser);
    final cleanBizId = biz.businessProfileId.replaceAll(RegExp(r'[^0-9]'), '');
    final bizPosts = postService.allPosts.where((p) {
      if (p.businessProfileId == biz.businessProfileId) return true;
      if (cleanBizId.isNotEmpty && p.businessProfileId.replaceAll(RegExp(r'[^0-9]'), '') == cleanBizId) return true;
      return false;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1. Header Sliver with Clean Navigation & Overflow Menu
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827), size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  if (isOwner)
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF111827), size: 24),
                      tooltip: 'More options',
                      onPressed: () => _showOwnerActionsModal(context, biz),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: GestureDetector(
                    onTap: () {
                      if (biz.image.isNotEmpty) {
                        _showImageViewer(context, biz.image);
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CyclingBusinessImage(
                          images: biz.images,
                          height: 240,
                          borderRadius: BorderRadius.zero,
                          interval: const Duration(seconds: 5),
                          emptyWidget: Container(
                            color: const Color(0xFFEEF2FF),
                            child: const Center(
                              child: Icon(Icons.storefront_rounded, color: Color(0xFF4F46E5), size: 64),
                            ),
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black38, Colors.transparent, Colors.black45],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Business Profile Details & Actions Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Business Title & Follow Action
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  biz.displayName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        biz.displayCategory.toUpperCase(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFEF4444)),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        biz.displayCity.isNotEmpty ? biz.displayCity : biz.displayLocation,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!isOwner) ...[
                            ElevatedButton.icon(
                              onPressed: () {
                                bizService.toggleFollow(
                                  biz.businessProfileId,
                                  authToken: authService.currentUser.authToken,
                                  userId: authService.currentUser.userId,
                                  userEmail: authService.currentUser.email,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: biz.isFollowed ? const Color(0xFFF3F4F6) : const Color(0xFF4F46E5),
                                foregroundColor: biz.isFollowed ? const Color(0xFF374151) : Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(
                                biz.isFollowed ? Icons.check_rounded : Icons.add_rounded,
                                size: 16,
                              ),
                              label: Text(
                                biz.isFollowed ? 'Following' : 'Follow',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Business About & Details
                      if (biz.about.isNotEmpty) ...[
                        Text(
                          biz.about,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Address & Contact Bar
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                        ),
                        child: Column(
                          children: [
                            if (biz.registeredAddress.isNotEmpty)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.place_outlined, size: 16, color: Color(0xFF4F46E5)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      biz.registeredAddress,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                                    ),
                                  ),
                                ],
                              ),
                            if (biz.phone.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF059669)),
                                  const SizedBox(width: 8),
                                  Text(
                                    biz.phone,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Owner's "+ New Post" Action Bar
                      if (isOwner) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _openCreatePostModal(context, biz),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('New Post', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Posts Feed Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Business Posts',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                          ),
                          Text(
                            '${bizPosts.length} posts',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // 3. Posts Feed List
              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: SkeletonPostCard(),
                      ),
                      childCount: 2,
                    ),
                  ),
                )
              else if (bizPosts.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.post_add_rounded, color: Color(0xFF4F46E5), size: 28),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No Posts Published Yet',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOwner
                                ? 'Tap "+ New Post" above to publish your first announcement.'
                                : 'Check back soon for updates from this business.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = bizPosts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: PostCard(
                            item: post,
                            onView: () {},
                            onToggleSave: () {
                              postService.toggleSavePost(
                                post.postId,
                                authToken: authService.currentUser.authToken,
                                userId: authService.currentUser.userId,
                                userEmail: authService.currentUser.email,
                              );
                            },
                          ),
                        );
                      },
                      childCount: bizPosts.length,
                    ),
                  ),
                ),
            ],
          ),

          // Sticky Compact Header after scrolling
          if (_showStickyHeader)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        biz.displayName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOwner)
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF111827), size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showOwnerActionsModal(context, biz),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
