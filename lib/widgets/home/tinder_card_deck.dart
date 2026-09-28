import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/post_service.dart';
import '../business/cycling_post_image.dart';

/// Tinder-style horizontal swipe card deck for Simple ADVT Explore feed.
/// Features:
/// - Smooth rotation and translation on horizontal drag.
/// - Next 1-2 cards visible underneath in stack with subtle scaling and offset.
/// - "More Info" and "Save" buttons on each card.
/// - Full post image presentation with rounded corners and shadows.
class TinderCardDeck extends StatefulWidget {
  final List<PostItem> posts;
  final Function(PostItem post) onToggleSave;
  final Function(PostItem post)? onBusinessTap;
  final VoidCallback? onReload;

  const TinderCardDeck({
    super.key,
    required this.posts,
    required this.onToggleSave,
    this.onBusinessTap,
    this.onReload,
  });

  @override
  State<TinderCardDeck> createState() => _TinderCardDeckState();
}

class _TinderCardDeckState extends State<TinderCardDeck> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0.0;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;
  bool _isAnimatingOffscreen = false;
  bool _swipingNext = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _animController.addListener(() {
      setState(() {
        _dragOffset = _slideAnimation.value;
        _dragAngle = _rotateAnimation.value;
      });
    });
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_isAnimatingOffscreen) {
          setState(() {
            if (_swipingNext) {
              _currentIndex = (_currentIndex + 1) % widget.posts.length;
            } else {
              _currentIndex = (_currentIndex - 1 + widget.posts.length) % widget.posts.length;
            }
            _dragOffset = Offset.zero;
            _dragAngle = 0.0;
            _isAnimatingOffscreen = false;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant TinderCardDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.posts.length != oldWidget.posts.length) {
      if (_currentIndex >= widget.posts.length && widget.posts.isNotEmpty) {
        _currentIndex = 0;
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (_animController.isAnimating) return;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_animController.isAnimating) return;
    setState(() {
      _dragOffset += details.delta;
      // Rotation angle proportional to horizontal drag
      final screenWidth = MediaQuery.of(context).size.width;
      _dragAngle = (_dragOffset.dx / screenWidth) * 0.25;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_animController.isAnimating) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.28;
    final vx = details.velocity.pixelsPerSecond.dx;

    if (_dragOffset.dx > threshold || vx > 500) {
      // Swiped Right -> Next Post
      _animateSwipe(const Offset(650, 0), 0.35, isNext: true);
    } else if (_dragOffset.dx < -threshold || vx < -500) {
      // Swiped Left -> Previous Post
      _animateSwipe(const Offset(-650, 0), -0.35, isNext: false);
    } else {
      _animateBackToCenter();
    }
  }

  void _animateSwipe(Offset targetOffset, double targetAngle, {required bool isNext}) {
    _swipingNext = isNext;
    _isAnimatingOffscreen = true;
    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutQuad));

    _rotateAnimation = Tween<double>(
      begin: _dragAngle,
      end: targetAngle,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutQuad));

    _animController.forward(from: 0.0);
  }

  void _animateBackToCenter() {
    _isAnimatingOffscreen = false;
    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));

    _rotateAnimation = Tween<double>(
      begin: _dragAngle,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));

    _animController.forward(from: 0.0);
  }

  void _swipeManual(bool isRight) {
    if (_animController.isAnimating || widget.posts.isEmpty) return;
    final targetX = isRight ? 650.0 : -650.0;
    _animateSwipe(Offset(targetX, 0), isRight ? 0.3 : -0.3, isNext: isRight);
  }

  void _showMoreInfoModal(BuildContext context, PostItem post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TinderPostMoreInfoSheet(
        post: post,
        onToggleSave: () {
          widget.onToggleSave(post);
        },
        onBusinessTap: () {
          Navigator.pop(ctx);
          if (widget.onBusinessTap != null) {
            widget.onBusinessTap!(post);
          } else if (post.businessProfileId.isNotEmpty) {
            Navigator.pushNamed(context, '/business-details', arguments: post.businessProfileId);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.style_outlined, size: 48, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No More Posts in Deck',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have reviewed all current advertisements.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            if (widget.onReload != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: widget.onReload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Start Over'),
              ),
            ],
          ],
        ),
      );
    }

    final postCount = widget.posts.length;
    final topPost = widget.posts[_currentIndex % postCount];
    final secondPost = postCount > 1 ? widget.posts[(_currentIndex + 1) % postCount] : null;
    final thirdPost = postCount > 2 ? widget.posts[(_currentIndex + 2) % postCount] : null;

    return Column(
      children: [
        // Main Swipeable Card Deck Stack
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 3rd Card in Stack (Bottom-most)
                if (thirdPost != null)
                  Transform.translate(
                    offset: const Offset(0, 18),
                    child: Transform.scale(
                      scale: 0.90,
                      child: _buildCard(thirdPost, isInteractive: false, elevation: 1),
                    ),
                  ),

                // 2nd Card in Stack (Middle)
                if (secondPost != null)
                  Transform.translate(
                    offset: const Offset(0, 9),
                    child: Transform.scale(
                      scale: 0.95,
                      child: _buildCard(secondPost, isInteractive: false, elevation: 3),
                    ),
                  ),

                // 1st Card in Stack (Active Top Card - Gesture Enabled)
                GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Transform.translate(
                    offset: _dragOffset,
                    child: Transform.rotate(
                      angle: _dragAngle,
                      child: _buildCard(
                        topPost,
                        isInteractive: true,
                        elevation: 6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Deck Controls: Previous Post, Save Post, Next Post
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous Post (Swipe Left / Back)
              _buildActionButton(
                icon: Icons.arrow_back_rounded,
                color: const Color(0xFF4B5563),
                backgroundColor: const Color(0xFFF3F4F6),
                size: 50,
                iconSize: 24,
                tooltip: 'Previous Post',
                onTap: () => _swipeManual(false),
              ),

              const SizedBox(width: 28),

              // Bookmark / Save Active Card Button
              _buildActionButton(
                icon: topPost.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: topPost.isSaved ? Colors.white : const Color(0xFF10B981),
                backgroundColor: topPost.isSaved ? const Color(0xFF10B981) : const Color(0xFFD1FAE5),
                size: 56,
                iconSize: 28,
                tooltip: topPost.isSaved ? 'Saved' : 'Save Post',
                onTap: () => widget.onToggleSave(topPost),
              ),

              const SizedBox(width: 28),

              // Next Post (Swipe Right / Forward)
              _buildActionButton(
                icon: Icons.arrow_forward_rounded,
                color: const Color(0xFF4F46E5),
                backgroundColor: const Color(0xFFEEF2FF),
                size: 50,
                iconSize: 24,
                tooltip: 'Next Post',
                onTap: () => _swipeManual(true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required double size,
    required double iconSize,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, color: color, size: iconSize),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    PostItem post, {
    required bool isInteractive,
    required double elevation,
  }) {
    final imagePath = post.images.isNotEmpty ? post.images.first : (post.brandLogo ?? '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: elevation * 3,
            offset: Offset(0, elevation),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Card Background & Media
          _buildCardMedia(post, imagePath),

          // 2. Top & Bottom Gradient Scrims
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.22, 0.60, 1.0],
                  colors: [
                    Color(0x99000000),
                    Colors.transparent,
                    Color(0x22000000),
                    Color(0xD9000000),
                  ],
                ),
              ),
            ),
          ),

          // 3. Top Header: Publisher Avatar, Name, and Location Badge
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Row(
              children: [
                // Publisher Info Pill
                GestureDetector(
                  onTap: () {
                    if (widget.onBusinessTap != null) {
                      widget.onBusinessTap!(post);
                    } else if (post.businessProfileId.isNotEmpty) {
                      Navigator.pushNamed(context, '/business-details', arguments: post.businessProfileId);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAvatar(post.brandLogo, 22),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            post.displayBizName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // Location Tag
                if (post.displayLocation.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            post.displayLocation,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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

          // 4. Bottom Section: Post Title & Action Buttons ([More Info] & [Save])
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Post Title
                Text(
                  post.displayTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.2,
                    shadows: [
                      Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Primary Dual Action Buttons: [More Info] & [Save]
                Row(
                  children: [
                    // 1. "More Info" Trigger Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showMoreInfoModal(context, post),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.info_outline_rounded, size: 18),
                        label: const Text(
                          'More Info',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 2. "Save" Bookmark Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => widget.onToggleSave(post),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                              decoration: BoxDecoration(
                                color: post.isSaved
                                    ? const Color(0xFF10B981)
                                    : Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: post.isSaved
                                      ? const Color(0xFF059669)
                                      : Colors.white.withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    post.isSaved ? 'Saved' : 'Save',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
    );
  }

  Widget _buildCardMedia(PostItem post, String imagePath) {
    if (imagePath.isEmpty) {
      return Container(
        color: const Color(0xFF1E1B4B),
        child: const Center(
          child: Icon(Icons.campaign_rounded, size: 64, color: Color(0xFF818CF8)),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Ambient Blurred Backdrop for edge-to-edge aesthetic fit
        _buildImageWidget(imagePath, fit: BoxFit.cover),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.black.withValues(alpha: 0.4)),
        ),

        // Sharp Centered Image / Cycling Post Media
        if (post.images.length > 1)
          CyclingPostImage(
            images: post.images,
            height: double.infinity,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.zero,
            showIndicators: true,
          )
        else
          Center(
            child: _buildImageWidget(imagePath, fit: BoxFit.contain),
          ),
      ],
    );
  }

  Widget _buildImageWidget(String pathOrUrl, {required BoxFit fit}) {
    if (pathOrUrl.startsWith('assets/')) {
      return Image.asset(
        pathOrUrl,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1B4B)),
      );
    }
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(
        pathOrUrl,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1B4B)),
      );
    }
    final f = File(pathOrUrl);
    if (f.existsSync()) {
      return Image.file(
        f,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1B4B)),
      );
    }
    return Container(color: const Color(0xFF1E1B4B));
  }

  Widget _buildAvatar(String? logo, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: (logo != null && logo.isNotEmpty)
          ? _buildImageWidget(logo, fit: BoxFit.cover)
          : const Icon(Icons.storefront_rounded, size: 12, color: Color(0xFF4F46E5)),
    );
  }
}

/// Expandable Bottom Sheet / Drawer revealed on tapping "More Info" in Tinder Deck
class _TinderPostMoreInfoSheet extends StatelessWidget {
  final PostItem post;
  final VoidCallback onToggleSave;
  final VoidCallback onBusinessTap;

  const _TinderPostMoreInfoSheet({
    required this.post,
    required this.onToggleSave,
    required this.onBusinessTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag / Collapse Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // TOP SECTION: Poster Info & Profile Badge
                    // ==========================================
                    Row(
                      children: [
                        // Profile Avatar
                        GestureDetector(
                          onTap: onBusinessTap,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF4F46E5), width: 1.5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: (post.brandLogo != null && post.brandLogo!.isNotEmpty)
                                ? _buildAvatarImage(post.brandLogo!)
                                : const Icon(Icons.storefront_rounded, color: Color(0xFF4F46E5), size: 26),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Name & Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      post.displayBizName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF4F46E5)),
                                ],
                              ),
                              if (post.displaySubtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  post.displaySubtitle,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF9CA3AF)),
                                  const SizedBox(width: 4),
                                  Text(
                                    post.timeAgo,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      post.postId,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // View Profile Button
                        OutlinedButton(
                          onPressed: onBusinessTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFF4F46E5), width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    const Divider(height: 28, color: Color(0xFFF3F4F6)),

                    // ==========================================
                    // BOTTOM SECTION: Post Description & Details
                    // ==========================================
                    Text(
                      post.displayTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (post.description.isNotEmpty) ...[
                      Text(
                        post.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Target Locations Pill List
                    if (post.displayLocation.isNotEmpty) ...[
                      const Text(
                        'Target Location',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 4),
                                Text(
                                  post.displayLocation,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3730A3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (post.targetLocationItems != null)
                            for (final item in post.targetLocationItems!)
                              if (item.name.toLowerCase() != (post.targetLocation ?? '').toLowerCase())
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
                                  ),
                                ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Action buttons in drawer
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onToggleSave,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: post.isSaved ? const Color(0xFF10B981) : const Color(0xFF4B5563),
                              side: BorderSide(
                                color: post.isSaved ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: Icon(
                              post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              size: 18,
                            ),
                            label: Text(
                              post.isSaved ? 'Saved to Bookmarks' : 'Save Post',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Back to Post', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarImage(String pathOrUrl) {
    if (pathOrUrl.startsWith('assets/')) {
      return Image.asset(pathOrUrl, fit: BoxFit.cover);
    }
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(pathOrUrl, fit: BoxFit.cover);
    }
    final f = File(pathOrUrl);
    if (f.existsSync()) {
      return Image.file(f, fit: BoxFit.cover);
    }
    return const Icon(Icons.storefront_rounded, color: Color(0xFF4F46E5), size: 26);
  }
}
