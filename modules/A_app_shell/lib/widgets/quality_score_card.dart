import 'package:flutter/material.dart';
import '../services/restoration_service.dart';

/// Widget that visualizes quality score components from Module C
class QualityScoreCard extends StatelessWidget {
  final double overallScore;
  final QualityComponents? components;
  final double? processingTimeMs;
  final double? skewAngle;
  final bool compact;

  const QualityScoreCard({
    required this.overallScore,
    this.components,
    this.processingTimeMs,
    this.skewAngle,
    this.compact = false,
    super.key,
  });

  Color _getScoreColor(double score) {
    if (score >= 0.90) return Colors.green;
    if (score >= 0.75) return Colors.green.shade300;
    if (score >= 0.60) return Colors.yellow.shade700;
    if (score >= 0.40) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel(double score) {
    if (score >= 0.90) return '우수';
    if (score >= 0.75) return '양호';
    if (score >= 0.60) return '보통';
    if (score >= 0.40) return '부족';
    return '사용 불가';
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    final color = _getScoreColor(overallScore);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: overallScore,
                strokeWidth: 3,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Text(
                '${(overallScore * 100).round()}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _getScoreLabel(overallScore),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFull(BuildContext context) {
    final color = _getScoreColor(overallScore);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall score header
            Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: overallScore,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(overallScore * 100).round()}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            '점',
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '품질 점수',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getScoreLabel(overallScore),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (components != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                '세부 점수',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              ..._buildComponentBars(),
            ],

            if (processingTimeMs != null || skewAngle != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildMetadataRow(context),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildComponentBars() {
    if (components == null) return [];
    final map = components!.toMap();
    final labels = QualityComponents.labels;
    final weights = QualityComponents.weights;

    return map.entries.map((entry) {
      final label = labels[entry.key] ?? entry.key;
      final weight = weights[entry.key] ?? 0.0;
      final value = entry.value;
      final color = _getScoreColor(value);

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${(weight * 100).round()}%)',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Text(
                  value.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildMetadataRow(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        if (processingTimeMs != null)
          _buildMetadataChip(
            Icons.timer_outlined,
            '처리 시간',
            processingTimeMs! < 1000
                ? '${processingTimeMs!.round()}ms'
                : '${(processingTimeMs! / 1000).toStringAsFixed(1)}초',
          ),
        if (skewAngle != null)
          _buildMetadataChip(
            Icons.rotate_right,
            '기울기',
            '${skewAngle!.toStringAsFixed(1)}°',
          ),
      ],
    );
  }

  Widget _buildMetadataChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
