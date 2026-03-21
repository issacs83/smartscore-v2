import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/score_library_provider.dart';
import '../widgets/import_dialog.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({Key? key}) : super(key: key);

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Score'),
      ),
      body: _isImporting
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.upload_file,
                          size: 96,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Import a Score',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose a source below',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showImportDialog(),
                    icon: const Icon(Icons.description),
                    label: const Text('Import PDF'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showImportDialog(),
                    icon: const Icon(Icons.music_note),
                    label: const Text('Import MusicXML'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showImportDialog(),
                    icon: const Icon(Icons.image),
                    label: const Text('Import Image'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
    );
  }

  void _showImportDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return ImportDialog(
          onImport: _handleImport,
        );
      },
    );
  }

  Future<void> _handleImport(String filePath, String fileType) async {
    Navigator.of(context).pop();

    setState(() => _isImporting = true);

    try {
      final library = Provider.of<ScoreLibraryProvider>(context, listen: false);

      // Import via Module B
      bool success = false;
      String? newScoreId;

      if (fileType == 'pdf') {
        // Call Module B.importPdf()
        final result = await library.moduleB?.importPdf(filePath);
        if (result?.ok ?? false) {
          newScoreId = result.value.id;
          success = true;
        }
      } else if (fileType == 'musicxml') {
        // Call Module B.importMusicXml()
        final result = await library.moduleB?.importMusicXml(filePath);
        if (result?.ok ?? false) {
          newScoreId = result.value.id;
          success = true;
        }
      } else if (fileType == 'image') {
        // Call Module B.importImage()
        final bytes = await _readFileAsBytes(filePath);
        final result = await library.moduleB?.importImage(bytes);
        if (result?.ok ?? false) {
          newScoreId = result.value.id;
          success = true;
        }
      }

      if (!mounted) return;

      setState(() => _isImporting = false);

      if (success && newScoreId != null) {
        // Refresh library
        await library.loadLibrary();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Score imported successfully'),
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to viewer
        context.go('/viewer/$newScoreId');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${library.lastError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<int>> _readFileAsBytes(String filePath) async {
    // Placeholder - in real implementation, use file_picker plugin
    return [];
  }
}
