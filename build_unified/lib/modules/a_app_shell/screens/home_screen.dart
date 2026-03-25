import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../../../demo_data.dart';

const String _omrServerUrl = 'http://58.29.21.11:5000';

/// Home screen: shows demo scores and allows MusicXML file import.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _importing = false;
  String _loadingMessage = '';
  double _loadingProgress = 0;

  void _showLoadingDialog(String message) {
    _loadingMessage = message;
    _loadingProgress = 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Store setter for external updates
          _dialogSetState = setDialogState;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  width: 56, height: 56,
                  child: CircularProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _loadingMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (_loadingProgress > 0) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _loadingProgress),
                  const SizedBox(height: 4),
                  Text(
                    '${(_loadingProgress * 100).round()}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void Function(void Function())? _dialogSetState;

  void _updateLoading(String message, double progress) {
    _loadingMessage = message;
    _loadingProgress = progress;
    _dialogSetState?.call(() {});
  }

  void _closeLoadingDialog() {
    _dialogSetState = null;
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _importFile() async {
    if (!kIsWeb) return;

    setState(() => _importing = true);

    try {
      final input = html.FileUploadInputElement()
        ..accept = ''  // Empty = show all files on mobile
        ..multiple = false;

      // Trigger the file picker dialog
      input.click();

      await input.onChange.first;

      final file = input.files?.first;
      if (file == null) {
        setState(() => _importing = false);
        return;
      }

      final reader = html.FileReader();
      reader.readAsText(file);
      await reader.onLoad.first;

      final xmlContent = reader.result as String?;
      if (xmlContent == null || xmlContent.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File is empty or could not be read')),
          );
        }
        setState(() => _importing = false);
        return;
      }

      // Validate: must be XML content (MusicXML)
      final isXml = xmlContent.trimLeft().startsWith('<?xml') ||
          xmlContent.trimLeft().startsWith('<score-partwise') ||
          xmlContent.trimLeft().startsWith('<score-timewise') ||
          xmlContent.trimLeft().startsWith('<!DOCTYPE');
      if (!isXml) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not a MusicXML file. Please select a .xml or .musicxml file.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() => _importing = false);
        return;
      }

      final title = file.name
          .replaceAll(RegExp(r'\.(xml|musicxml|mxl)$', caseSensitive: false), '');
      final scoreId = DemoData.addImported(title, xmlContent);

      if (mounted) {
        setState(() => _importing = false);
        context.go('/viewer/$scoreId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _captureCamera() async {
    if (!kIsWeb) return;
    setState(() => _importing = true);
    try {
      // Use capture attribute to open camera on mobile
      final input = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..setAttribute('capture', 'environment');
      input.click();
      await input.onChange.first;
      final file = input.files?.first;
      if (file == null) {
        setState(() => _importing = false);
        return;
      }
      await _processImageFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _scanImage() async {
    if (!kIsWeb) return;
    setState(() => _importing = true);
    try {
      final input = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..multiple = false;
      input.click();
      await input.onChange.first;
      final file = input.files?.first;
      if (file == null) {
        setState(() => _importing = false);
        return;
      }
      await _processImageFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e'), duration: const Duration(seconds: 5)),
        );
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _processImageFile(html.File file) async {
    _showLoadingDialog('Preparing image...');
    await Future.delayed(const Duration(milliseconds: 300));
    _updateLoading('Uploading to AI server...', 0.1);

    try {
      final formData = html.FormData();
      formData.appendBlob('image', file, file.name);

      _updateLoading('AI is recognizing music notation...\nThis may take 30-60 seconds.', 0.2);

      final request = html.HttpRequest();
      request.open('POST', '$_omrServerUrl/omr');

      // Progress simulation while waiting
      var progress = 0.2;
      final progressTimer = Timer.periodic(const Duration(seconds: 2), (t) {
        progress = (progress + 0.05).clamp(0.0, 0.85);
        final step = progress < 0.4 ? 'Detecting staff lines...'
            : progress < 0.6 ? 'Recognizing notes and symbols...'
            : progress < 0.8 ? 'Building music structure...'
            : 'Generating MusicXML...';
        _updateLoading(step, progress);
      });

      final completer = request.onLoad.first;
      request.send(formData);
      await completer;

      progressTimer.cancel();
      _updateLoading('Processing result...', 0.95);

      if (request.status == 200) {
        final response = jsonDecode(request.responseText ?? '{}');
        if (response['success'] == true && response['musicxml'] != null) {
          final musicXml = response['musicxml'] as String;
          final title = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
          final pngBase64 = response['png_base64'] as String?;
          final scoreId = DemoData.addImported(title, musicXml, pngBase64: pngBase64);

          _updateLoading('Done!', 1.0);
          await Future.delayed(const Duration(milliseconds: 500));
          _closeLoadingDialog();

          if (mounted) {
            setState(() => _importing = false);
            context.go('/viewer/$scoreId');
          }
          return;
        } else {
          throw Exception(response['error'] ?? 'OMR failed');
        }
      } else {
        throw Exception('Server error: ${request.status}');
      }
    } catch (e) {
      _closeLoadingDialog();
      if (mounted) {
        setState(() => _importing = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Recognition Failed'),
            content: Text('$e\n\nTip: Try with a simpler, cleaner score image.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allScores = DemoData.allScores;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Icon(Icons.music_note, color: colorScheme.primary, size: 28),
            const SizedBox(width: 8),
            Text(
              'SmartScore',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _importing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : PopupMenuButton<String>(
                      icon: Icon(Icons.add, color: colorScheme.primary),
                      tooltip: 'Import',
                      onSelected: (value) {
                        if (value == 'scan') _scanImage();
                        if (value == 'camera') _captureCamera();
                        if (value == 'xml') _importFile();
                        if (value == 'corpus') context.go('/corpus');
                        if (value == 'imslp') context.go('/imslp');
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'corpus',
                          child: ListTile(
                            leading: Icon(Icons.menu_book),
                            title: Text('Browse Library (15K+ scores)'),
                            subtitle: Text('Built-in corpus — 100% accurate'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'camera',
                          child: ListTile(
                            leading: Icon(Icons.camera_alt),
                            title: Text('Take Photo'),
                            subtitle: Text('Capture score with camera'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'scan',
                          child: ListTile(
                            leading: Icon(Icons.image_search),
                            title: Text('Scan Image'),
                            subtitle: Text('Select image from gallery'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'xml',
                          child: ListTile(
                            leading: Icon(Icons.upload_file),
                            title: Text('Import MusicXML'),
                            subtitle: Text('Open .xml or .musicxml file'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'imslp',
                          child: ListTile(
                            leading: Icon(Icons.library_music),
                            title: Text('Browse IMSLP'),
                            subtitle: Text('Search 210,000+ free scores'),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CorpusBanner(onTap: () => context.go('/corpus')),
              const SizedBox(height: 16),
              Text(
                'Scores',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: allScores.entries.map((entry) {
                    return _ScoreCard(
                      scoreId: entry.key,
                      title: entry.value['title'] ?? entry.key,
                      composer: entry.value['composer'] ?? '',
                      isImported: DemoData.isImported(entry.key),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String scoreId;
  final String title;
  final String composer;
  final bool isImported;

  const _ScoreCard({
    required this.scoreId,
    required this.title,
    required this.composer,
    required this.isImported,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isImported
                    ? colorScheme.secondaryContainer
                    : colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isImported ? Icons.upload_file : Icons.music_note,
                color: isImported
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onPrimaryContainer,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (composer.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      composer,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (isImported) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Imported',
                      style: TextStyle(
                        color: colorScheme.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => context.go('/viewer/$scoreId'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prominent banner for the built-in corpus browser.
class _CorpusBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _CorpusBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.menu_book, color: colorScheme.primary, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Browse Library (15,026 scores)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bach, Beethoven, Mozart and more — 100% accurate MusicXML',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
