import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/score_library_provider.dart';
import '../theme.dart';

// ============================================================
// Import source types
// ============================================================
enum _ImportSource { camera, pdf, musicXml, image, url }

// ============================================================
// ImportScreen
// ============================================================
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _isImporting = false;
  String _importStatusMessage = '';
  double _importProgress = 0.0;

  // -------------------------------------------------------
  // Import handlers
  // -------------------------------------------------------
  Future<void> _handleImportSource(_ImportSource source) async {
    switch (source) {
      case _ImportSource.camera:
        context.push('/capture/camera');
      case _ImportSource.pdf:
        await _importFile('pdf');
      case _ImportSource.musicXml:
        await _importFile('musicxml');
      case _ImportSource.image:
        await _importFile('image');
      case _ImportSource.url:
        await _showUrlImportSheet();
    }
  }

  Future<void> _importFile(String fileType) async {
    // In production this uses the file_picker package.
    // The file path returned by the picker is passed to Module B.
    final fakePath = 'sample.$fileType';
    await _runImport(fakePath, fileType);
  }

  Future<void> _showUrlImportSheet() async {
    final controller = TextEditingController();

    // Pre-fill if clipboard contains a URL
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboard = clipboardData?.text ?? '';
    if (_looksLikeUrl(clipboard)) {
      controller.text = clipboard;
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import from URL',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Paste a link to a MusicXML or PDF file (e.g. IMSLP).',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://...',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Import'),
                    onPressed: () {
                      final url = controller.text.trim();
                      if (url.isEmpty) return;
                      Navigator.of(ctx).pop();
                      _runImport(url, 'url');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _runImport(String path, String fileType) async {
    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _importStatusMessage = 'Preparing import...';
    });

    try {
      final library = Provider.of<ScoreLibraryProvider>(context, listen: false);

      // Simulate progress updates while Module B processes the file.
      // In production, Module B would emit progress events.
      final progressTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _importProgress = (_importProgress + 0.04).clamp(0.0, 0.90);
          _importStatusMessage = _progressMessage(_importProgress, fileType);
        });
      });

      bool success = false;
      String? newScoreId;

      if (fileType == 'pdf') {
        final result = await library.moduleB?.importPdf(path);
        if (result?.isSuccess ?? false) {
          newScoreId = result!.valueOrNull!.id;
          success = true;
        }
      } else if (fileType == 'musicxml') {
        final result = await library.moduleB?.importMusicXml(path);
        if (result?.isSuccess ?? false) {
          newScoreId = result!.valueOrNull!.id;
          success = true;
        }
      } else if (fileType == 'image') {
        final bytes = <int>[];
        final fileName = path.split('/').last;
        final result = await library.moduleB?.importImage(bytes, fileName);
        if (result?.isSuccess ?? false) {
          newScoreId = result!.valueOrNull!.id;
          success = true;
        }
      } else if (fileType == 'url') {
        // URL import: detect type from URL and call appropriate Module B method
        if (path.endsWith('.xml') || path.endsWith('.mxl') || path.contains('musicxml')) {
          final result = await library.moduleB?.importMusicXml(path);
          if (result?.isSuccess ?? false) {
            newScoreId = result!.valueOrNull!.id;
            success = true;
          }
        } else {
          // Default to PDF for URLs
          final result = await library.moduleB?.importPdf(path);
          if (result?.isSuccess ?? false) {
            newScoreId = result!.valueOrNull!.id;
            success = true;
          }
        }
      }

      progressTimer.cancel();

      if (!mounted) return;

      setState(() {
        _importProgress = 1.0;
        _isImporting = false;
      });

      if (success && newScoreId != null) {
        await library.loadLibrary();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Score imported successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/viewer/$newScoreId');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${library.lastError ?? "Unknown error"}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // -------------------------------------------------------
  // Helpers
  // -------------------------------------------------------
  bool _looksLikeUrl(String text) {
    return text.startsWith('http://') || text.startsWith('https://');
  }

  String _progressMessage(double progress, String fileType) {
    if (progress < 0.2) return 'Reading file...';
    if (progress < 0.5) {
      return fileType == 'pdf'
          ? 'Extracting pages...'
          : fileType == 'image'
              ? 'Preparing image...'
              : 'Parsing MusicXML...';
    }
    if (progress < 0.8) return 'Processing score...';
    return 'Finalizing...';
  }

  // -------------------------------------------------------
  // Build
  // -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isImporting) {
      return _buildImportingScreen(context);
    }
    return _buildIdleScreen(context);
  }

  Widget _buildImportingScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importing...'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.upload_file_outlined,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _importStatusMessage,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: _importProgress,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_importProgress * 100).round()}%',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => setState(() => _isImporting = false),
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdleScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
          tooltip: 'Close',
        ),
        title: const Text('Import Score'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section: Capture
              _SectionHeader(label: 'Capture'),
              const SizedBox(height: 8),
              _CameraCard(
                onTap: () => _handleImportSource(_ImportSource.camera),
              ),

              const SizedBox(height: 24),
              // Section: From Files
              _SectionHeader(label: 'From Files'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ImportOptionCard(
                      icon: Icons.picture_as_pdf,
                      iconColor: AppTheme.sourcePdf,
                      title: 'PDF',
                      subtitle: 'Import a PDF score',
                      onTap: () => _handleImportSource(_ImportSource.pdf),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImportOptionCard(
                      icon: Icons.music_note,
                      iconColor: AppTheme.sourceMusicXml,
                      title: 'MusicXML',
                      subtitle: '.xml or .mxl',
                      onTap: () => _handleImportSource(_ImportSource.musicXml),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImportOptionCard(
                      icon: Icons.image_outlined,
                      iconColor: AppTheme.sourceImage,
                      title: 'Image',
                      subtitle: 'JPG, PNG, TIFF',
                      onTap: () => _handleImportSource(_ImportSource.image),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              // Section: From Web
              _SectionHeader(label: 'From Web'),
              const SizedBox(height: 8),
              _UrlImportCard(
                onTap: () => _handleImportSource(_ImportSource.url),
              ),

              const SizedBox(height: 32),
              // Section: Recent imports (placeholder)
              _RecentImportsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Section header
// ============================================================
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
    );
  }
}

// ============================================================
// Camera card — large, prominent
// ============================================================
class _CameraCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CameraCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer,
                scheme.primary.withValues(alpha: 0.15),
              ],
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 36,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan with Camera',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Photograph printed music\nAuto-crop and deskew included',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Generic import option card (compact, used in row of 3)
// ============================================================
class _ImportOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImportOptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// URL import card
// ============================================================
class _UrlImportCard extends StatefulWidget {
  final VoidCallback onTap;
  const _UrlImportCard({required this.onTap});

  @override
  State<_UrlImportCard> createState() => _UrlImportCardState();
}

class _UrlImportCardState extends State<_UrlImportCard> {
  bool _hasClipboardUrl = false;
  String _clipboardUrl = '';

  @override
  void initState() {
    super.initState();
    _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.startsWith('http://') || text.startsWith('https://')) {
      if (mounted) {
        setState(() {
          _hasClipboardUrl = true;
          _clipboardUrl = text.length > 50 ? '${text.substring(0, 47)}...' : text;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.link,
                  color: scheme.secondary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Import from URL',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'IMSLP or any direct link to a score file',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_hasClipboardUrl) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.content_paste,
                              size: 12,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _clipboardUrl,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Recent imports section (stub)
// ============================================================
class _RecentImportsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // In production this reads from ScoreLibraryProvider.allScores[:5]
    return Consumer<ScoreLibraryProvider>(
      builder: (context, library, _) {
        final recent = library.allScores.take(3).toList();
        if (recent.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: 'Recent Imports'),
            const SizedBox(height: 8),
            ...recent.map((score) => _RecentImportTile(score: score)),
          ],
        );
      },
    );
  }
}

class _RecentImportTile extends StatelessWidget {
  final Map<String, dynamic> score;
  const _RecentImportTile({required this.score});

  @override
  Widget build(BuildContext context) {
    final sourceType =
        (score['sourceType'] ?? '').toString().toLowerCase();
    final iconColor = _sourceColor(sourceType);
    final icon = _sourceIcon(sourceType);
    final dateImported = score['dateImported'] != null
        ? DateTime.tryParse(score['dateImported'])
        : null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        score['title'] ?? 'Unknown',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        dateImported != null ? _relativeDate(dateImported) : '',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () {
        context.go('/viewer/${score['id']}');
      },
    );
  }
}

// ============================================================
// Shared helpers (duplicated from home_screen; could be extracted)
// ============================================================
IconData _sourceIcon(String sourceType) {
  if (sourceType.contains('pdf')) return Icons.picture_as_pdf;
  if (sourceType.contains('musicxml') || sourceType.contains('xml')) {
    return Icons.music_note;
  }
  if (sourceType.contains('image')) return Icons.image;
  return Icons.description;
}

Color _sourceColor(String sourceType) {
  if (sourceType.contains('pdf')) return AppTheme.sourcePdf;
  if (sourceType.contains('musicxml') || sourceType.contains('xml')) {
    return AppTheme.sourceMusicXml;
  }
  if (sourceType.contains('image')) return AppTheme.sourceImage;
  return const Color(0xFF72787E);
}

String _relativeDate(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 60) return 'Just now';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.month}/${date.day}/${date.year}';
}
