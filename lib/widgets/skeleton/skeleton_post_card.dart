import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

class SkeletonPostCard extends StatelessWidget {
  const SkeletonPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image Skeleton (Matches 200px fixed container)
          const SkeletonLoader(
            width: double.infinity,
            height: 200,
            borderRadius: BorderRadius.zero,
          ),

          // Content Skeleton
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SkeletonLoader.circular(size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLoader(
                            width: MediaQuery.of(context).size.width * 0.45,
                            height: 14,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 6),
                          SkeletonLoader(
                            width: MediaQuery.of(context).size.width * 0.3,
                            height: 10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SkeletonLoader(
                  width: double.infinity,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonLoader(
                      width: 60,
                      height: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    SkeletonLoader(
                      width: 80,
                      height: 28,
                      borderRadius: BorderRadius.circular(8),
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
}
