import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

class SkeletonBusinessCard extends StatelessWidget {
  const SkeletonBusinessCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const SkeletonLoader.circular(size: 48),
          const SizedBox(width: 14),
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
                  height: 11,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SkeletonLoader(
            width: 54,
            height: 28,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}
