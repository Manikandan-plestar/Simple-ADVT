import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Shared service for picking real local device images for Business Job & Offer posts.
class DeviceImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  /// Opens the device's native gallery picker to select multiple images.
  /// Enforces [maxLimit] and merges cleanly with [currentSelected].
  static Future<List<String>> pickImagesFromGallery({
    required List<String> currentSelected,
    int maxLimit = 6,
  }) async {
    try {
      final remainingSlots = maxLimit - currentSelected.length;
      if (remainingSlots <= 0) {
        return currentSelected;
      }

      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        limit: remainingSlots > 0 ? remainingSlots : null,
      );

      if (pickedFiles.isEmpty) {
        // User cancelled selection; keep current images unchanged
        return currentSelected;
      }

      final updated = List<String>.from(currentSelected);

      for (final xfile in pickedFiles) {
        final path = xfile.path;
        if (path.isNotEmpty && !updated.contains(path)) {
          // Verify file exists if on a supported filesystem
          try {
            final f = File(path);
            if (f.existsSync()) {
              updated.add(path);
            } else {
              // If async file or virtual provider, still retain path
              updated.add(path);
            }
          } catch (_) {
            updated.add(path);
          }
        }
        if (updated.length >= maxLimit) break;
      }

      return updated;
    } catch (e) {
      debugPrint('DeviceImagePickerService error during pickMultiImage: $e');
      return currentSelected;
    }
  }

  /// Opens native picker for a single image (from Gallery or Camera)
  static Future<String?> pickSingleImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(source: source);
      return file?.path;
    } catch (e) {
      debugPrint('DeviceImagePickerService error during pickImage: $e');
      return null;
    }
  }
}
