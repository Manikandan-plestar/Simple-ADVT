import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/business_service.dart';
import '../widgets/common/bottom_navigation.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/home/post_card.dart';
import '../widgets/skeleton/skeleton_post_card.dart';
import '../utils/text_utils.dart';
import 'saved_items_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;

  const HomeScreen({super.key, this.initialTabIndex = 1});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentBottomNavIndex;
  final _searchController = TextEditingController();
  bool _isInitialLoaded = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentBottomNavIndex = widget.initialTabIndex;
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
    _searchController.dispose();
    super.dispose();
  }

  String _formatUserLocationDisplay(UserProfile user) {
    if (user.locality.isNotEmpty && user.city.isNotEmpty && user.locality != user.city) {
      return '${TextUtils.capitalizeWords(user.locality)}, ${TextUtils.capitalizeWords(user.city)}';
    }
    if (user.city.isNotEmpty) return TextUtils.capitalizeWords(user.city);
    if (user.locality.isNotEmpty) return TextUtils.capitalizeWords(user.locality);
    if (user.state.isNotEmpty) return TextUtils.capitalizeWords(user.state);

    if (user.address.isNotEmpty) {
      final parts = user.address.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        return '${TextUtils.capitalizeWords(parts[parts.length - 2])}, ${TextUtils.capitalizeWords(parts[parts.length - 1].split('-')[0].trim())}';
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
            // 1: Explore (Center - Main discovery screen)
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
                  setState(() {
                    _currentBottomNavIndex = index;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreTab() {
    final authService = Provider.of<AuthService>(context);
    final postService = Provider.of<PostService>(context);
    final user = authService.currentUser;
    final allPosts = postService.allPosts;
    final isLoading = postService.isLoading;

    // Filter posts by search query if user typed in the explore search bar
    final filteredPosts = _searchQuery.isEmpty
        ? allPosts
        : allPosts.where((p) {
            final q = _searchQuery.toLowerCase();
            return p.title.toLowerCase().contains(q) ||
                p.bizName.toLowerCase().contains(q) ||
                p.description.toLowerCase().contains(q) ||
                (p.targetLocation?.toLowerCase().contains(q) ?? false);
          }).toList();

    final userFirstName = user.name.trim().isNotEmpty
        ? TextUtils.capitalizeWords(user.name.trim().split(' ').first)
        : 'User';

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: const Color(0xFF4F46E5),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Explore App Bar & Header
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: User Greeting & Location Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.explore_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Explore Simple ADVT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Hello, $userFirstName',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Location pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE0E7FF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                _formatUserLocationDisplay(user),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Integrated Search Bar in Explore
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search businesses or posts in your area...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF9CA3AF)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Location Targeting Feed Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Relevant For You',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Text(
                          'LOCATION MATCHED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isLoading)
                    Text(
                      '${filteredPosts.length} post${filteredPosts.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                    ),
                ],
              ),
            ),
          ),

          // Feed Content: Skeleton loading or Post list or Empty state
          if (isLoading && allPosts.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SkeletonPostCard(),
                  ),
                  childCount: 4,
                ),
              ),
            )
          else if (filteredPosts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: EmptyStateWidget(
                  icon: Icons.location_off_rounded,
                  title: _searchQuery.isNotEmpty ? 'No matches found' : 'No posts in your area yet',
                  subtitle: _searchQuery.isNotEmpty
                      ? 'Try searching with a different business name or keyword.'
                      : 'Posts targeting ${_formatUserLocationDisplay(user)} will appear here once published by businesses.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = filteredPosts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PostCard(
                        post: post,
                        onBookmarkTap: () {
                          postService.toggleSavePost(
                            post.postId,
                            authToken: user.authToken,
                            userId: user.userId,
                            userEmail: user.email,
                          );
                        },
                      ),
                    );
                  },
                  childCount: filteredPosts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
