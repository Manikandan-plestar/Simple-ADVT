import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../widgets/home/business_card.dart';

class BusinessProfilesListScreen extends StatefulWidget {
  const BusinessProfilesListScreen({super.key});

  @override
  State<BusinessProfilesListScreen> createState() => _BusinessProfilesListScreenState();
}

class _BusinessProfilesListScreenState extends State<BusinessProfilesListScreen> {
  bool _hasFetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasFetched) {
      _hasFetched = true;
      _loadProfiles();
    }
  }

  Future<void> _loadProfiles() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final bizService = Provider.of<BusinessService>(context, listen: false);

    if (authService.currentUser.userId.isNotEmpty || authService.currentUser.email.isNotEmpty) {
      await bizService.fetchUserBusinesses(
        userId: authService.currentUser.userId,
        authToken: authService.currentUser.authToken,
        userEmail: authService.currentUser.email,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final bizService = Provider.of<BusinessService>(context);

    // Requirement 9 & 10: Strict logged-in user isolation
    final userBusinesses = bizService.getUserBusinesses(authService.currentUser.userId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Your Business Profiles',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfiles,
        color: const Color(0xFF4F46E5),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20),
          child: Column(
            children: [
              if (bizService.isLoading && userBusinesses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2),
                  ),
                )
              else if (userBusinesses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.storefront_outlined, color: Color(0xFF4F46E5), size: 30),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No Business Profiles Found',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'You have not registered any business profile yet.\nTap below to add your first business profile.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: userBusinesses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final biz = userBusinesses[index];
                    return BusinessCard(
                      business: biz,
                      onTap: () {
                        bizService.setActiveBusiness(biz.businessProfileId);
                        Navigator.pushNamed(
                          context,
                          '/business-details',
                          arguments: biz.businessProfileId,
                        );
                      },
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'View',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      // Fixed bottom button bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/create-biz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Add New Business Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
