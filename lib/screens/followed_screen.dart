import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/home/business_card.dart';
import '../widgets/skeleton/skeleton_business_card.dart';

class FollowedScreen extends StatefulWidget {
  const FollowedScreen({super.key});

  @override
  State<FollowedScreen> createState() => _FollowedScreenState();
}

class _FollowedScreenState extends State<FollowedScreen> {
  final Set<String> _togglingIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFollowed();
    });
  }

  Future<void> _loadFollowed() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final bizService = Provider.of<BusinessService>(context, listen: false);
    final user = authService.currentUser;

    await bizService.fetchFollowedBusinesses(
      authToken: user.authToken,
      userId: user.userId.isNotEmpty ? user.userId : null,
      userEmail: user.email.isNotEmpty ? user.email : null,
    );
  }

  Future<void> _handleUnfollow(String businessProfileId) async {
    setState(() => _togglingIds.add(businessProfileId));
    final authService = Provider.of<AuthService>(context, listen: false);
    final bizService = Provider.of<BusinessService>(context, listen: false);
    final user = authService.currentUser;

    final success = await bizService.toggleFollow(
      businessProfileId,
      authToken: user.authToken,
      userId: user.userId,
      userEmail: user.email,
    );

    if (mounted) {
      setState(() => _togglingIds.remove(businessProfileId));
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update follow status. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bizService = Provider.of<BusinessService>(context);
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final followedList = bizService.followedBusinesses;
    final isLoading = bizService.isLoading;

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
      body: RefreshIndicator(
        onRefresh: () => bizService.fetchFollowedBusinesses(
          authToken: user.authToken,
          userId: user.userId,
          userEmail: user.email,
        ),
        color: const Color(0xFF4F46E5),
        child: isLoading && followedList.isEmpty
            ? ListView.separated(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 96),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const SkeletonBusinessCard(),
              )
            : followedList.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      EmptyStateWidget(
                        icon: Icons.how_to_reg_rounded,
                        title: 'Not following any business yet',
                        subtitle: 'Search stores and follow to see exclusive updates and get real-time notifications.',
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 96),
                    itemCount: followedList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final biz = followedList[index];
                      final isToggling = _togglingIds.contains(biz.businessProfileId);

                      return BusinessCard(
                        business: biz,
                        onTap: () {
                          Navigator.pushNamed(context, '/business-details', arguments: biz.businessProfileId);
                        },
                        trailing: OutlinedButton(
                          onPressed: isToggling ? null : () => _handleUnfollow(biz.businessProfileId),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFF3F4F6),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isToggling
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4F46E5)),
                                )
                              : const Text(
                                  'Following',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                                ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
