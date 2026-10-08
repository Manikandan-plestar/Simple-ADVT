import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/post_service.dart';
import '../business/cycling_post_image.dart';

/// Tinder-style horizontal swipe card deck for ADVT App Explore feed.
/// Features:
/// - Smooth rotation and translation on horizontal drag.
/// - Next 1-2 cards visible underneath in stack with subtle scaling and offset.
/// - Bottom navigation & action controls: Previous, More Info, Save, and Next.
/// - Full post image presentation with rounded corners and shadows.
class TinderCardDeck extends StatefulWidget {
  final List<PostItem> posts;
  final int? totalCount;
  final Function(PostItem post) onToggleSave;
  final Function(PostItem post)? onMoreInfoClick;
  final Function(PostItem post)? onBusinessTap;
  final VoidCallback? onReload;

  const TinderCardDeck({
    super.key,
    required this.posts,
    this.totalCount,
    required this.onToggleSave,
    this.onMoreInfoClick,
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
              if (widget.posts.isNotEmpty) {
                _currentIndex = (_currentIndex + 1) % widget.posts.length;
              }
            } else {
              if (widget.posts.isNotEmpty) {
                _currentIndex = (_currentIndex - 1 + widget.posts.length) % widget.posts.length;
              }
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
        _currentIndex = widget.posts.length - 1;
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

    if (_dragOffset.dx < -threshold || vx < -500) {
      // Swiped Right -> Left (dragged left): Show NEXT Post (Loops to 1st after last)
      if (widget.posts.length > 1) {
        _animateSwipe(const Offset(-650, 0), -0.35, isNext: true);
      } else {
        _animateBackToCenter();
      }
    } else if (_dragOffset.dx > threshold || vx > 500) {
      // Swiped Left -> Right (dragged right): Show PREVIOUS Post (Loops to last if at 1st)
      if (widget.posts.length > 1) {
        _animateSwipe(const Offset(650, 0), 0.35, isNext: false);
      } else {
        _animateBackToCenter();
      }
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

  void _swipeManual(bool isNext) {
    if (_animController.isAnimating || widget.posts.length <= 1) return;
    if (isNext) {
      _animateSwipe(const Offset(-650, 0), -0.3, isNext: true);
    } else {
      _animateSwipe(const Offset(650, 0), 0.3, isNext: false);
    }
  }

  void _showMoreInfoModal(BuildContext context, PostItem post) {
    if (widget.onMoreInfoClick != null) {
      widget.onMoreInfoClick!(post);
    }
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
    final totalEligible = widget.totalCount != null && widget.totalCount! > 0
        ? widget.totalCount!
        : postCount;

    final safeIndex = _currentIndex % postCount;
    final topPost = widget.posts[safeIndex];

    final nextIndex = (safeIndex + 1) % postCount;
    final secondPost = postCount > 1 ? widget.posts[nextIndex] : null;

    final topCardIndex = safeIndex + 1;
    final secondCardIndex = nextIndex + 1;

    // Dynamic drag progress (0.0 to 1.0)
    final dragFraction = (_dragOffset.dx.abs() / 240.0).clamp(0.0, 1.0);

    return Column(
      children: [
        // Main Swipeable Card Stack (Normal Centered View)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth;
                final cardHeight = constraints.maxHeight;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Next Card in Stack (Sitting directly underneath, scaling smoothly into place)
                    if (secondPost != null)
                      Positioned(
                        left: 0,
                        top: 0,
                        width: cardWidth,
                        height: cardHeight,
                        child: Transform.scale(
                          scale: 0.96 + (0.04 * dragFraction),
                          child: _buildCard(
                            secondPost,
                            isInteractive: false,
                            elevation: 2,
                            cardIndex: secondCardIndex,
                            totalCount: totalEligible,
                            dimOpacity: (0.12 * (1.0 - dragFraction)).clamp(0.0, 1.0),
                          ),
                        ),
                      ),

                    // Active Top Card (Gesture & Swipe Enabled)
                    Positioned(
                      left: _dragOffset.dx,
                      top: _dragOffset.dy,
                      width: cardWidth,
                      height: cardHeight,
                      child: GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        onLongPress: () {
                          final img = topPost.images.isNotEmpty
                              ? topPost.images.first
                              : (topPost.brandLogo ?? '');
                          if (img.isNotEmpty) {
                            if (widget.onMoreInfoClick != null) {
                              widget.onMoreInfoClick!(topPost);
                            }
                            _openFullScreenImage(context, img);
                          }
                        },
                        child: Transform.rotate(
                          angle: _dragAngle * 0.4,
                          child: _buildCard(
                            topPost,
                            isInteractive: true,
                            elevation: 5,
                            cardIndex: topCardIndex,
                            totalCount: totalEligible,
                            dimOpacity: 0.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // Bottom Deck Controls: Previous Post, More Info, Save Post, Next Post
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous Post (Swipe Left / Back - Loops infinitely)
              _buildActionButton(
                icon: Icons.arrow_back_rounded,
                color: postCount > 1 ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
                backgroundColor: postCount > 1 ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
                size: 50,
                iconSize: 24,
                tooltip: 'Previous Post',
                onTap: postCount > 1 ? () => _swipeManual(false) : () {},
              ),

              const SizedBox(width: 16),

              // More Info Action Button (Positioned before Save)
              _buildActionButton(
                icon: Icons.info_outline_rounded,
                color: const Color(0xFF4F46E5),
                backgroundColor: const Color(0xFFEEF2FF),
                size: 50,
                iconSize: 24,
                tooltip: 'More Info',
                onTap: () => _showMoreInfoModal(context, topPost),
              ),

              const SizedBox(width: 16),

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

              const SizedBox(width: 16),

              // Next Post (Swipe Right / Forward - Loops infinitely)
              _buildActionButton(
                icon: Icons.arrow_forward_rounded,
                color: postCount > 1 ? const Color(0xFF4F46E5) : const Color(0xFF9CA3AF),
                backgroundColor: postCount > 1 ? const Color(0xFFEEF2FF) : const Color(0xFFF9FAFB),
                size: 50,
                iconSize: 24,
                tooltip: 'Next Post',
                onTap: postCount > 1 ? () => _swipeManual(true) : () {},
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
    required int cardIndex,
    required int totalCount,
    double dimOpacity = 0.0,
  }) {
    final imagePath = post.images.isNotEmpty ? post.images.first : (post.brandLogo ?? '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isInteractive
              ? Colors.white.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.4),
          width: isInteractive ? 1.0 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isInteractive ? 0.16 : 0.10),
            blurRadius: elevation * 3.5,
            offset: Offset(isInteractive ? 0 : 2, elevation),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Card Background & Media
          _buildCardMedia(post, imagePath),

          // 2. Subtle Depth Dimming Overlay for Background Cards only (inactive cards in stack)
          if (dimOpacity > 0.0)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: dimOpacity),
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

                // Location Tag (Owner Only)
                if (post.isOwner && post.displayLocation.isNotEmpty)
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

          // 4. Bottom Right: Post Count Indicator (CURRENT_POST_NUMBER / TOTAL_POST_COUNT)
          Positioned(
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 0.8,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
              child: Text(
                '$cardIndex/$totalCount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardMedia(PostItem post, String imagePath) {
    if (imagePath.isEmpty && post.images.isEmpty) {
      return _buildFallbackImage();
    }

    if (post.images.length > 1) {
      return CyclingPostImage(
        images: post.images,
        height: double.infinity,
        width: double.infinity,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.zero,
        showIndicators: true,
      );
    }

    final targetPath = post.images.isNotEmpty ? post.images.first : imagePath;
    return _buildImageWidget(targetPath, fit: BoxFit.cover);
  }

  Widget _buildImageWidget(String pathOrUrl, {required BoxFit fit}) {
    if (pathOrUrl.startsWith('assets/')) {
      return Image.asset(
        pathOrUrl,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallbackImage(),
      );
    }
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(
        pathOrUrl,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final totalBytes = loadingProgress.expectedTotalBytes;
          final loadedBytes = loadingProgress.cumulativeBytesLoaded;
          final progress = totalBytes != null && totalBytes > 0 ? loadedBytes / totalBytes : null;

          return Container(
            color: const Color(0xFF1E1B4B),
            child: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  color: const Color(0xFF818CF8),
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _buildFallbackImage(),
      );
    }
    final f = File(pathOrUrl);
    if (f.existsSync()) {
      return Image.file(
        f,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallbackImage(),
      );
    }
    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_rounded, size: 56, color: Color(0xFF818CF8)),
            SizedBox(height: 8),
            Text(
              'ADVT',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFA5B4FC),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
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
                                    post.calculatedTimeAgo,
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
                        // OutlinedButton(
                        //   onPressed: onBusinessTap,
                        //   style: OutlinedButton.styleFrom(
                        //     foregroundColor: const Color(0xFF4F46E5),
                        //     side: const BorderSide(color: Color(0xFF4F46E5), width: 1.2),
                        //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        //   ),
                        //   child: const Text('Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        // ),
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

                    // Target Locations Pill List (Owner Only)
                    if (post.isOwner && post.displayLocation.isNotEmpty) ...[
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
