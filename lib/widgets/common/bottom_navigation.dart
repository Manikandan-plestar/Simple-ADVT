import 'dart:async';
import 'package:flutter/material.dart';

class CustomBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<CustomBottomNavigation> createState() => _CustomBottomNavigationState();
}

class _CustomBottomNavigationState extends State<CustomBottomNavigation> {
  Timer? _sequenceTimer1;
  Timer? _sequenceTimer2;
  bool _showingPlus = false;

  final List<_NavItemData> _items = const [
    _NavItemData(
      label: 'Saved',
      activeIcon: Icons.bookmark_rounded,
      inactiveIcon: Icons.bookmark_border_rounded,
    ),
    _NavItemData(
      label: 'Explore',
      activeIcon: Icons.explore_rounded,
      inactiveIcon: Icons.explore_outlined,
    ),
    _NavItemData(
      label: 'Settings',
      activeIcon: Icons.settings_rounded,
      inactiveIcon: Icons.settings_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.currentIndex == 1) {
      _startExploreAnimationSequence();
    }
  }

  @override
  void didUpdateWidget(covariant CustomBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      if (widget.currentIndex == 1) {
        // Tab changed to Explore -> Start icon animation sequence
        _startExploreAnimationSequence();
      } else {
        // Tab changed away from Explore -> Cancel timers & reset
        _cancelExploreAnimationSequence();
      }
    }
  }

  void _cancelExploreAnimationSequence() {
    _sequenceTimer1?.cancel();
    _sequenceTimer1 = null;
    _sequenceTimer2?.cancel();
    _sequenceTimer2 = null;
    if (_showingPlus) {
      if (mounted) {
        setState(() {
          _showingPlus = false;
        });
      } else {
        _showingPlus = false;
      }
    }
  }

  void _startExploreAnimationSequence() {
    _cancelExploreAnimationSequence();

    // 1. Explore icon is displayed (_showingPlus is false)
    // 2. Wait 3 seconds
    _sequenceTimer1 = Timer(const Duration(seconds: 3), () {
      if (!mounted || widget.currentIndex != 1) return;

      // 3. Animate/rotate icon -> + icon
      setState(() {
        _showingPlus = true;
      });

      // 4. Keep + icon visible for 2 seconds
      _sequenceTimer2 = Timer(const Duration(seconds: 2), () {
        if (!mounted || widget.currentIndex != 1) return;

        // 5. Animate/rotate icon -> Explore icon
        setState(() {
          _showingPlus = false;
        });

        // 6. Recursively loop the animation cycle while Explore tab is active
        _startExploreAnimationSequence();
      });
    });
  }

  @override
  void dispose() {
    _cancelExploreAnimationSequence();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6366F1); // Indigo / Purple
    const inactiveColor = Color(0xFF9CA3AF); // Slate Gray
    final items = _items;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final tabWidth = totalWidth / items.length;

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: widget.currentIndex.toDouble(), end: widget.currentIndex.toDouble()),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          builder: (context, animIndex, child) {
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // 1. Curved Scooped Background Bar
                CustomPaint(
                  size: Size(totalWidth, 68),
                  painter: _CurvedNotchPainter(
                    activeIndex: animIndex,
                    itemCount: items.length,
                    barColor: Colors.white,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                  ),
                ),

                // 2. Tab Items Row (Inactive items with icons and labels)
                SizedBox(
                  height: 68,
                  child: Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final isCurrent = index == widget.currentIndex;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onTap(index),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 8),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isCurrent ? 0.0 : 1.0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.inactiveIcon,
                                    size: 22,
                                    color: inactiveColor,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: inactiveColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // 3. Floating Raised Circular Active Button
                Positioned(
                  left: (animIndex + 0.5) * tabWidth - 26,
                  bottom: 24,
                  child: GestureDetector(
                    onTap: () => widget.onTap(widget.currentIndex),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.38),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: widget.currentIndex == 1
                          ? AnimatedSwitcher(
                              duration: const Duration(milliseconds: 380),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                final rotateAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
                                  CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
                                );
                                return RotationTransition(
                                  turns: rotateAnimation,
                                  child: ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                                );
                              },
                              child: Icon(
                                _showingPlus ? Icons.add_rounded : Icons.explore_rounded,
                                key: ValueKey<bool>(_showingPlus),
                                size: 26,
                                color: Colors.white,
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, animation) => ScaleTransition(
                                scale: animation,
                                child: child,
                              ),
                              child: Icon(
                                items[widget.currentIndex].activeIcon,
                                key: ValueKey<int>(widget.currentIndex),
                                size: 26,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NavItemData {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _NavItemData({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
  });
}

class _CurvedNotchPainter extends CustomPainter {
  final double activeIndex;
  final int itemCount;
  final Color barColor;
  final Color shadowColor;

  _CurvedNotchPainter({
    required this.activeIndex,
    required this.itemCount,
    required this.barColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final tabWidth = w / itemCount;
    final centerX = (activeIndex + 0.5) * tabWidth;

    const cornerRadius = 22.0;
    const notchRadius = 34.0;
    const notchDepth = 28.0;

    final path = Path();
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // Line to left side of notch
    final notchLeft = (centerX - notchRadius - 14).clamp(cornerRadius, w - cornerRadius);
    path.lineTo(notchLeft, 0);

    // Smooth organic scoop curve
    path.cubicTo(
      centerX - notchRadius,
      0,
      centerX - notchRadius * 0.55,
      notchDepth,
      centerX,
      notchDepth,
    );
    path.cubicTo(
      centerX + notchRadius * 0.55,
      notchDepth,
      centerX + notchRadius,
      0,
      (centerX + notchRadius + 14).clamp(cornerRadius, w - cornerRadius),
      0,
    );

    // Line to right corner
    path.lineTo(w - cornerRadius, 0);
    path.quadraticBezierTo(w, 0, w, cornerRadius);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // Draw elevation shadow
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(path.shift(const Offset(0, -2)), shadowPaint);

    // Draw white bar background
    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CurvedNotchPainter oldDelegate) {
    return oldDelegate.activeIndex != activeIndex ||
        oldDelegate.itemCount != itemCount ||
        oldDelegate.barColor != barColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}
