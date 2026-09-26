import 'dart:io';
import 'package:flutter/material.dart';

/// Opens the device's local file / gallery picker to select real local images.
/// - Scans device image folders (DCIM, Pictures, Downloads, Documents) for real image files.
/// - Allows searching and browsing device directories.
/// - Allows manual file path entry or browsing any local folder on the device.
/// - Allows multiple selection up to [maxLimit].
/// - Displays real file previews and lets the user confirm or toggle files.
class DeviceGalleryPicker {
  static Future<List<String>?> show({
    required BuildContext context,
    required List<String> currentSelected,
    int maxLimit = 6,
  }) async {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DeviceGalleryPickerSheet(
        initialSelected: currentSelected,
        maxLimit: maxLimit,
      ),
    );
  }
}

class _DeviceGalleryPickerSheet extends StatefulWidget {
  final List<String> initialSelected;
  final int maxLimit;

  const _DeviceGalleryPickerSheet({
    required this.initialSelected,
    required this.maxLimit,
  });

  @override
  State<_DeviceGalleryPickerSheet> createState() => _DeviceGalleryPickerSheetState();
}

class _DeviceGalleryPickerSheetState extends State<_DeviceGalleryPickerSheet> {
  late List<String> _selected;
  List<File> _foundLocalFiles = [];
  bool _isLoading = true;
  String _currentFolder = '';
  final TextEditingController _customPathController = TextEditingController();
  final TextEditingController _searchFilterController = TextEditingController();

