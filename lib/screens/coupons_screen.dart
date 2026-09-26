import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/post_service.dart';
import '../services/business_service.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/notification_bell_button.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  String _selectedFilter = 'all'; // 'all', 'active', 'trending', 'electronics', 'healthcare', 'services', 'expired'
  final _searchController = TextEditingController();
  bool _isFilterOpen = false;
  bool _isInitialLoaded = false;

  final Map<String, String> _filterLabels = {
    'all': 'All Coupons',
    'active': 'Active Deals',
    'trending': 'Trending',
    'electronics': 'Electronics',
    'healthcare': 'Healthcare',
    'services': 'Services',
    'expired': 'Expired Deals',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialLoaded) {
      _isInitialLoaded = true;
      final postService = Provider.of<PostService>(context, listen: false);
      postService.fetchPosts(postType: 'coupon');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getBadgeColor(String? badge) {
    if (badge == null) return const Color(0xFF4B5563);
    final b = badge.toLowerCase();
    if (b.contains('liked')) return const Color(0xFF2563EB);
    if (b.contains('expired')) return const Color(0xFF6B7280);
    if (b.contains('active') || b.contains('7d') || b.contains('left')) return const Color(0xFF059669);
    return const Color(0xFF4F46E5);
  }

  @override
  Widget build(BuildContext context) {
    final postService = Provider.of<PostService>(context);
    final bizService = Provider.of<BusinessService>(context);
    final allCoupons = postService.allCoupons;

    final query = _searchController.text.trim().toLowerCase();
    final filteredCoupons = allCoupons.where((c) {
      if (_selectedFilter == 'active' && (c.badgeText?.toLowerCase() == 'expired')) {
        return false;
      }
      if (_selectedFilter == 'expired' && (c.badgeText?.toLowerCase() != 'expired')) {
        return false;
      }
      if (_selectedFilter == 'trending' && !(c.badgeText?.toLowerCase().contains('liked') ?? false)) {
        return false;
      }
      if (_selectedFilter == 'healthcare' && !c.bizName.toLowerCase().contains('dental')) {
        return false;
      }
      if (_selectedFilter == 'electronics' &&
          !c.title.toLowerCase().contains('earbud') &&
          !c.subtitle.toLowerCase().contains('earbud') &&
          !c.subtitle.toLowerCase().contains('appliance')) {
        return false;
      }
      if (_selectedFilter == 'services' &&
          !c.bizName.toLowerCase().contains('electrical') &&
          !c.bizName.toLowerCase().contains('tech')) {
        return false;
      }

      if (query.isNotEmpty) {
        final matchTitle = c.title.toLowerCase().contains(query);
        final matchSubtitle = c.subtitle.toLowerCase().contains(query);
        final matchBiz = c.bizName.toLowerCase().contains(query);
        final matchDiscount = (c.discount ?? '').toLowerCase().contains(query);
        return matchTitle || matchSubtitle || matchBiz || matchDiscount;
      }

      return true;
    }).toList();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8FAFC), // Light application background
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Light Top Header Bar: Title + Search & Filter Row
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 42,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Text(
                            'Coupons',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                              letterSpacing: -0.3,
                            ),
                          ),
                          NotificationBellButton(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search Bar and Filter Icon in the same horizontal row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9CA3AF)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (_) => setState(() {}),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF111827),
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Search coupons...',
                                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9CA3AF)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isFilterOpen = !_isFilterOpen;
                            });
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.filter_alt_rounded, color: Colors.white, size: 19),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Coupon Feed Heading & Active Filter Indicator
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _searchController.text.trim().isNotEmpty
                          ? 'Matching Coupons (${filteredCoupons.length})'
                          : (_filterLabels[_selectedFilter] ?? 'All Coupons'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (_selectedFilter != 'all')
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilter = 'all';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedFilter.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.close_rounded, size: 12, color: Color(0xFF4F46E5)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Coupons Grid Feed
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await postService.fetchPosts(postType: 'coupon');
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 6, bottom: 96),
                    child: filteredCoupons.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          alignment: Alignment.center,
                          child: EmptyStateWidget(
                            icon: Icons.confirmation_number_outlined,
                            title: _searchController.text.trim().isNotEmpty
                                ? 'No coupons found for "${_searchController.text.trim()}"'
                                : 'No coupons in this category',
                            subtitle: 'Try searching with another keyword or reset the filter.',
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredCoupons.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.74,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemBuilder: (context, index) {
                            final coupon = filteredCoupons[index];
                            final isExpired = coupon.badgeText?.toLowerCase() == 'expired';

                            return GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/coupon-details',
                                  arguments: coupon.postId,
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFF3F4F6),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x06000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Top Banner Image Section
                                    Expanded(
                                      flex: 5,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Background Image
                                          if (coupon.images.isNotEmpty)
                                            Image.network(
                                              coupon.images.first,
                                              fit: BoxFit.cover,
                                              color: isExpired ? Colors.black.withOpacity(0.3) : null,
                                              colorBlendMode: isExpired ? BlendMode.darken : null,
                                              errorBuilder: (_, __, ___) => _buildPlaceholderBackground(coupon),
                                            )
                                          else
                                            _buildPlaceholderBackground(coupon),

                                          // Subtle gradient overlay for badge visibility
                                          Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.black38,
                                                  Colors.transparent,
                                                  Colors.black26,
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Top-Right Status Badge Pill
                                          if (coupon.badgeText != null && coupon.badgeText!.isNotEmpty)
                                            Positioned(
                                              top: 9,
                                              right: 9,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: _getBadgeColor(coupon.badgeText),
                                                  borderRadius: BorderRadius.circular(10),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Colors.black26,
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  coupon.badgeText!,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Bottom Text Section (Light theme card footer)
                                    Expanded(
                                      flex: 4,
                                      child: Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            // Big Discount Headline
                                            Text(
                                              coupon.discount ?? coupon.title,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF111827),
                                                letterSpacing: -0.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),

                                            // Subtitle / Description text
                                            Text(
                                              coupon.subtitle,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: Color(0xFF6B7280),
                                                height: 1.25,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ),
              ),
            ],
          ),

          // Filter Dropdown Overlay
          if (_isFilterOpen)
            Positioned(
              top: 96,
              right: 20,
              child: Container(
                width: 190,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _filterLabels.entries.map((entry) {
                    final isSelected = _selectedFilter == entry.key;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFilter = entry.key;
                          _isFilterOpen = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF374151),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Color(0xFF4F46E5),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderBackground(dynamic coupon) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF59E0B),
            Color(0xFFD97706),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.confirmation_number_rounded,
          size: 38,
          color: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }
}
