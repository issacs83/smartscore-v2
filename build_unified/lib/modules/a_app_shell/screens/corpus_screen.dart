import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../demo_data.dart';

const String _omrServerUrl = '';

/// A single search result from the music21 corpus.
class CorpusResult {
  final String id;
  final String title;
  final String composer;
  final int parts;

  const CorpusResult({
    required this.id,
    required this.title,
    required this.composer,
    required this.parts,
  });

  factory CorpusResult.fromJson(Map<String, dynamic> json) {
    return CorpusResult(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      composer: json['composer'] as String? ?? '',
      parts: json['parts'] as int? ?? 0,
    );
  }
}

/// Browse and import scores from the music21 built-in corpus (15,026 scores).
class CorpusScreen extends StatefulWidget {
  const CorpusScreen({super.key});

  @override
  State<CorpusScreen> createState() => _CorpusScreenState();
}

class _CorpusScreenState extends State<CorpusScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<CorpusResult> _results = [];
  bool _searching = false;
  String _searchError = '';
  String _lastQuery = '';
  String _selectedCategory = 'All';

  Timer? _debounceTimer;

  static const List<String> _categories = [
    'All',
    'Bach',
    'Beethoven',
    'Mozart',
    'Classical',
    'Monteverdi',
    'Haydn',
  ];

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
      final url = '$_omrServerUrl/corpus/search?q=$encodedQuery';

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
            .map((e) => CorpusResult.fromJson(e as Map<String, dynamic>))
            .where((r) => r.id.isNotEmpty)
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
          _searchError = 'Search failed: $e\n\nMake sure the OMR server is running.';
        });
      }
    }
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    final query = category == 'All' ? 'bach' : category.toLowerCase();
    _searchController.text = category == 'All' ? '' : category;
    _lastQuery = '';
    _search(query);
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 600), () {
        _search(value);
      });
    }
  }

  void _onSearchSubmit(String value) {
    _debounceTimer?.cancel();
    _search(value);
  }

  String _exportMessage = '';
  double _exportProgress = 0;
  void Function(void Function())? _exportDialogSetState;

  Future<void> _importScore(CorpusResult result) async {
    if (!mounted) return;

    _exportMessage = 'Preparing...';
    _exportProgress = 0;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          _exportDialogSetState = setDialogState;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  width: 56, height: 56,
                  child: CircularProgressIndicator(
                    value: _exportProgress > 0 ? _exportProgress : null,
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 20),
                Text(_exportMessage, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _exportProgress),
                const SizedBox(height: 4),
                Text('${(_exportProgress * 100).round()}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          );
        },
      ),
    );

    void updateProgress(String msg, double pct) {
      _exportMessage = msg;
      _exportProgress = pct;
      _exportDialogSetState?.call(() {});
    }

    try {
      updateProgress('Parsing score...', 0.1);
      final encodedId = Uri.encodeQueryComponent(result.id);
      final url = '$_omrServerUrl/corpus/export?id=$encodedId';

      updateProgress('Exporting MusicXML...', 0.2);

      final request = html.HttpRequest();
      request.open('GET', url);
      request.setRequestHeader('Accept', 'application/json');

      // Progress simulation
      final progressTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_exportProgress < 0.85) {
          final step = _exportProgress < 0.4 ? 'Converting to LilyPond...'
              : _exportProgress < 0.6 ? 'Rendering notation...'
              : _exportProgress < 0.8 ? 'Generating PNG...'
              : 'Almost done...';
          updateProgress(step, _exportProgress + 0.08);
        }
      });

      final completer = Completer<void>();
      request.onLoad.listen((_) => completer.complete());
      request.onError.listen((_) => completer.completeError('Network error'));
      request.send();

      await completer.future;
      progressTimer.cancel();

      updateProgress('Done!', 1.0);
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;
      _exportDialogSetState = null;
      Navigator.of(context, rootNavigator: true).pop();

      if (request.status == 200) {
        final data = jsonDecode(request.responseText ?? '{}');
        if (data['success'] == true && data['musicxml'] != null) {
          final xml = data['musicxml'] as String;
          final title = (data['title'] as String?)?.isNotEmpty == true
              ? data['title'] as String
              : result.title;
          final pngBase64 = data['png_base64'] as String?;
          final scoreId = DemoData.addImported(title, xml, pngBase64: pngBase64);
          if (mounted) {
            context.go('/viewer/$scoreId');
          }
        } else {
          throw Exception(data['error'] ?? 'Export failed');
        }
      } else {
        throw Exception('Server returned ${request.status}');
      }
    } catch (e) {
      _exportDialogSetState = null;
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error'),
          content: Text('$e\n\nTry a smaller score (e.g. Bach BWV chorales).'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    }
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
            Icon(Icons.menu_book, color: colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Browse Library',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colorScheme),
            _buildSearchBar(colorScheme),
            _buildCategoryChips(colorScheme),
            Expanded(child: _buildBody(colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  '15,026 scores',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  '100% accurate MusicXML',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
                      _selectedCategory = 'All';
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

  Widget _buildCategoryChips(ColorScheme colorScheme) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final selected = _selectedCategory == cat;
          return FilterChip(
            label: Text(cat),
            selected: selected,
            onSelected: (_) => _onCategorySelected(cat),
            selectedColor: colorScheme.primaryContainer,
            checkmarkColor: colorScheme.primary,
            labelStyle: TextStyle(
              color: selected ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          );
        },
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
      return _buildWelcomeState(colorScheme);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _results.length,
      itemBuilder: (ctx, i) => _CorpusResultCard(
        result: _results[i],
        onTap: () => _importScore(_results[i]),
      ),
    );
  }

  Widget _buildWelcomeState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, size: 72, color: colorScheme.primary.withOpacity(0.3)),
            const SizedBox(height: 24),
            Text(
              '15,026 built-in scores',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bach, Beethoven, Mozart, and more\nNo OMR — 100% accurate MusicXML',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _QuickSearchButton(
                  label: 'Bach Chorales',
                  onTap: () {
                    _searchController.text = 'bach';
                    _onSearchSubmit('bach');
                  },
                ),
                _QuickSearchButton(
                  label: 'Beethoven',
                  onTap: () {
                    _searchController.text = 'beethoven';
                    _onSearchSubmit('beethoven');
                  },
                ),
                _QuickSearchButton(
                  label: 'Mozart',
                  onTap: () {
                    _searchController.text = 'mozart';
                    _onSearchSubmit('mozart');
                  },
                ),
                _QuickSearchButton(
                  label: 'Palestrina',
                  onTap: () {
                    _searchController.text = 'palestrina';
                    _onSearchSubmit('palestrina');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSearchButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickSearchButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: colorScheme.outline.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _CorpusResultCard extends StatelessWidget {
  final CorpusResult result;
  final VoidCallback onTap;

  const _CorpusResultCard({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayComposer = result.composer.isNotEmpty
        ? result.composer
        : _inferComposer(result.id);

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
                      result.title.isNotEmpty ? result.title : result.id,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (displayComposer.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        displayComposer,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      'Tap to open',
                      style: TextStyle(
                        color: colorScheme.primary.withOpacity(0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.primary, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _inferComposer(String id) {
    final lower = id.toLowerCase();
    if (lower.contains('bach')) return 'J.S. Bach';
    if (lower.contains('beethoven')) return 'L.v. Beethoven';
    if (lower.contains('mozart')) return 'W.A. Mozart';
    if (lower.contains('haydn')) return 'F.J. Haydn';
    if (lower.contains('schubert')) return 'F. Schubert';
    if (lower.contains('handel')) return 'G.F. Handel';
    if (lower.contains('monteverdi')) return 'C. Monteverdi';
    if (lower.contains('palestrina')) return 'G.P. da Palestrina';
    return '';
  }
}

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
