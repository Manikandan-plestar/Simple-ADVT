import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Interactive Card Ratio Crop & Framing Modal
/// Allows businesses to pinch, zoom, pan, and rotate their photos to fit the exact ADVT post card aspect ratio.
class CardRatioCropModal extends StatefulWidget {
  final String imagePath;
  final double targetAspectRatio; // Defaults to 3:4 (card deck proportion)

  const CardRatioCropModal({
    super.key,
    required this.imagePath,
    this.targetAspectRatio = 0.75, // 3:4
  });

  @override
  State<CardRatioCropModal> createState() => _CardRatioCropModalState();
}

class _CardRatioCropModalState extends State<CardRatioCropModal> {
  final GlobalKey _cropAreaKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  
  int _rotationQuarterTurns = 0;
  bool _isProcessing = false;
  bool _showGrid = true;
  BoxFit _fitMode = BoxFit.cover; // cover or contain

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetTransform() {
    setState(() {
      _transformController.value = Matrix4.identity();
      _rotationQuarterTurns = 0;
    });
  }

  void _rotateImage() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _toggleFitMode() {
    setState(() {
      _fitMode = _fitMode == BoxFit.cover ? BoxFit.contain : BoxFit.cover;
      _transformController.value = Matrix4.identity();
    });
  }

  Future<void> _exportCroppedImage() async {
    setState(() => _isProcessing = true);
    try {
      // Hide grid overlay before capturing boundary
      setState(() => _showGrid = false);
      await Future.delayed(const Duration(milliseconds: 60));

      final boundary = _cropAreaKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context, widget.imagePath);
        return;
      }

      // Capture high-resolution render (pixelRatio 3.0 for crisp display)
      final ui.Image capturedImage = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await capturedImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        Navigator.pop(context, widget.imagePath);
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = Directory.systemTemp;
      final exportFile = File('${tempDir.path}/advt_crop_${DateTime.now().millisecondsSinceEpoch}.png');
      await exportFile.writeAsBytes(pngBytes);

      if (mounted) {
        Navigator.pop(context, exportFile.path);
      }
    } catch (e) {
      debugPrint('[CropModal] Error exporting cropped image: $e');
      if (mounted) {
        Navigator.pop(context, widget.imagePath);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildImageWidget() {
    final imageWidget = widget.imagePath.startsWith('http')
        ? Image.network(
            widget.imagePath,
            fit: _fitMode,
            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
          )
        : Image.file(
            File(widget.imagePath),
            fit: _fitMode,
            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
          );

    if (_rotationQuarterTurns == 0) {
      return imageWidget;
    }

    return RotatedBox(
      quarterTurns: _rotationQuarterTurns,
      child: imageWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Sleek dark canvas
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: const Text(
          'Fit to Post Card Size',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isProcessing ? null : _exportCroppedImage,
            icon: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded, color: Colors.white, size: 20),
            label: const Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Subtitle instruction
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pinch_rounded, color: Color(0xFF94A3B8), size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Pinch to zoom & drag to frame your post',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ],
            ),
          ),

          // Main Crop Framing Viewport
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AspectRatio(
                  aspectRatio: widget.targetAspectRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF4F46E5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Repaint Boundary that gets captured
                        RepaintBoundary(
                          key: _cropAreaKey,
                          child: Container(
                            color: Colors.black,
                            child: InteractiveViewer(
                              transformationController: _transformController,
                              minScale: 0.5,
                              maxScale: 4.5,
                              panEnabled: true,
                              scaleEnabled: true,
                              boundaryMargin: const EdgeInsets.all(120),
                              child: Center(
                                child: _buildImageWidget(),
                              ),
                            ),
                          ),
                        ),

                        // Interactive 3x3 Grid Overlay (Rule of Thirds)
                        if (_showGrid)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _CardGridPainter(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Control Toolbar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Rotate Button
                _buildToolButton(
                  icon: Icons.rotate_right_rounded,
                  label: 'Rotate',
                  onTap: _rotateImage,
                ),

                // Fit / Fill Toggle
                _buildToolButton(
                  icon: _fitMode == BoxFit.cover ? Icons.crop_free_rounded : Icons.aspect_ratio_rounded,
                  label: _fitMode == BoxFit.cover ? 'Fill Card' : 'Fit Full',
                  onTap: _toggleFitMode,
                ),

                // Grid Toggle
                _buildToolButton(
                  icon: _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                  label: 'Grid',
                  isActive: _showGrid,
                  onTap: () => setState(() => _showGrid = !_showGrid),
                ),

                // Reset Button
                _buildToolButton(
                  icon: Icons.restart_alt_rounded,
                  label: 'Reset',
                  onTap: _resetTransform,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF818CF8) : Colors.white70,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF818CF8) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for rule-of-thirds grid lines
class _CardGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.0;

    // Vertical lines
    final thirdWidth = size.width / 3;
    canvas.drawLine(Offset(thirdWidth, 0), Offset(thirdWidth, size.height), paint);
    canvas.drawLine(Offset(thirdWidth * 2, 0), Offset(thirdWidth * 2, size.height), paint);

    // Horizontal lines
    final thirdHeight = size.height / 3;
    canvas.drawLine(Offset(0, thirdHeight), Offset(size.width, thirdHeight), paint);
    canvas.drawLine(Offset(0, thirdHeight * 2), Offset(size.width, thirdHeight * 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
