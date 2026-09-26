import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/target_location_model.dart';
import '../../services/device_image_picker_service.dart';
import '../../services/target_location_service.dart';
import 'target_location_picker_modal.dart';

class CreatePostModal extends StatefulWidget {
  final Function({
    required String title,
    required String subtitle,
    required String description,
    required String targetLocation,
    List<TargetLocationModel>? targetLocations,
    List<String>? images,
  }) onSubmit;

  const CreatePostModal({
    super.key,
    required this.onSubmit,
  });

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  List<String> _selectedImages = [];
  bool _isProcessingImages = false;

  List<TargetLocationModel> _selectedTargetLocations = [
    TargetLocationService.defaultLocations.firstWhere(
      (loc) => loc.placeId == 'city_tirunelveli',
      orElse: () => TargetLocationService.defaultLocations.first,
    ),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImagesFromDevice() async {
    setState(() => _isProcessingImages = true);
    try {
      final result = await DeviceImagePickerService.pickImagesFromGallery(
        currentSelected: _selectedImages,
        maxLimit: 6,
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
        setState(() => _isProcessingImages = false);
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _openLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TargetLocationPickerModal(
        initialSelectedLocations: _selectedTargetLocations,
        onApply: (updatedLocations) {
          setState(() {
            _selectedTargetLocations = updatedLocations;
          });
        },
      ),
    );
  }

  void _removeLocation(TargetLocationModel loc) {
    setState(() {
      _selectedTargetLocations.removeWhere((e) => e.placeId == loc.placeId);
    });
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'country':
        return const Color(0xFF4338CA);
      case 'state':
        return const Color(0xFF7C3AED);
      case 'city':
      case 'district':
        return const Color(0xFF2563EB);
      case 'locality':
      case 'sublocality':
      case 'area':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF4B5563);
    }
  }

  void _handleSubmit() {
    final title = _titleController.text.trim();
    final description = _descController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a post title or headline.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedTargetLocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one target location for your post.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final targetLocationStr = _selectedTargetLocations.map((e) => e.name).join(', ');

    Navigator.pop(context);
    widget.onSubmit(
      title: title,
      subtitle: '',
      description: description,
      targetLocation: targetLocationStr,
      targetLocations: _selectedTargetLocations,
      images: _selectedImages,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.post_add_rounded, color: Color(0xFF4F46E5), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Create New Post',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Post Images Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Post Images',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                Text(
                  '${_selectedImages.length}/6 images',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Images Grid / Picker Row
            SizedBox(
              height: 86,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Add Image Button
                  GestureDetector(
                    onTap: _isProcessingImages ? null : _pickImagesFromDevice,
                    child: Container(
                      width: 86,
                      height: 86,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid),
                      ),
                      child: _isProcessingImages
                          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5))))
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF4F46E5), size: 26),
                                SizedBox(height: 4),
                                Text('Add Image', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
                              ],
                            ),
                    ),
                  ),

                  // Selected Images Previews
                  ..._selectedImages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final imgPath = entry.value;
                    return Container(
                      width: 86,
                      height: 86,
                      margin: const EdgeInsets.only(right: 10),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: imgPath.startsWith('http')
                                ? Image.network(imgPath, width: 86, height: 86, fit: BoxFit.cover)
                                : Image.file(File(imgPath), width: 86, height: 86, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Post Title
            const Text(
              'Title / Headline',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g. Grand Summer Clearance Sale or Special Promotion',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Post Description
            const Text(
              'Description & Details',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add full details, highlights, or announcement description...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
              ),
            ),
            const SizedBox(height: 18),

            // 4. Target Locations
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Target Locations',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                GestureDetector(
                  onTap: _openLocationPicker,
                  child: const Text(
                    '+ Add / Edit Locations',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Target Location Chips
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: _selectedTargetLocations.isEmpty
                  ? GestureDetector(
                      onTap: _openLocationPicker,
                      child: const Row(
                        children: [
                          Icon(Icons.add_location_alt_outlined, size: 16, color: Color(0xFF4F46E5)),
                          SizedBox(width: 8),
                          Text('Tap to select target areas for this post...', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        ],
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _selectedTargetLocations.map((loc) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE0E7FF)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: _getTypeColor(loc.type).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  loc.type.toUpperCase(),
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: _getTypeColor(loc.type)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(loc.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _removeLocation(loc),
                                child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF9CA3AF)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 24),

            // Publish Post Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Publish Post', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
