import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../demo_data.dart';

const String _omrServerUrl = '';

/// A single search result from IMSLP.
class ImslpResult {
  final String title;
  final String pageTitle;
  final String snippet;

  const ImslpResult({
    required this.title,
    required this.pageTitle,
    required this.snippet,
  });

  factory ImslpResult.fromJson(Map<String, dynamic> json) {
    return ImslpResult(
      title: json['title'] as String? ?? '',
      pageTitle: json['title'] as String? ?? '',
      snippet: _stripHtml(json['snippet'] as String? ?? ''),
    );
  }

  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}

/// A downloadable file entry parsed from an IMSLP page.
class ImslpFile {
  final String label;
  final String url;
  final String fileType; // 'musicxml', 'pdf', 'midi', 'other'
  final String wikiUrl;  // fallback wiki page URL

  const ImslpFile({
    required this.label,
    required this.url,
    required this.fileType,
    required this.wikiUrl,
  });
}

/// IMSLP browse and download screen.
class ImslpScreen extends StatefulWidget {
  const ImslpScreen({super.key});

  @override
  State<ImslpScreen> createState() => _ImslpScreenState();
}

class _ImslpScreenState extends State<ImslpScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<ImslpResult> _results = [];
  bool _searching = false;
  String _searchError = '';
  String _lastQuery = '';

  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty || q == _lastQuery) return;
    _lastQuery = q;

    setState(() {
      _searching = true;
      _searchError = '';
      _results = [];
    });

    try {
      final encodedQuery = Uri.encodeQueryComponent(q);
      final url = '$_omrServerUrl/imslp/search?q=$encodedQuery';

      final request = html.HttpRequest();
      request.open('GET', url);
      request.setRequestHeader('Accept', 'application/json');

      final completer = Completer<void>();
      request.onLoad.listen((_) => completer.complete());
      request.onError.listen((_) => completer.completeError('Network error'));
      request.send();

      await completer.future;

      if (request.status == 200) {
        final data = jsonDecode(request.responseText ?? '{}');
        final rawResults = data['results'] as List<dynamic>? ?? [];
        final results = rawResults
            .map((e) => ImslpResult.fromJson(e as Map<String, dynamic>))
            .where((r) => r.title.isNotEmpty)
            .toList();

        if (mounted) {
          setState(() {
            _results = results;
            _searching = false;
          });
        }
      } else {
        throw Exception('Server returned ${request.status}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _searchError = 'Search failed: $e';
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().length >= 3) {
      _debounceTimer = Timer(const Duration(milliseconds: 600), () {
        _search(value);
      });
    }
  }

  void _onSearchSubmit(String value) {
    _debounceTimer?.cancel();
    _search(value);
  }

  void _openPage(ImslpResult result) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImslpPageDetail(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: Row(
          children: [
            Icon(Icons.library_music, color: colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Browse IMSLP',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(colorScheme),
            Expanded(child: _buildBody(colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: 'Search composer, title, instrument...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _results = [];
                      _searchError = '';
                      _lastQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        onSubmitted: _onSearchSubmit,
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchError.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _searchError,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _search(_searchController.text),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty && _lastQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No results for "$_lastQuery"',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              '210,000+ free scores',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search the IMSLP public domain library',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _results.length,
      itemBuilder: (ctx, i) => _ResultCard(
        result: _results[i],
        onTap: () => _openPage(_results[i]),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ImslpResult result;
  final VoidCallback onTap;

  const _ResultCard({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.music_note,
                  color: colorScheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.snippet.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.snippet,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail page showing files for an IMSLP page entry.
class _ImslpPageDetail extends StatefulWidget {
  final ImslpResult result;

  const _ImslpPageDetail({required this.result});

  @override
  State<_ImslpPageDetail> createState() => _ImslpPageDetailState();
}

class _ImslpPageDetailState extends State<_ImslpPageDetail> {
  List<ImslpFile> _files = [];
  bool _loading = true;
  String _loadError = '';

  @override
  void initState() {
    super.initState();
    _loadPageFiles();
  }

  String get _wikiUrl {
    return 'https://imslp.org/wiki/${Uri.encodeComponent(widget.result.pageTitle)}';
  }

  Future<void> _loadPageFiles() async {
    setState(() {
      _loading = true;
      _loadError = '';
    });

    try {
      final encodedTitle = Uri.encodeQueryComponent(widget.result.pageTitle);
      final url = '$_omrServerUrl/imslp/page?title=$encodedTitle';

      final request = html.HttpRequest();
      request.open('GET', url);
      request.setRequestHeader('Accept', 'application/json');

      final completer = Completer<void>();
      request.onLoad.listen((_) => completer.complete());
      request.onError.listen((_) => completer.completeError('Network error'));
      request.send();

      await completer.future;

      if (request.status == 200) {
        final data = jsonDecode(request.responseText ?? '{}');
        final rawFiles = data['files'] as List<dynamic>? ?? [];
        final files = rawFiles.map((e) {
          final m = e as Map<String, dynamic>;
          final fileUrl = m['url'] as String? ?? '';
          final label = m['label'] as String? ?? fileUrl;
          // Prefer server-provided type field; fall back to URL extension
          String fileType = m['type'] as String? ?? '';
          if (fileType.isEmpty) {
            final ext = fileUrl.toLowerCase();
            if (ext.contains('.xml') ||
                ext.contains('musicxml') ||
                ext.contains('.mxl')) {
              fileType = 'musicxml';
            } else if (ext.contains('.pdf')) {
              fileType = 'pdf';
            } else if (ext.contains('.mid')) {
              fileType = 'midi';
            } else {
              fileType = 'other';
            }
          }
          return ImslpFile(
            label: label,
            url: fileUrl,
            fileType: fileType,
            wikiUrl: _wikiUrl,
          );
        }).toList();

        // Sort: MusicXML first, then PDF, then MIDI, then others
        files.sort((a, b) {
          const order = {'musicxml': 0, 'pdf': 1, 'midi': 2, 'other': 3};
          return (order[a.fileType] ?? 3).compareTo(order[b.fileType] ?? 3);
        });

        if (mounted) {
          setState(() {
            _files = files;
            _loading = false;
          });
        }
      } else {
        throw Exception('Server returned ${request.status}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Failed to load files: $e';
        });
      }
    }
  }

  /// Show a centered loading dialog with a progress message.
  Future<T?> _withLoadingDialog<T>({
    required String message,
    required Future<T> Function() task,
  }) async {
    if (!mounted) return null;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LoadingDialog(message: message),
    );

    try {
      final result = await task();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      return result;
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      rethrow;
    }
  }

  /// One-tap handler: auto-detect type and process.
  Future<void> _openFile(ImslpFile file) async {
    switch (file.fileType) {
      case 'musicxml':
        await _openMusicXml(file);
      default:
        _openWikiPage(file);
    }
  }

  void _openWikiPage(ImslpFile file) {
    final url = file.wikiUrl.isNotEmpty ? file.wikiUrl : _wikiUrl;
    html.window.open(url, '_blank');
  }

  Future<void> _openMusicXml(ImslpFile file) async {
    if (file.url.isEmpty) {
      _openWikiPage(file);
      return;
    }

    try {
      final xmlContent = await _withLoadingDialog(
        message: 'Importing score...',
        task: () => _downloadMusicXml(file.url),
      );

      if (xmlContent == null || !mounted) return;

      final scoreId = DemoData.addImported(widget.result.title, xmlContent);
      context.go('/viewer/$scoreId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<String> _downloadMusicXml(String fileUrl) async {
    final proxyUrl =
        '$_omrServerUrl/imslp/download?url=${Uri.encodeQueryComponent(fileUrl)}';

    final request = html.HttpRequest();
    request.open('GET', proxyUrl);

    final completer = Completer<void>();
    request.onLoad.listen((_) => completer.complete());
    request.onError.listen((_) => completer.completeError('Download failed'));
    request.send();

    await completer.future;

    if (request.status != 200) {
      throw Exception('Download failed: ${request.status}');
    }

    final xmlContent = request.responseText ?? '';
    final isXml = xmlContent.trimLeft().startsWith('<?xml') ||
        xmlContent.trimLeft().startsWith('<score-partwise') ||
        xmlContent.trimLeft().startsWith('<score-timewise');

    if (!isXml) {
      throw Exception('Downloaded file is not valid MusicXML');
    }

    return xmlContent;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.result.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: _buildBody(colorScheme),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _loadError,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadPageFiles,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No downloadable files found',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => html.window.open(_wikiUrl, '_blank'),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open on IMSLP'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Available files — tap to open',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        ..._files.map(
          (file) => _FileCard(
            file: file,
            onTap: () => _openFile(file),
          ),
        ),
      ],
    );
  }
}

/// Centered loading dialog with a spinner and a progress message.
class _LoadingDialog extends StatelessWidget {
  final String message;

  const _LoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final ImslpFile file;
  final VoidCallback onTap;

  const _FileCard({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMusicXml = file.fileType == 'musicxml';
    final isPdf = file.fileType == 'pdf';
    final isMidi = file.fileType == 'midi';

    final IconData iconData;
    final Color iconColor;
    final Color badgeColor;
    if (isMusicXml) {
      iconData = Icons.description;
      iconColor = colorScheme.primary;
      badgeColor = colorScheme.primaryContainer;
    } else if (isPdf) {
      iconData = Icons.picture_as_pdf;
      iconColor = Colors.red.shade600;
      badgeColor = Colors.red.shade50;
    } else if (isMidi) {
      iconData = Icons.music_note;
      iconColor = Colors.green.shade700;
      badgeColor = Colors.green.shade50;
    } else {
      iconData = Icons.insert_drive_file;
      iconColor = Colors.grey.shade600;
      badgeColor = Colors.grey.shade100;
    }

    final String badgeLabel;
    if (isMusicXml) {
      badgeLabel = 'MUSICXML';
    } else if (isPdf) {
      badgeLabel = 'PDF';
    } else if (isMidi) {
      badgeLabel = 'MIDI';
    } else {
      badgeLabel = file.fileType.toUpperCase();
    }

    final String actionHint;
    if (isMusicXml) {
      actionHint = 'Tap to import & render';
    } else {
      actionHint = 'Tap to open on IMSLP';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      actionHint,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isMusicXml ? Icons.chevron_right : Icons.open_in_new,
                color: isMusicXml ? colorScheme.primary : Colors.grey.shade400,
                size: isMusicXml ? 24 : 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
