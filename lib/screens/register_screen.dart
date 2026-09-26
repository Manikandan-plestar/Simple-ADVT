import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../utils/text_utils.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  LocationDetails? _locationDetails;
  bool _isFetchingAddress = false;
  bool _isSubmitting = false;

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

      // 1. Request location permission
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
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 2. Fetch current GPS location and reverse geocode
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
            content: Text('Failed to retrieve address. Please check GPS settings and try again.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
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

  void _handleRegister() async {
    final rawName = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (rawName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final formattedName = TextUtils.capitalizeWords(rawName);

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap "Get Address" to fetch your location'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final email = authService.pendingEmail ?? authService.currentUser.email;

    String locality = (_locationDetails?.area ?? '').trim();
    String city = (_locationDetails?.city ?? '').trim();
    String state = (_locationDetails?.state ?? '').trim();
    String country = (_locationDetails?.country ?? '').trim();
    double latitude = _locationDetails?.latitude ?? 0.0;
    double longitude = _locationDetails?.longitude ?? 0.0;

    // Parse structured address components if not already populated
    final parts = address.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) {
      if (country.isEmpty) {
        final lastPart = parts.last.replaceAll(RegExp(r'[0-9-]'), '').trim();
        country = lastPart.isNotEmpty ? lastPart : 'India';
      }
      if (state.isEmpty && parts.length >= 2) {
        final stateCandidate = parts[parts.length - 2].replaceAll(RegExp(r'[0-9-]'), '').trim();
        if (stateCandidate.isNotEmpty) state = stateCandidate;
      }
      if (city.isEmpty) {
        if (parts.length >= 3) {
          city = parts[parts.length - 3].replaceAll(RegExp(r'[0-9-]'), '').trim();
        } else if (parts.length == 2) {
          city = parts[0].replaceAll(RegExp(r'[0-9-]'), '').trim();
        } else {
          city = parts[0].trim();
        }
      }
      if (locality.isEmpty) {
        if (parts.length >= 4) {
          locality = parts.sublist(0, parts.length - 3).join(', ').trim();
        } else {
          locality = parts[0].trim();
        }
      }
    }

    if (country.isEmpty) country = 'India';
    if (state.isEmpty) state = 'Tamil Nadu';
    if (city.isEmpty) city = 'Tirunelveli';
    if (locality.isEmpty) locality = city;

    final response = await authService.registerUser(
      name: formattedName,
      email: email,
      address: address,
      locality: locality,
      city: city,
      state: state,
      country: country,
      latitude: latitude,
      longitude: longitude,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(response.message)),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(response.message)),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Row: Back Arrow and User Registration Title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827), size: 24),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'User Registration',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 38),
                  child: Text(
                    'Complete your registration details to discover relevant local business posts.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 2. Name Field (Only Name)
                const Text(
                  'Name',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF111827), fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Enter your name (e.g. Mani Kumar)',
                    hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Address Field (Only Address, Read-only with Get Address & Clear)
                const Text(
                  'Address',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
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
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tap here or "Get Address" to fetch location...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: Color(0xFF4F46E5),
                    ),
                    suffixIcon: _isFetchingAddress
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Text Actions below Address field: Get Address (Left) & Clear (Right)
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
                            if (_isFetchingAddress) ...[
                              const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Fetching Address...',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ] else ...[
                              const Icon(
                                Icons.my_location_rounded,
                                size: 15,
                                color: Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Get Address',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _isFetchingAddress ? null : _clearAddress,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isFetchingAddress
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_isFetchingAddress) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Retrieving current GPS location & reverse geocoding address...',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4338CA),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 36),

                // Save & Next Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || _isFetchingAddress) ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      disabledBackgroundColor: const Color(0xFFC7D2FE),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                          )
                        : const Text(
                            'Save & Next',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
