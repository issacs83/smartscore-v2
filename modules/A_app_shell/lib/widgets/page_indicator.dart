import 'package:flutter/material.dart';

class PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int page)? onPageChanged;

  const PageIndicator({
    required this.currentPage,
    required this.totalPages,
    this.onPageChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page slider
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: currentPage.toDouble(),
                  min: 0,
                  max: (totalPages - 1).toDouble(),
                  divisions: totalPages > 1 ? totalPages - 1 : 1,
                  label: '${currentPage + 1}',
                  onChanged: (value) {
                    onPageChanged?.call(value.toInt());
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Page info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page ${currentPage + 1} of $totalPages',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${((currentPage + 1) / totalPages * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
