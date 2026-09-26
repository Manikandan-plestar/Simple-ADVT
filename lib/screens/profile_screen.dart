import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../widgets/common/notification_bell_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final authService = Provider.of<AuthService>(context, listen: false);
              authService.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final bizService = Provider.of<BusinessService>(context);

    final userBusinesses = bizService.getUserBusinesses(authService.currentUser.userId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Standard Top Header: Title + Notification Bell (Exact same position and metrics)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            child: SizedBox(
              height: 42,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                      letterSpacing: -0.3,
                    ),
                  ),
                  NotificationBellButton(),
                ],
              ),
            ),
          ),

          // Options Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Option 1: My Profile
            _buildProfileOption(
              context,
              title: 'My Profile',
              subtitle: 'View & edit registered personal details',
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
              onTap: () => Navigator.pushNamed(context, '/my-profile'),
            ),
            const SizedBox(height: 12),

            // Option 2: Business Profile Hub
            _buildProfileOption(
              context,
              title: 'Business Profile',
              subtitle: 'Manage stores, jobs & special offers',
              icon: Icons.storefront_rounded,
              iconColor: const Color(0xFF4F46E5),
              bgColor: const Color(0xFFEEF2FF),
              onTap: () => Navigator.pushNamed(context, '/business-profiles-list'),
            ),
            const SizedBox(height: 12),

            // Option 3: Followed Businesses
            _buildProfileOption(
              context,
              title: 'Followed',
              subtitle: 'Stores and businesses you actively track',
              icon: Icons.how_to_reg_rounded,
              iconColor: const Color(0xFF059669),
              bgColor: const Color(0xFFECFDF5),
              onTap: () => Navigator.pushNamed(context, '/followed'),
            ),
            const SizedBox(height: 12),

            // Option 4: Saved Posts
            _buildProfileOption(
              context,
              title: 'Saved Posts',
              subtitle: 'View bookmarked jobs & discount deals',
              icon: Icons.bookmark_outline_rounded,
              iconColor: const Color(0xFFD97706),
              bgColor: const Color(0xFFFFFBEB),
              onTap: () => Navigator.pushNamed(context, '/saved-items'),
            ),
            const SizedBox(height: 20),
            
            // Option 4: Logout Button below Saved Posts with Confirmation Dialog
            _buildProfileOption(
              context,
              title: 'Logout Account',
              subtitle: 'Sign out of current user session',
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFFEF4444),
              bgColor: const Color(0xFFFEF2F2),
              onTap: () => _showLogoutConfirmationDialog(context),
            ),
          ],
        ),
      ),
    ),
  ],
),
);
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: title == 'Logout Account' ? const Color(0xFFEF4444) : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: title == 'Logout Account' ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
