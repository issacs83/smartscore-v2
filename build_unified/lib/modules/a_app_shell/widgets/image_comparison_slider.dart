import 'dart:typed_data';
import 'package:flutter/material.dart';

/// A widget that shows two images side by side with a draggable divider
/// for before/after comparison.
class ImageComparisonSlider extends StatefulWidget {
  final Uint8List originalImage;
  final Uint8List restoredImage;
  final String leftLabel;
  final String rightLabel;
  final double initialPosition;

  const ImageComparisonSlider({
    required this.originalImage,
    required this.restoredImage,
    this.leftLabel = '원본',
    this.rightLabel = '복원',
    this.initialPosition = 0.5,
    super.key,
  });

  @override
  State<ImageComparisonSlider> createState() => _ImageComparisonSliderState();
}

class _ImageComparisonSliderState extends State<ImageComparisonSlider> {
  late double _dividerPosition;

  @override
  void initState() {
    super.initState();
    _dividerPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final dividerX = width * _dividerPosition;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dividerPosition =
                  (details.localPosition.dx / width).clamp(0.05, 0.95);
            });
          },
          child: Stack(
            children: [
              // Right side: restored image (full width, shown behind)
              Positioned.fill(
                child: Image.memory(
                  widget.restoredImage,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),

              // Left side: original image (clipped to divider position)
              Positioned.fill(
                child: ClipRect(
                  clipper: _LeftClipper(dividerX),
                  child: Image.memory(
                    widget.originalImage,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),

              // Divider line
              Positioned(
                left: dividerX - 1.5,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  color: Colors.white,
                ),
              ),

              // Drag handle
              Positioned(
                left: dividerX - 20,
                top: height / 2 - 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.drag_handle,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
              ),

              // Left label
              Positioned(
                left: 8,
                top: 8,
                child: _buildLabel(widget.leftLabel),
              ),

              // Right label
              Positioned(
                right: 8,
                top: 8,
                child: _buildLabel(widget.rightLabel),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Custom clipper that clips the left portion of a widget
class _LeftClipper extends CustomClipper<Rect> {
  final double dividerX;

  _LeftClipper(this.dividerX);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, dividerX, size.height);
  }

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) {
    return oldClipper.dividerX != dividerX;
  }
}
