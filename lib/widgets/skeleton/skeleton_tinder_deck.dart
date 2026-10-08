import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

/// Shimmering Skeleton Loader for the Tinder-style Explore Card Deck
/// Used during initial load / after verification to avoid showing "no posts" text before data arrives.
class SkeletonTinderDeck extends StatelessWidget {
  const SkeletonTinderDeck({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main Stacked Card Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final availableHeight = constraints.maxHeight;

                final cardWidth = availableWidth - 20.0;
                final cardHeight = availableHeight - 12.0;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Peeking 2nd Card in Background (Fanned right)
                    Positioned(
                      left: 16.0,
                      top: 8.0,
                      width: cardWidth,
                      height: cardHeight,
                      child: Transform.rotate(
                        angle: 0.056,
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D000000),
                                blurRadius: 10,
                                offset: Offset(2, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Active Top Card Skeleton
                    Positioned(
                      left: 0,
                      top: 0,
                      width: cardWidth,
                      height: cardHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Full-Height Card Body Shimmer
                            const SkeletonLoader(
                              width: double.infinity,
                              height: double.infinity,
                              borderRadius: BorderRadius.zero,
                            ),

                            // 2. Top Header: Profile Pill Skeleton & Location Tag
                            Positioned(
                              top: 14,
                              left: 14,
                              right: 14,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SkeletonLoader.circular(size: 22),
                                        const SizedBox(width: 8),
                                        SkeletonLoader(
                                          width: 90,
                                          height: 12,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: SkeletonLoader(
                                      width: 60,
                                      height: 12,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 3. Bottom Right: Card Count Badge Skeleton
                            Positioned(
                              right: 14,
                              bottom: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SkeletonLoader(
                                  width: 32,
                                  height: 12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // Bottom Deck Action Buttons Skeleton Row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SkeletonLoader.circular(size: 50),
              SizedBox(width: 16),
              SkeletonLoader.circular(size: 50),
              SizedBox(width: 16),
              SkeletonLoader.circular(size: 56),
              SizedBox(width: 16),
              SkeletonLoader.circular(size: 50),
            ],
          ),
        ),
      ],
    );
  }
}
