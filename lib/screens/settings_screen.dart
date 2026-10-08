import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../utils/text_utils.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        content: const Text(
          'Are you sure you want to logout from ADVT App? You will need to verify your email again to log in.',
          style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3F4F6)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4F46E5),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TextUtils.capitalizeWords(user.name.isNotEmpty ? user.name : 'Registered User'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                        if (user.city.isNotEmpty || user.locality.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 3),
                              Text(
                                user.city.isNotEmpty ? user.city : user.locality,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF4F46E5)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Settings Menu Items: My Profile, Business Profile, Followed, Logout
            const Text(
              'ACCOUNT & BUSINESS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Column(
                children: [
                  // 1. My Profile
                  _buildMenuItem(
                    icon: Icons.person_outline_rounded,
                    title: 'My Profile',
                    subtitle: 'View and manage your personal registration data',
                    iconColor: const Color(0xFF4F46E5),
                    iconBg: const Color(0xFFEEF2FF),
                    onTap: () => Navigator.pushNamed(context, '/my-profile'),
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 16, color: Color(0xFFF3F4F6)),

                  // 2. Business Profile
                  _buildMenuItem(
                    icon: Icons.storefront_outlined,
                    title: 'Business Profile',
                    subtitle: 'Manage your businesses and create new business profiles',
                    iconColor: const Color(0xFF059669),
                    iconBg: const Color(0xFFECFDF5),
                    onTap: () => Navigator.pushNamed(context, '/business-profiles-list'),
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 16, color: Color(0xFFF3F4F6)),

                  // 3. Followed
                  _buildMenuItem(
                    icon: Icons.favorite_border_rounded,
                    title: 'Followed',
                    subtitle: 'View businesses you are actively following',
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFFFFFBEB),
                    onTap: () {
                      final auth = Provider.of<AuthService>(context, listen: false);
                      final biz = Provider.of<BusinessService>(context, listen: false);
                      biz.fetchFollowedBusinesses(
                        authToken: auth.currentUser.authToken,
                        userId: auth.currentUser.userId.isNotEmpty ? auth.currentUser.userId : null,
                        userEmail: auth.currentUser.email.isNotEmpty ? auth.currentUser.email : null,
                      );
                      Navigator.pushNamed(context, '/followed');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Logout Option
            const Text(
              'SESSION',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: _buildMenuItem(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Sign out from ADVT App on this device',
                iconColor: const Color(0xFFEF4444),
                iconBg: const Color(0xFFFEF2F2),
                titleColor: const Color(0xFFEF4444),
                onTap: () => _confirmLogout(context),
              ),
            ),

            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ADVT v1.0.0',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Signed in as ${user.email}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBg,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: titleColor ?? const Color(0xFF111827),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 20),
      onTap: onTap,
    );
  }
}
