import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../services/country_code_data.dart';
import '../services/device_image_picker_service.dart';
import '../widgets/common/country_code_picker_widget.dart';

class EditBusinessScreen extends StatefulWidget {
  final String businessProfileId;

  const EditBusinessScreen({super.key, required this.businessProfileId});

  @override
  State<EditBusinessScreen> createState() => _EditBusinessScreenState();
}

class _EditBusinessScreenState extends State<EditBusinessScreen> {
  late TextEditingController _nameController;
  late TextEditingController _catController;
  late TextEditingController _phoneController;
  late TextEditingController _aboutController;

  late CountryCodeModel _selectedCountry;
  List<String> _images = [];
  bool _isPickingImages = false;

  @override
  void initState() {
    super.initState();
    final biz = Provider.of<BusinessService>(context, listen: false).getBusinessById(widget.businessProfileId);
    _nameController = TextEditingController(text: biz?.name ?? '');
    _catController = TextEditingController(text: biz?.category ?? '');
    _aboutController = TextEditingController(text: biz?.about ?? '');

    // Parse existing phone for dial code
    final rawPhone = biz?.phone ?? '+91 98402 12345';
    CountryCodeModel matchedCountry = CountryCodeData.defaultCountry;
    String numberPart = rawPhone;

    for (final c in CountryCodeData.allCountries) {
      if (rawPhone.startsWith(c.dialCode)) {
        matchedCountry = c;
        numberPart = rawPhone.substring(c.dialCode.length).trim();
        break;
      }
    }
    _selectedCountry = matchedCountry;
    _phoneController = TextEditingController(text: numberPart);

    if (biz != null && biz.images.isNotEmpty) {
      _images = List<String>.from(biz.images);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _catController.dispose();
    _phoneController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _pickImagesFromDevice() async {
    setState(() => _isPickingImages = true);
    try {
      final result = await DeviceImagePickerService.pickImagesFromGallery(
        currentSelected: _images,
        maxLimit: 4,
      );

      if (mounted) {
        setState(() {
          _images = result;
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

  void _saveChanges() async {
    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'\s+'), '');
    final cleanPhoneDigits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter business name')),
      );
      return;
    }

    if (cleanPhoneDigits.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit business phone number')),
      );
      return;
    }

    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please keep at least 1 business image (maximum 4).')),
      );
      return;
    }

    if (_images.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 4 images allowed for business profile.')),
      );
      return;
    }

    final fullBusinessPhone = '${_selectedCountry.dialCode} $cleanPhoneDigits';

    final authService = Provider.of<AuthService>(context, listen: false);
    final bizService = Provider.of<BusinessService>(context, listen: false);

    await bizService.updateBusinessProfile(
      businessProfileId: widget.businessProfileId,
      name: name,
      category: _catController.text.trim().isNotEmpty ? _catController.text.trim() : 'General Store',
      phone: fullBusinessPhone,
      countryCode: _selectedCountry.dialCode,
      images: _images,
      about: _aboutController.text.trim(),
      callerUserId: authService.currentUser.userId,
      authToken: authService.currentUser.authToken,
      userEmail: authService.currentUser.email,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business Profile updated successfully.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
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
          'Edit Business Profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Business Name
            const Text('Business Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(controller: _nameController, decoration: _inputDecoration('e.g. Saffron Clothing & Boutique')),
            const SizedBox(height: 14),

            // 2. Category
            const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(controller: _catController, decoration: _inputDecoration('e.g. Dress Shop, Cafe, Clinic...')),
            const SizedBox(height: 14),

            // 3. Business Phone Number with Country Code
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

            // 4. Business Images (1 to 4 Images)
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
                        Text('Add Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (_images.isNotEmpty) ...[
              SizedBox(
                height: 95,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length + (_images.length < 4 ? 1 : 0),
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, idx) {
                    if (idx == _images.length) {
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

                    final imgPath = _images[idx];

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
                                _images.removeAt(idx);
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
                '${_images.length}/4 image(s) saved. Displayed full-width one by one at top of Business Profile.',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280)),
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
                      Text('Tap to select 1–4 photos from your device', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      SizedBox(height: 2),
                      Text('Will be displayed full-width at top of Business Profile', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),

            // 5. About Business
            const Text('About Business', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            TextField(controller: _aboutController, maxLines: 3, decoration: _inputDecoration('Describe your services...')),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Update Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
