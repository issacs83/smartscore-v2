import 'package:flutter/material.dart';

class ScoreCard extends StatelessWidget {
  final Map<String, dynamic> score;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ScoreCard({
    required this.score,
    required this.onTap,
    required this.onDelete,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = score['title'] ?? 'Unknown Score';
    final composer = score['composer'] ?? '';
    final sourceType = score['sourceType'] ?? 'unknown';
    final pageCount = score['pageCount'] ?? 0;
    final measureCount = score['measureCount'] ?? 0;
    final dateImported = score['dateImported'] != null
        ? DateTime.parse(score['dateImported']).toLocal()
        : DateTime.now();

    return GestureDetector(
      onLongPress: () {
        _showContextMenu(context);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and source icon
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.labelLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (composer.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'by $composer',
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildSourceIcon(sourceType),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Metadata row
                Row(
                  children: [
                    if (pageCount > 0)
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.description, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$pageCount pages',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    if (measureCount > 0)
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.music_note, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$measureCount measures',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Date imported
                Text(
                  'Imported: ${_formatDate(dateImported)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceIcon(String sourceType) {
    IconData icon;
    Color color;

    switch (sourceType.toLowerCase()) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'image':
        icon = Icons.image;
        color = Colors.orange;
        break;
      case 'musicxml':
        icon = Icons.music_note;
        color = Colors.blue;
        break;
      default:
        icon = Icons.description;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 1) {
      return 'Just now';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open'),
                onTap: () {
                  Navigator.of(context).pop();
                  onTap();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
