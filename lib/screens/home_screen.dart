import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/target_location_model.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/business_service.dart';
import '../services/notification_service.dart';
import '../widgets/common/bottom_navigation.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/business/create_post_modal.dart';
import '../widgets/home/business_card.dart';
import '../widgets/skeleton/skeleton_business_card.dart';
import '../utils/text_utils.dart';
import 'notifications_screen.dart';
import 'saved_items_screen.dart';
import 'settings_screen.dart';
import '../widgets/home/tinder_card_deck.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;

  const HomeScreen({super.key, this.initialTabIndex = 1});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentBottomNavIndex;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;
  bool _isInitialLoaded = false;
  String _searchQuery = '';
  bool _isSearchFocused = false;
  bool _isSearching = false;
  List<BusinessProfile> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _currentBottomNavIndex = widget.initialTabIndex;
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  void _onSearchFocusChanged() {
    if (mounted) {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    }
  }

  void _onSearchChanged(String val) {
    final query = val.trim();
    _searchDebounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });

    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () async {
      final bizService = Provider.of<BusinessService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      final results = await bizService.searchBusinessProfiles(
        query,
        authToken: user.authToken,
        userId: user.userId,
        userEmail: user.email,
      );

      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _clearSearch() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _isSearching = false;
    });
    _searchFocusNode.requestFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialLoaded) {
      _isInitialLoaded = true;
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final postService = Provider.of<PostService>(context, listen: false);
    final bizService = Provider.of<BusinessService>(context, listen: false);

    final user = authService.currentUser;

    // Fetch posts targeted for the user's registered location
    await postService.fetchPosts(
      authToken: user.authToken,
      userId: user.userId,
      userEmail: user.email,
      location: user.city.isNotEmpty ? user.city : (user.locality.isNotEmpty ? user.locality : user.state),
      locality: user.locality,
      city: user.city,
      state: user.state,
      country: user.country,
    );

    if (user.userId.isNotEmpty) {
      await bizService.fetchUserBusinesses(
        userId: user.userId,
        authToken: user.authToken,
        userEmail: user.email,
      );
      await bizService.fetchFollowedBusinesses(
        userId: user.userId,
        authToken: user.authToken,
        userEmail: user.email,
      );
      await postService.fetchSavedPosts(
        authToken: user.authToken,
        userId: user.userId,
        userEmail: user.email,
      );
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatUserLocationDisplay(UserProfile user) {
    if (user.locality.isNotEmpty && user.city.isNotEmpty && user.locality.toLowerCase() != user.city.toLowerCase()) {
      return '${TextUtils.capitalizeWords(user.locality)}, ${TextUtils.capitalizeWords(user.city)}';
    }
    if (user.locality.isNotEmpty) return TextUtils.capitalizeWords(user.locality);
    if (user.city.isNotEmpty) return TextUtils.capitalizeWords(user.city);
    if (user.state.isNotEmpty) return TextUtils.capitalizeWords(user.state);

    if (user.address.isNotEmpty) {
      final parts = user.address.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        return '${TextUtils.capitalizeWords(parts[0])}, ${TextUtils.capitalizeWords(parts[1].split('-')[0].trim())}';
      } else if (parts.isNotEmpty) {
        return TextUtils.capitalizeWords(parts.first);
      }
    }
    return 'Palayamkottai, Tirunelveli';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            // Exact 3 bottom navigation tabs:
            // 0: Saved (Left)
            // 1: Explore (Center - Tinder-Style Card Stack)
            // 2: Settings (Right - My Profile, Business Profile, Followed, Logout)
            IndexedStack(
              index: _currentBottomNavIndex,
              children: [
                const SavedItemsScreen(isTab: true),
                _buildExploreTab(),
                const SettingsScreen(),
              ],
            ),

            // Bottom Navigation Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomBottomNavigation(
                currentIndex: _currentBottomNavIndex,
                onTap: (index) {
                  if (index == _currentBottomNavIndex) {
                    if (index == 1) {
                      // Active Explore tab tapped -> Directly check business profile & open New Post flow
                      _handleNewPostFlow();
                    }
                  } else {
                    setState(() {
                      _currentBottomNavIndex = index;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles New Post flow according to business profile ownership cases
  Future<void> _handleNewPostFlow() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final bizService = Provider.of<BusinessService>(context, listen: false);
    final user = authService.currentUser;

    // Check user owned business profiles
    List<BusinessProfile> userBusinesses = bizService.getUserBusinesses(user.userId);

    if (userBusinesses.isEmpty && user.userId.isNotEmpty) {
      userBusinesses = await bizService.fetchUserBusinesses(
        userId: user.userId,
        authToken: user.authToken,
        userEmail: user.email,
      );
    }

    if (!mounted) return;

    // Case 3: No Business Profile
    if (userBusinesses.isEmpty) {
      _showNoBusinessProfileDialog();
      return;
    }

    // Case 2: Only One Business Profile -> Directly open Post Creation Form
    if (userBusinesses.length == 1) {
      _openCreatePostModalForBiz(userBusinesses.first);
      return;
    }

    // Case 1: Multiple Business Profiles -> Show Selection Screen
    _showBusinessProfileSelectionModal(userBusinesses);
  }

  /// Case 3 Dialog: User has no business profiles
  void _showNoBusinessProfileDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_outlined, color: Color(0xFFD97706), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Business Profile Required',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'You need an active business profile to create and publish advertisement posts on Simple ADVT.',
          style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/create-biz');
            },
            child: const Text('Create Business'),
          ),
        ],
      ),
    );
  }

  /// Case 1 Modal: User has multiple business profiles
  void _showBusinessProfileSelectionModal(List<BusinessProfile> userBusinesses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.business_rounded, color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Business Profile',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Choose a profile to publish this new post',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: userBusinesses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final biz = userBusinesses[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openCreatePostModalForBiz(biz);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            // Business Avatar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 46,
                                height: 46,
                                color: const Color(0xFFEEF2FF),
                                child: biz.image.isNotEmpty
                                    ? Image.network(
                                        biz.image,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.storefront_rounded,
                                          color: Color(0xFF4F46E5),
                                          size: 24,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.storefront_rounded,
                                        color: Color(0xFF4F46E5),
                                        size: 24,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Business Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    biz.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${biz.displayCategory} • ${biz.displayLocation}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF94A3B8),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Opens Create Post Modal for the selected BusinessProfile
  void _openCreatePostModalForBiz(BusinessProfile biz) {
    final postService = Provider.of<PostService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreatePostModal(
        modalTitle: 'New Post for ${biz.displayName}',
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
            _loadInitialData();
          }
        },
      ),
    );
  }

  Widget _buildExploreTab() {
    final authService = Provider.of<AuthService>(context);
    final postService = Provider.of<PostService>(context);
    final notifService = Provider.of<NotificationService>(context);
    final user = authService.currentUser;
    final allPosts = postService.allPosts;
    final isLoading = postService.isLoading;

    final userDisplayName = user.name.trim().isNotEmpty
        ? TextUtils.capitalizeWords(user.name.trim().split(' ').first)
        : 'User';

    final isSearchActive = _isSearchFocused || _searchController.text.isNotEmpty;

    return PopScope(
      canPop: !isSearchActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _searchFocusNode.unfocus();
          _clearSearch();
          setState(() {
            _isSearchFocused = false;
          });
        }
      },
      child: Stack(
        children: [
          // ==========================================
          // 1. CARD STACK AREA: Tinder-Style Horizontal Swipe Deck
          // ==========================================
          Column(
            children: [
              // Spacer corresponding to header height
              const SizedBox(height: 124),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 74), // Spacing above scooped bottom nav
                  child: isLoading && allPosts.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                        )
                      : allPosts.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: EmptyStateWidget(
                                  icon: Icons.location_off_rounded,
                                  title: 'No posts in your area yet',
                                  subtitle:
                                      'Posts targeting ${_formatUserLocationDisplay(user)} will appear here once published by businesses.',
                                ),
                              ),
                            )
                          : TinderCardDeck(
                              posts: allPosts,
                              onReload: _loadInitialData,
                              onMoreInfoClick: (post) {
                                postService.trackMoreInfoClick(
                                  post.postId,
                                  authToken: user.authToken,
                                  userId: user.userId,
                                  userEmail: user.email,
                                );
                              },
                              onToggleSave: (post) {
                                postService.toggleSavePost(
                                  post.postId,
                                  authToken: user.authToken,
                                  userId: user.userId,
                                  userEmail: user.email,
                                );
                              },
                              onBusinessTap: (post) {
                                if (post.businessProfileId.isNotEmpty) {
                                  Navigator.pushNamed(context, '/business-details', arguments: post.businessProfileId);
                                }
                              },
                            ),
                ),
              ),
            ],
          ),

          // ==========================================
          // 2. DIM / BLUR OVERLAY LAYER (When Search is Focused / Active)
          // ==========================================
          if (isSearchActive)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _searchFocusNode.unfocus();
                  setState(() {
                    _isSearchFocused = false;
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.35),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            ),

          // ==========================================
          // 3. PINNED TOP HEADER + FOREGROUND SEARCH + SEARCH RESULTS
          // ==========================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: isSearchActive ? 74 : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Card (Background and Search Bar)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: isSearchActive
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Row: Left Image Logo + User Greeting/Location + Notification Bell
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Left Corner Image Logo
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/images/explore_header.jpg',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.campaign_rounded,
                                    size: 26,
                                    color: Color(0xFF4F46E5),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 2. Center Column: Hello, Username & Location below
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Hello, $userDisplayName',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 14,
                                      color: Color(0xFF4F46E5),
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        _formatUserLocationDisplay(user),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 3. Right: Notification Bell Button with badge
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                );
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(
                                      Icons.notifications_none_rounded,
                                      color: Color(0xFF1F2937),
                                      size: 21,
                                    ),
                                    if (notifService.unreadCount > 0)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 2. Foreground Search Bar with exact placeholder
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isSearchFocused ? Colors.white : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isSearchFocused ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
                            width: _isSearchFocused ? 1.5 : 1,
                          ),
                          boxShadow: _isSearchFocused
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withOpacity(0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 12, right: 8),
                              child: Icon(
                                Icons.search_rounded,
                                color: Color(0xFF4F46E5),
                                size: 20,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: _onSearchChanged,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF111827),
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Search a category or shop/business',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.normal,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B7280)),
                                splashRadius: 18,
                                onPressed: _clearSearch,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Results Dropdown List directly below Search Bar
                if (isSearchActive)
                  Expanded(
                    child: _buildSearchResultsOverlay(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsOverlay() {
    if (_isSearching) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const SkeletonBusinessCard(),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _searchFocusNode.unfocus();
          setState(() => _isSearchFocused = false);
        },
        child: const SizedBox.expand(),
      );
    }

    if (_searchResults.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_outlined, size: 36, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                Text(
                  'No businesses found for "${_searchController.text.trim()}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Try searching by another shop name or category (e.g. Dress Shop, Electronics).',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final biz = _searchResults[index];
        return BusinessCard(
          business: biz,
          onTap: () {
            _searchFocusNode.unfocus();
            Navigator.pushNamed(
              context,
              '/business-details',
              arguments: biz.businessProfileId,
            );
          },
        );
      },
    );
  }
}
