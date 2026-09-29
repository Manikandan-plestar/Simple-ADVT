import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/business_service.dart';
import '../services/notification_service.dart';
import '../widgets/common/bottom_navigation.dart';
import '../widgets/common/empty_state.dart';
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
    final notifService = Provider.of<NotificationService>(context);
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

    final userDisplayName = user.name.trim().isNotEmpty
        ? TextUtils.capitalizeWords(user.name.trim().split(' ').first)
        : 'User';

    return Column(
      children: [
        // ==========================================
        // 1. PINNED TOP HEADER: Logo, User, Location, Search Bar, Notification Bell
        // ==========================================
        Container(
          color: Colors.white,
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

              // 2. Pinned Search Bar
              Container(
                height: 44,
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ==========================================
        // 2. CARD STACK AREA: Tinder-Style Horizontal Swipe Deck
        // ==========================================
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 74), // Spacing above scooped bottom nav
            child: isLoading && allPosts.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  )
                : filteredPosts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: EmptyStateWidget(
                            icon: Icons.location_off_rounded,
                            title: _searchQuery.isNotEmpty ? 'No matches found' : 'No posts in your area yet',
                            subtitle: _searchQuery.isNotEmpty
                                ? 'Try searching with a different business name or keyword.'
                                : 'Posts targeting ${_formatUserLocationDisplay(user)} will appear here once published by businesses.',
                          ),
                        ),
                      )
                    : TinderCardDeck(
                        posts: filteredPosts,
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
    );
  }
}
