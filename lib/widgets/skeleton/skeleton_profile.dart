import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

class SkeletonProfile extends StatelessWidget {
  const SkeletonProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Center(child: SkeletonLoader.circular(size: 72)),
          const SizedBox(height: 20),
          ...List.generate(4, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: 80,
                  height: 10,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 6),
                SkeletonLoader(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          )),
          const SizedBox(height: 10),
          const SkeletonLoader(
            width: double.infinity,
            height: 46,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ],
      ),
    );
  }
}
