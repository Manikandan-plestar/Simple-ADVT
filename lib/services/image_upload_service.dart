import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  /// Uploads a single image if it is a local device file path.
  /// If it is already a network URL (http/https) or an asset, returns it directly.
  Future<String> uploadImageIfNeeded(String pathOrUrl) async {
    final clean = pathOrUrl.trim();
    if (clean.isEmpty) return clean;
    if (clean.startsWith('http://') || clean.startsWith('https://') || clean.startsWith('assets/')) {
      return clean;
    }

    final file = File(clean);
    if (!file.existsSync()) {
      return clean;
    }

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return clean;

      final base64Data = base64Encode(bytes);
      final filename = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'image.png';
      final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'png';

      final baseUrl = ApiClient().baseUrl;
      final url = Uri.parse('$baseUrl/api/upload-image');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'image': base64Data,
              'filename': filename,
              'ext': ext,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['url'] != null) {
          final serverUrl = data['url'].toString();
          if (kDebugMode) {
            print('[ImageUploadService] Uploaded local file ($filename) -> $serverUrl');
          }
          return serverUrl;
        }
      } else {
        if (kDebugMode) {
          print('[ImageUploadService] Server returned status ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ImageUploadService] Error uploading image $clean: $e');
      }
    }

    return clean;
  }

  /// Uploads a list of images, replacing any local files with public server URLs.
  Future<List<String>> uploadImages(List<String> pathsOrUrls) async {
    final results = <String>[];
    for (final item in pathsOrUrls) {
      final uploaded = await uploadImageIfNeeded(item);
      results.add(uploaded);
    }
    return results;
  }
}
