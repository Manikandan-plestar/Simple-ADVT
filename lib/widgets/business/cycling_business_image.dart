import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Displays business profile images one at a time.
/// If multiple images (2-4) exist, it automatically cycles through them at a fixed interval (1s).
/// If only 1 image exists, it remains static without starting a timer.
/// Seamlessly supports local device files (File), network URLs, and asset images.
class CyclingBusinessImage extends StatefulWidget {
  final List<String> images;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final Duration interval;
  final Widget? emptyWidget;

  const CyclingBusinessImage({
    super.key,
    required this.images,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.fit = BoxFit.cover,
    this.interval = const Duration(seconds: 1),
    this.emptyWidget,
  });

  @override
  State<CyclingBusinessImage> createState() => _CyclingBusinessImageState();
}

class _CyclingBusinessImageState extends State<CyclingBusinessImage> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant CyclingBusinessImage oldWidget) {
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
      if (widget.emptyWidget != null) {
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: widget.emptyWidget!,
        );
      }
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: Container(
          width: widget.width,
          height: widget.height,
          color: const Color(0xFFEEF2FF),
          child: const Center(
            child: Icon(Icons.store_rounded, color: Color(0xFF4F46E5), size: 36),
          ),
        ),
      );
    }

    // If only 1 image, render statically without AnimatedSwitcher
    if (widget.images.length == 1) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: _buildImageSource(widget.images.first),
        ),
      );
    }

    final safeIndex = _currentIndex < widget.images.length ? _currentIndex : 0;
    final currentImageUrl = widget.images[safeIndex];

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: _buildImageSource(
            currentImageUrl,
            key: ValueKey<String>(currentImageUrl),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSource(String pathOrUrl, {Key? key}) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(
        pathOrUrl,
        key: key,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xFF4F46E5),
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
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
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildErrorFallback(),
      );
    }

    return _buildErrorFallback();
  }

  Widget _buildErrorFallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFEEF2FF),
      child: const Center(
        child: Icon(Icons.store_rounded, color: Color(0xFF4F46E5), size: 36),
      ),
    );
  }
}