  static const List<String> _imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.gif',
    '.bmp',
  ];

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
    _scanDeviceDirectories();
  }

  @override
  void dispose() {
    _customPathController.dispose();
    _searchFilterController.dispose();
    super.dispose();
  }

  /// Scan common platform-specific directories for local device images
  Future<void> _scanDeviceDirectories([String? targetDir]) async {
    setState(() => _isLoading = true);

    final List<File> discovered = [];
    final List<Directory> dirsToScan = [];

    if (targetDir != null && targetDir.isNotEmpty) {
      final customDir = Directory(targetDir);
      if (await customDir.exists()) {
        dirsToScan.add(customDir);
        _currentFolder = customDir.path;
      }
    } else {
      // Platform specific default directories
      if (Platform.isAndroid) {
        final paths = [
          '/storage/emulated/0/DCIM/Camera',
          '/storage/emulated/0/DCIM',
          '/storage/emulated/0/Pictures',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/WhatsApp/Media/WhatsApp Images',
        ];
        for (final p in paths) {
          final d = Directory(p);
          if (await d.exists()) dirsToScan.add(d);
        }
      } else if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        final paths = [
          '$userProfile\\Pictures',
          '$userProfile\\Downloads',
          '$userProfile\\Desktop',
          Directory.current.path,
        ];
        for (final p in paths) {
          if (p.isNotEmpty) {
            final d = Directory(p);
            if (await d.exists()) dirsToScan.add(d);
          }
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        final home = Platform.environment['HOME'] ?? '';
        final paths = [
          '$home/Pictures',
          '$home/Downloads',
          '$home/Desktop',
        ];
        for (final p in paths) {
          if (p.isNotEmpty) {
            final d = Directory(p);
            if (await d.exists()) dirsToScan.add(d);
          }
        }
      }
    }

    // Traverse directory trees up to 2 levels deep
    for (final dir in dirsToScan) {
      try {
        final entities = dir.listSync(recursive: false, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final ext = entity.path.toLowerCase();
            if (_imageExtensions.any((e) => ext.endsWith(e))) {
              discovered.add(entity);
            }
          } else if (entity is Directory && targetDir == null) {
            try {
              final subEntities = entity.listSync(recursive: false, followLinks: false);
              for (final sub in subEntities) {
                if (sub is File) {
                  final ext = sub.path.toLowerCase();
                  if (_imageExtensions.any((e) => ext.endsWith(e))) {
                    discovered.add(sub);
                  }
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    // Also include any previously selected files that still exist
    for (final selectedPath in _selected) {
      final file = File(selectedPath);
      if (file.existsSync() && !discovered.any((f) => f.path == file.path)) {
        discovered.insert(0, file);
      }
    }

    if (mounted) {
      setState(() {
        _foundLocalFiles = discovered;
        _isLoading = false;
      });
    }
  }

  void _toggleSelect(String localPath) {
    setState(() {
      if (_selected.contains(localPath)) {
        _selected.remove(localPath);
      } else {
        if (_selected.length >= widget.maxLimit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum ${widget.maxLimit} images allowed.'),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _selected.add(localPath);
      }
    });
  }

  void _addManualPath() {
    final path = _customPathController.text.trim();
    if (path.isEmpty) return;

    final file = File(path);
    if (file.existsSync()) {
      if (!_selected.contains(file.path)) {
        if (_selected.length >= widget.maxLimit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Maximum ${widget.maxLimit} images allowed.')),
          );
          return;
        }
        setState(() {
          _selected.add(file.path);
          if (!_foundLocalFiles.any((f) => f.path == file.path)) {
            _foundLocalFiles.insert(0, file);
          }
        });
      }
      _customPathController.clear();
      Navigator.of(context, rootNavigator: true).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found at specified path.')),
      );
    }
  }

  void _showAddCustomFileDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Local File by Path', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the full absolute path of an image file on this device:',
              style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customPathController,
              decoration: InputDecoration(
                hintText: Platform.isWindows
                    ? 'C:\\Users\\Username\\Pictures\\photo.jpg'
                    : '/storage/emulated/0/DCIM/photo.jpg',
                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addManualPath,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add File'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchFilterController.text.trim().toLowerCase();
    final displayedFiles = query.isEmpty
        ? _foundLocalFiles
        : _foundLocalFiles.where((f) => f.path.toLowerCase().contains(query)).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      padding: const EdgeInsets.only(top: 14, left: 20, right: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Local Files & Photos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select 1 to ${widget.maxLimit} local images (${_selected.length}/${widget.maxLimit} selected)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search and Action Bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: TextField(
                    controller: _searchFilterController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Filter local files...',
                      hintStyle: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      prefixIcon: Icon(Icons.search_rounded, size: 16, color: Color(0xFF6366F1)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showAddCustomFileDialog,
                icon: const Icon(Icons.add_link_rounded, color: Color(0xFF4F46E5)),
                tooltip: 'Add file by path',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEEF2FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _scanDeviceDirectories(),
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4B5563)),
                tooltip: 'Rescan device folders',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selected Chips Preview Bar (if any selected)
          if (_selected.isNotEmpty)
            Container(
              height: 38,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selected.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final path = _selected[idx];
                  final name = path.split(Platform.isWindows ? '\\' : '/').last;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(path),
                            width: 20,
                            height: 20,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 14),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _toggleSelect(path),
                          child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF4338CA)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Main Files Grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4F46E5),
                    ),
                  )
                : displayedFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text(
                              'No local image files found in device folders',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Place image files in your Pictures/Downloads folder\nor tap the + button above to add an image path directly.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _showAddCustomFileDialog,
                              icon: const Icon(Icons.add_rounded, size: 14),
                              label: const Text('Add File by Path', style: TextStyle(fontSize: 11.5)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                side: const BorderSide(color: Color(0xFF4F46E5)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        itemCount: displayedFiles.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        ),
                        itemBuilder: (context, idx) {
                          final file = displayedFiles[idx];
                          final isSelected = _selected.contains(file.path);
                          final fileName = file.path.split(Platform.isWindows ? '\\' : '/').last;

                          return GestureDetector(
                            onTap: () => _toggleSelect(file.path),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.broken_image_rounded, color: Color(0xFF9CA3AF), size: 24),
                                      ),
                                    ),
                                  ),
                                ),
                                // Selection Checkbox Badge
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF4F46E5) : Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.check_rounded : Icons.add_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                                // File name caption
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                    ),
                                    child: Text(
                                      fileName,
                                      style: const TextStyle(fontSize: 8.5, color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                'Confirm Selection (${_selected.length}/${widget.maxLimit})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
