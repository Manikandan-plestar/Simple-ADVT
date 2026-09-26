import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Displays Job or Offer post images one at a time.
/// - If multiple images exist, automatically cycles to the next image every 5 seconds.
/// - If only 1 image exists, renders statically without running a timer.
/// - If 0 images exist, renders the [emptyWidget] or null.
/// - Supports both local device file paths and network URLs.
class CyclingPostImage extends StatefulWidget {
  final List<String> images;
  final double height;
  final double? width;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final Duration interval;
  final Widget? emptyWidget;
  final List<Widget>? overlayWidgets;
  final bool showIndicators;

  const CyclingPostImage({
    super.key,
    required this.images,
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.fit = BoxFit.cover,
    this.interval = const Duration(seconds: 5),
    this.emptyWidget,
    this.overlayWidgets,
    this.showIndicators = true,
  });

  @override
  State<CyclingPostImage> createState() => _CyclingPostImageState();
}

class _CyclingPostImageState extends State<CyclingPostImage> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant CyclingPostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length ||
        oldWidget.images != widget.images) {
      _currentIndex = 0;
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(widget.interval, (timer) {
        if (mounted && widget.images.isNotEmpty) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % widget.images.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return widget.emptyWidget ?? const SizedBox.shrink();
    }

    final hasMultiple = widget.images.length > 1;
    final safeIndex = _currentIndex < widget.images.length ? _currentIndex : 0;
    final currentImagePath = widget.images[safeIndex];

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Container(
        width: widget.width ?? double.infinity,
        height: widget.height,
        color: const Color(0xFFF3F4F6),
        child: Stack(
          children: [
            // Image Content (AnimatedSwitcher for multiple images, static for 1 image)
            Positioned.fill(
              child: hasMultiple
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: _buildImageSource(
                        currentImagePath,
                        key: ValueKey<String>(currentImagePath),
                      ),
                    )
                  : _buildImageSource(widget.images.first),
            ),

            // Optional Image Counter / Dots Indicator when multiple images exist
            if (hasMultiple && widget.showIndicators)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.collections_rounded, size: 10, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        '${safeIndex + 1}/${widget.images.length}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Additional overlay badges (e.g. discount pill, special offer badge)
            if (widget.overlayWidgets != null) ...widget.overlayWidgets!,
          ],
        ),
      ),
    );
  }

  Widget _buildImageSource(String pathOrUrl, {Key? key}) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(
        pathOrUrl,
        key: key,
        width: widget.width ?? double.infinity,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFFF3F4F6),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildErrorFallback(),
      );
    }

    final file = File(pathOrUrl);
    if (file.existsSync()) {
      return Image.file(
        file,
        key: key,
        width: widget.width ?? double.infinity,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildErrorFallback(),
      );
    }

    return _buildErrorFallback();
  }

  Widget _buildErrorFallback() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height,
      color: const Color(0xFFEEF2FF),
      child: const Center(
        child: Icon(Icons.image_not_supported_rounded, color: Color(0xFF4F46E5), size: 36),
      ),
    );
  }
}
