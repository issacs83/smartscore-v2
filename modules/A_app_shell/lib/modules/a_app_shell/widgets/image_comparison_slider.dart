import 'package:flutter/material.dart';

/// Widget that displays two images with a draggable divider for comparison
/// Left side: Original image (원본)
/// Right side: Restored image (복원)
class ImageComparisonSlider extends StatefulWidget {
  final ImageProvider beforeImage;
  final ImageProvider afterImage;
  final double height;
  final double width;

  const ImageComparisonSlider({
    Key? key,
    required this.beforeImage,
    required this.afterImage,
    this.height = 400,
    this.width = 600,
  }) : super(key: key);

  @override
  State<ImageComparisonSlider> createState() => _ImageComparisonSliderState();
}

class _ImageComparisonSliderState extends State<ImageComparisonSlider> {
  late double _dividerPosition;

  @override
  void initState() {
    super.initState();
    _dividerPosition = 0.5;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dividerPosition += details.delta.dx / widget.width;
      _dividerPosition = _dividerPosition.clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey[50],
      ),
      child: Stack(
        children: [
          // After (Restored) image - full width background
          Positioned.fill(
            child: Image(
              image: widget.afterImage,
              fit: BoxFit.cover,
            ),
          ),
          // Before (Original) image - clipped by divider position
          Positioned(
            left: 0,
            top: 0,
            width: widget.width * _dividerPosition,
            height: widget.height,
            child: ClipRect(
              child: Image(
                image: widget.beforeImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Labels
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '원본 (Original)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '복원 (Restored)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Draggable divider
          Positioned(
            left: widget.width * _dividerPosition - 2,
            top: 0,
            width: 4,
            height: widget.height,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragUpdate: _handleDragUpdate,
                child: Container(
                  color: Colors.blue.withOpacity(0.7),
                  child: const Center(
                    child: Icon(
                      Icons.drag_handle,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
