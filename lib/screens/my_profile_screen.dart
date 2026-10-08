import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../utils/text_utils.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isEditing = false;
  bool _isFetchingAddress = false;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  LocationDetails? _locationDetails;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    _nameController = TextEditingController(text: user.name);
    _addressController = TextEditingController(text: user.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchAddress() async {
    if (_isFetchingAddress) return;

    setState(() {
      _isFetchingAddress = true;
    });

    try {
      final locService = Provider.of<LocationService>(context, listen: false);
      final hasPermission = await locService.requestPermission();
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _isFetchingAddress = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to fetch your address.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
        return;
      }

      final loc = await locService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _locationDetails = loc;
          _addressController.text = loc.formattedAddress;
          _isFetchingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingAddress = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to retrieve address. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _clearAddress() {
    if (_isFetchingAddress) return;
    setState(() {
      _addressController.clear();
      _locationDetails = null;
    });
  }

  void _saveChanges() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final formattedName = TextUtils.capitalizeWords(_nameController.text.trim());
    final newAddress = _addressController.text.trim();

    String locality = _locationDetails?.area ?? authService.currentUser.locality;
    String city = _locationDetails?.city ?? authService.currentUser.city;
    String state = _locationDetails?.state ?? authService.currentUser.state;
    String country = _locationDetails?.country ?? authService.currentUser.country;
    double lat = _locationDetails?.latitude ?? authService.currentUser.latitude;
    double lng = _locationDetails?.longitude ?? authService.currentUser.longitude;

    final success = await authService.updateProfile(
      name: formattedName,
      address: newAddress,
      locality: locality,
      city: city,
      state: state,
      country: country,
      latitude: lat,
      longitude: lng,
    );

    if (mounted) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Profile updated successfully!' : 'Failed to update profile.'),
          backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final confirmationController = TextEditingController();
    bool isMatch = false;
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: !isDeleting,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Delete Account',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This action is permanent and cannot be undone.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Deleting your account will permanently remove:',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                        ),
                        SizedBox(height: 6),
                        Text('• All your registered Business Profiles', style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D))),
                        Text('• All published & pending Posts', style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D))),
                        Text('• All Saved Bookmarks & Follows', style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D))),
                        Text('• All Notifications & Personal Data', style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'To confirm, type "delete my account" below:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmationController,
                    enabled: !isDeleting,
                    autofocus: false,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                    decoration: InputDecoration(
                      hintText: 'delete my account',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        isMatch = val.trim().toLowerCase() == 'delete my account';
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              ),
              ElevatedButton(
                onPressed: (!isMatch || isDeleting)
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        final authService = Provider.of<AuthService>(context, listen: false);
                        await authService.deleteAccount();

                        if (mounted) {
                          Navigator.pop(ctx);
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Your account and all data have been deleted.'),
                                ],
                              ),
                              backgroundColor: Color(0xFFEF4444),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  disabledBackgroundColor: const Color(0xFFFCA5A5),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isDeleting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Delete Permanently', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!_isEditing) ...[
              // View Mode Card (Displaying Name, Email, Address, Locality, City, State, Country)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x04000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildDetailField('FULL NAME', TextUtils.capitalizeWords(user.name)),
                    const SizedBox(height: 14),
                    _buildDetailField('EMAIL ADDRESS', user.email),
                    const SizedBox(height: 14),
                    _buildDetailField('FULL ADDRESS', user.address),
                    const SizedBox(height: 14),
                    _buildDetailField('LOCALITY', user.locality.isNotEmpty ? user.locality : 'Palayamkottai'),
                    const SizedBox(height: 14),
                    _buildDetailField('CITY', user.city.isNotEmpty ? user.city : 'Tirunelveli'),
                    const SizedBox(height: 14),
                    _buildDetailField('STATE', user.state.isNotEmpty ? user.state : 'Tamil Nadu'),
                    const SizedBox(height: 14),
                    _buildDetailField('COUNTRY', user.country.isNotEmpty ? user.country : 'India', isLast: true),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _isEditing = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeleteAccountDialog(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFECACA), width: 1.2),
                          backgroundColor: const Color(0xFFFEF2F2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Color(0xFFDC2626)),
                        label: const Text(
                          'Delete Account',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Edit Mode Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EDIT PROFILE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 16),

                    // 1. Email (Read-Only)
                    const Text('Email Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: user.email),
                      readOnly: true,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF9CA3AF)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Name (Editable)
                    const Text('Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(),
                    ),
                    const SizedBox(height: 16),

                    // 3. Address (GPS geocoding only)
                    const Text('Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _addressController,
                      readOnly: true,
                      onTap: _isFetchingAddress ? null : _fetchAddress,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tap here or "Get Address" to fetch location...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF4F46E5)),
                        suffixIcon: _isFetchingAddress
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5))),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: _isFetchingAddress ? null : _fetchAddress,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.my_location_rounded, size: 15, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 5),
                                Text(
                                  _isFetchingAddress ? 'Fetching Address...' : 'Get Address',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _isFetchingAddress ? null : _clearAddress,
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: Text(
                              'Clear',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _isEditing = false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Save Changes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailField(String label, String value, {bool isLast = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : 'Not provided',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
    );
  }
}
