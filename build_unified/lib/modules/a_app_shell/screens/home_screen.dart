import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../../../demo_data.dart';

/// Home screen: shows demo scores and allows MusicXML file import.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _importing = false;

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
                  : OutlinedButton.icon(
                      onPressed: _importFile,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Import MusicXML'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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
