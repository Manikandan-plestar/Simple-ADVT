import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/business_service.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/home/business_card.dart';

class FollowedScreen extends StatelessWidget {
  const FollowedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bizService = Provider.of<BusinessService>(context);
    final followedList = bizService.followedBusinesses;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Followed Businesses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            SizedBox(height: 2),
            Text(
              'Stores and organizations you actively track',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 96),
        child: Column(
          children: [
            if (followedList.isEmpty)
              const EmptyStateWidget(
                icon: Icons.how_to_reg_rounded,
                title: 'Not following any business yet',
                subtitle: 'Search stores and follow to see exclusive updates.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: followedList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final biz = followedList[index];
                  return BusinessCard(
                    business: biz,
                    onTap: () {
                      Navigator.pushNamed(context, '/business-details', arguments: biz.businessProfileId);
                    },
                    trailing: OutlinedButton(
                      onPressed: () {
                        bizService.toggleFollow(biz.businessProfileId);
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Following',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
