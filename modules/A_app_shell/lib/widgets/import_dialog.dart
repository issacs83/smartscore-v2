import 'package:flutter/material.dart';

class ImportDialog extends StatelessWidget {
  final Function(String filePath, String fileType) onImport;

  const ImportDialog({
    required this.onImport,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Score'),
      content: const Text('Select a file format to import:'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            // In production, use file_picker plugin
            onImport('sample.pdf', 'pdf');
          },
          child: const Text('PDF'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            // In production, use file_picker plugin
            onImport('sample.musicxml', 'musicxml');
          },
          child: const Text('MusicXML'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            // In production, use image_picker plugin
            onImport('sample.jpg', 'image');
          },
          child: const Text('Image'),
        ),
      ],
    );
  }
}
