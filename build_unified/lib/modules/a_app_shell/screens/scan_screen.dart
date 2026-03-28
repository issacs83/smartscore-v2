import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../demo_data.dart';

const String _omrServerUrl = '';

/// Multi-page score scan screen.
///
/// UX flow:
/// 1. User taps camera button -> file picker opens with capture='environment'
/// 2. Preview shown with page number
/// 3. User can add more pages or process all
/// 4. All pages sent to POST /omr/multi -> merged MusicXML
/// 5. Navigate to viewer on success
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<_PageEntry> _pages = [];
  bool _processing = false;
  String _loadingMessage = '';
  double _loadingProgress = 0;
  void Function(void Function())? _dialogSetState;

  // ---------------------------------------------------------------------------
  // Camera / file capture
  // ---------------------------------------------------------------------------

  /// Pick multiple images from gallery at once
  Future<void> _pickFromGallery() async {
    if (!kIsWeb) return;

    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;
    input.click();

    await input.onChange.first;

    final files = input.files;
    if (files == null || files.isEmpty) return;

    for (final file in files) {
      final dataUrl = await _readAsDataUrl(file);
      if (dataUrl != null) {
        setState(() {
          _pages.add(_PageEntry(file: file, dataUrl: dataUrl));
        });
      }
    }
  }

  /// Capture a single photo from camera
  Future<void> _captureFromCamera() async {
    if (!kIsWeb) return;

    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..setAttribute('capture', 'environment');
    input.click();

    await input.onChange.first;

    final file = input.files?.first;
    if (file == null) return;

    final dataUrl = await _readAsDataUrl(file);
    if (dataUrl == null) return;

    setState(() {
      _pages.add(_PageEntry(file: file, dataUrl: dataUrl));
    });
  }

  /// Legacy single-pick (kept for compatibility)
  Future<void> _capturePage() async {
    _pickFromGallery();
  }

  Future<String?> _readAsDataUrl(html.File file) async {
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoad.first;
    return reader.result as String?;
  }

  void _removePage(int index) {
    setState(() => _pages.removeAt(index));
  }

  // ---------------------------------------------------------------------------
  // Loading dialog helpers
  // ---------------------------------------------------------------------------

  void _showLoadingDialog(String message) {
    _loadingMessage = message;
    _loadingProgress = 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          _dialogSetState = setDialogState;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _loadingMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_loadingProgress > 0) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _loadingProgress),
                  const SizedBox(height: 4),
                  Text(
                    '${(_loadingProgress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

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

  // ---------------------------------------------------------------------------
  // Processing
  // ---------------------------------------------------------------------------

  Future<void> _processAll() async {
    if (_pages.isEmpty) return;

    setState(() => _processing = true);
    _showLoadingDialog('Preparing ${_pages.length} page(s)...');

    try {
      final formData = html.FormData();
      for (var i = 0; i < _pages.length; i++) {
        formData.appendBlob(
          'image_$i',
          _pages[i].file,
          _pages[i].file.name,
        );
      }

      _updateLoading(
        'Uploading ${_pages.length} page(s) to AI server...',
        0.1,
      );

      final request = html.HttpRequest()
        ..open('POST', '$_omrServerUrl/omr/multi')
        ..timeout = 300000; // 5 minutes timeout for OMR

      var progress = 0.1;
      var elapsed = 0;
      final progressTimer = Timer.periodic(const Duration(seconds: 2), (t) {
        elapsed += 2;
        if (progress < 0.85) {
          progress = (progress + 0.04).clamp(0.0, 0.85);
        }
        final stepMsg = progress < 0.3
            ? 'Detecting staff lines...'
            : progress < 0.5
                ? 'Recognizing notes and symbols...'
                : progress < 0.7
                    ? 'Merging pages...'
                    : 'AI processing... (${elapsed}s elapsed)';
        _updateLoading(stepMsg, progress < 0.85 ? progress : -1);
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
          final pageCount = response['page_count'] as int? ?? _pages.length;
          final pngBase64 = response['png_base64'] as String?;
          final title = 'Scanned Score ($pageCount pages)';
          final scoreId = DemoData.addImported(
            title,
            musicXml,
            pngBase64: pngBase64,
          );

          _updateLoading('Done!', 1.0);
          await Future.delayed(const Duration(milliseconds: 500));
          _closeLoadingDialog();

          if (mounted) {
            setState(() => _processing = false);
            context.go('/viewer/$scoreId');
          }
          return;
        } else {
          throw Exception(response['error'] ?? 'Multi-page OMR failed');
        }
      } else {
        throw Exception('Server error: ${request.status}');
      }
    } catch (e) {
      _closeLoadingDialog();
      if (mounted) {
        setState(() => _processing = false);
        _showErrorDialog('$e\n\nTip: Make sure the OMR server is running.');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Processing Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPages = _pages.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          'Scan Score',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: hasPages
                  ? _PageList(
                      pages: _pages,
                      onRemove: _processing ? null : _removePage,
                    )
                  : _EmptyState(
                      onGallery: _processing ? null : _pickFromGallery,
                      onCamera: _processing ? null : _captureFromCamera,
                    ),
            ),
            _BottomActionBar(
              pageCount: _pages.length,
              processing: _processing,
              onGallery: _pickFromGallery,
              onCamera: _captureFromCamera,
              onProcessAll: _pages.isNotEmpty ? _processAll : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _PageEntry {
  final html.File file;
  final String dataUrl;

  _PageEntry({required this.file, required this.dataUrl});
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onGallery;
  final VoidCallback? onCamera;

  const _EmptyState({this.onGallery, this.onCamera});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.music_note,
              size: 48,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Add score pages',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select images from gallery or take photos',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
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

class _PageList extends StatelessWidget {
  final List<_PageEntry> pages;
  final void Function(int index)? onRemove;

  const _PageList({required this.pages, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: pages.length,
      itemBuilder: (context, index) {
        return _PageTile(
          index: index,
          entry: pages[index],
          onRemove: onRemove != null ? () => onRemove!(index) : null,
        );
      },
    );
  }
}

class _PageTile extends StatelessWidget {
  final int index;
  final _PageEntry entry;
  final VoidCallback? onRemove;

  const _PageTile({
    required this.index,
    required this.entry,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                entry.dataUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Page ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.file.name,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(entry.file.size / 1024).round()} KB',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                tooltip: 'Remove page',
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final int pageCount;
  final bool processing;
  final VoidCallback? onGallery;
  final VoidCallback? onCamera;
  final VoidCallback? onProcessAll;

  const _BottomActionBar({
    required this.pageCount,
    required this.processing,
    this.onGallery,
    this.onCamera,
    this.onProcessAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          if (pageCount > 0) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: processing ? null : onGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: processing ? null : onCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: processing ? null : onProcessAll,
                icon: processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(
                  processing
                      ? 'Processing...'
                      : 'Process All ($pageCount)',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: processing ? null : onGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Select Images'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: processing ? null : onCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
