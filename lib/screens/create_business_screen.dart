import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../services/country_code_data.dart';
import '../services/device_image_picker_service.dart';
import '../services/location_service.dart';
import '../widgets/common/country_code_picker_widget.dart';

class CreateBusinessScreen extends StatefulWidget {
  const CreateBusinessScreen({super.key});

  @override
  State<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends State<CreateBusinessScreen> {
  final _nameController = TextEditingController();
  final _catController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _aboutController = TextEditingController();

  LocationDetails? _locationDetails;
  bool _isFetchingAddress = false;
  bool _isSubmitting = false;

  CountryCodeModel _selectedCountry = CountryCodeData.defaultCountry; // India (+91)
  List<String> _selectedImages = []; // Local device images only, empty by default!
  bool _isPickingImages = false;

  @override
  void dispose() {
    _nameController.dispose();
    _catController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _fetchAddress() async {
    if (_isFetchingAddress) return;

    setState(() {
      _isFetchingAddress = true;
    });

    try {
      final locService = Provider.of<LocationService>(context, listen: false);

      // Request location permission
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

      // Fetch location and reverse geocode
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
            content: Text('Failed to retrieve address. Please check location settings and try again.'),
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

  Future<void> _pickImagesFromDevice() async {
    setState(() => _isPickingImages = true);
    try {
      final result = await DeviceImagePickerService.pickImagesFromGallery(
        currentSelected: _selectedImages,
        maxLimit: 4,
      );

      if (mounted) {
        setState(() {
          _selectedImages = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open device gallery.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImages = false);
      }
    }
  }

  void _submitNewBusiness() async {
    if (_isSubmitting) return; // Prevent duplicate clicks

    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'\s+'), '');
    final cleanPhoneDigits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter business name'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (cleanPhoneDigits.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit business phone number'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap "Get Address" to fetch your business location'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select 1 to 4 business images from your device.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedImages.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 4 images allowed for business profile.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final fullBusinessPhone = '${_selectedCountry.dialCode} $cleanPhoneDigits';

    final authService = Provider.of<AuthService>(context, listen: false);
    final bizService = Provider.of<BusinessService>(context, listen: false);

    // Extract structured address data
    String locality = (_locationDetails?.area ?? '').trim();
    String city = (_locationDetails?.city ?? '').trim();
    String state = (_locationDetails?.state ?? '').trim();
    String country = (_locationDetails?.country ?? '').trim();

    // Parse separated address components from the full address string if any are empty
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

    if (city.isEmpty) city = 'Tirunelveli';

    final double lat = _locationDetails?.latitude ?? 8.7139;
    final double lng = _locationDetails?.longitude ?? 77.7567;

    try {
      final newBiz = await bizService.createBusinessProfile(
        ownerUserId: authService.currentUser.userId,
        name: name,
        category: _catController.text.trim().isNotEmpty ? _catController.text.trim() : 'General Store',
        phone: fullBusinessPhone,
        countryCode: _selectedCountry.dialCode,
        location: city,
        registeredAddress: address,
        locality: locality,
        city: city,
        state: state,
        country: country,
        latitude: lat,
        longitude: lng,
        images: _selectedImages,
        about: _aboutController.text.trim(),
        authToken: authService.currentUser.authToken,
        userEmail: authService.currentUser.email,
      );

      if (mounted) {
        bizService.setActiveBusiness(newBiz.businessProfileId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business Profile created & saved successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacementNamed(context, '/biz-manage');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating business profile: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Register Business',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Business Name
            const Text('Business / Store Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: _inputDecoration('e.g. Saffron Clothing & Boutique'),
            ),
            const SizedBox(height: 14),

            // 2. Business Category
            const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: _catController,
              decoration: _inputDecoration('e.g. Dress Shop, Cafe, Clinic...'),
            ),
            const SizedBox(height: 14),

            // 3. Business Phone Number with Country Code Selector
            const Text('Business Phone Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            Row(
              children: [
                CountryCodePickerWidget(
                  selectedCountry: _selectedCountry,
                  onCountryChanged: (c) {
                    setState(() {
                      _selectedCountry = c;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '9876543210',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF4F46E5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. Address Input (Read-only, GPS Geocoding only)
            const Text('Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: _addressController,
              readOnly: true,
              onTap: _isFetchingAddress ? null : _fetchAddress,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              decoration: InputDecoration(
                hintText: 'Tap here or "Get Address" to fetch location...',
                hintStyle: const TextStyle(
                  fontSize: 12,
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
                              fontSize: 12,
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
                              fontSize: 12,
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
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 12,
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Retrieving GPS coordinates & reverse geocoded address...',
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
            const SizedBox(height: 14),

            // 5. Business Images (1 to 4 Images - Local Device Only)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Business Images (1 to 4)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                InkWell(
                  onTap: _pickImagesFromDevice,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    child: Row(
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 15, color: Color(0xFF4F46E5)),
                        SizedBox(width: 4),
                        Text('Select Images', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (_selectedImages.isNotEmpty) ...[
              SizedBox(
                height: 95,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length + (_selectedImages.length < 4 ? 1 : 0),
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, idx) {
                    if (idx == _selectedImages.length) {
                      return GestureDetector(
                        onTap: _isPickingImages ? null : _pickImagesFromDevice,
                        child: Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF4F46E5), size: 22),
                              SizedBox(height: 4),
                              Text(
                                'Add More',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final imgPath = _selectedImages[idx];

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 85,
                            height: 85,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: imgPath.startsWith('http')
                                ? Image.network(imgPath, fit: BoxFit.cover)
                                : Image.file(
                                    File(imgPath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Icon(Icons.broken_image_rounded, color: Color(0xFF9CA3AF)),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImages.removeAt(idx);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_selectedImages.length}/4 image(s) selected from device.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ] else ...[
              GestureDetector(
                onTap: _pickImagesFromDevice,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 30, color: Color(0xFF4F46E5)),
                      SizedBox(height: 6),
                      Text(
                        'Tap to select 1–4 photos from your device',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      SizedBox(height: 2),
                      Text(
                        'Will be displayed full-width at top of Business Profile',
                        style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),

            // 6. About Business
            const Text('About Business', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(
              controller: _aboutController,
              maxLines: 3,
              decoration: _inputDecoration('Describe your services, offers, or store...'),
            ),
            const SizedBox(height: 24),

            // Submit Button with duplicate tap prevention and loading state
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitNewBusiness,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  disabledBackgroundColor: const Color(0xFFC7D2FE),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Create & Save Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
    );
  }
}
