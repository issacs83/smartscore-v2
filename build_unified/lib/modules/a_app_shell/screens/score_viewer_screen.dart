import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';

import '../../../demo_data.dart';
import 'verovio_js_interop.dart' if (dart.library.html) 'verovio_js_interop_web.dart';

/// Score viewer backed by the Verovio WASM engraving engine.
class ScoreViewerScreen extends StatefulWidget {
  final String scoreId;
  const ScoreViewerScreen({required this.scoreId, super.key});

  @override
  State<ScoreViewerScreen> createState() => _ScoreViewerScreenState();
}

class _ScoreViewerScreenState extends State<ScoreViewerScreen> {
  String? _svgContent;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _loading = true;
  String? _error;

  // Playback state
  bool _isPlaying = false;
  double _tempo = 120.0;
  Timer? _playbackStateTimer;

  @override
  void initState() {
    super.initState();
    _loadScore();
  }

  @override
  void dispose() {
    _playbackStateTimer?.cancel();
    if (kIsWeb) verovioStop();
    super.dispose();
  }

  Future<void> _loadScore() async {
    final xml = DemoData.getXml(widget.scoreId);
    if (xml == null) {
      setState(() {
        _error = 'Score not found';
        _loading = false;
      });
      return;
    }

    // Wait for Verovio to be ready (retry up to 60 times, 500ms each = 30s max)
    for (int i = 0; i < 60; i++) {
      if (verovioIsReady()) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!verovioIsReady()) {
      setState(() {
        _error = 'Verovio engine failed to load';
        _loading = false;
      });
      return;
    }

    try {
      final svg = verovioLoadScore(xml);
      final pages = verovioGetPageCount();
      setState(() {
        _svgContent = svg;
        _totalPages = pages;
        _currentPage = 1;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Render error: $e';
        _loading = false;
      });
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    final svg = verovioRenderPage(page);
    setState(() {
      _svgContent = svg;
      _currentPage = page;
    });
  }

  void _onPlayPause() {
    if (!kIsWeb) return;
    if (_isPlaying) {
      verovioPause();
      _playbackStateTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      verovioSetTempo(_tempo.round());
      verovioPlay();
      setState(() => _isPlaying = true);
      // Wait for async JS play to start, then poll for natural stop
      _playbackStateTimer?.cancel();
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted || !_isPlaying) return;
        _playbackStateTimer = Timer.periodic(
          const Duration(milliseconds: 500),
          (_) {
            if (!mounted) return;
            final state = verovioGetPlaybackState();
            if (state == 'stopped') {
              setState(() => _isPlaying = false);
              _playbackStateTimer?.cancel();
            }
          },
        );
      });
    }
  }

  void _onStop() {
    if (!kIsWeb) return;
    verovioStop();
    _playbackStateTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _onTempoChanged(double value) {
    setState(() => _tempo = value);
    if (kIsWeb) verovioSetTempo(value.round());
  }

  @override
  Widget build(BuildContext context) {
    final title = DemoData.getTitle(widget.scoreId);

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
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading music engraving engine...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    if (_svgContent == null || _svgContent!.isEmpty) {
      return const Center(child: Text('No content to display'));
    }

    return Column(
      children: [
        Expanded(child: _buildSvgViewer()),
        _buildPageIndicator(),
        if (kIsWeb) _buildPlaybackBar(),
      ],
    );
  }

  Widget _buildSvgViewer() {
    if (kIsWeb) {
      return _WebSvgViewer(svgContent: _svgContent!);
    }
    // Fallback for non-web: show raw SVG text (placeholder)
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_svgContent!, style: const TextStyle(fontSize: 8)),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
          ),
          const SizedBox(width: 8),
          Text(
            '$_currentPage / $_totalPages',
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () => _goToPage(_currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Play / Pause
          IconButton(
            tooltip: _isPlaying ? 'Pause' : 'Play',
            icon: Icon(
              _isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              size: 36,
              color: colorScheme.primary,
            ),
            onPressed: _onPlayPause,
          ),
          // Stop
          IconButton(
            tooltip: 'Stop',
            icon: Icon(
              Icons.stop_circle_outlined,
              size: 36,
              color: colorScheme.primary,
            ),
            onPressed: _isPlaying ? _onStop : null,
          ),
          const SizedBox(width: 8),
          // Tempo label
          Text(
            '${_tempo.round()} BPM',
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          // Tempo slider (60–200 BPM, 28 steps of 5)
          Expanded(
            child: Slider(
              min: 60,
              max: 200,
              divisions: 28,
              value: _tempo,
              label: '${_tempo.round()}',
              onChanged: _onTempoChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Web-only: renders SVG string as an HtmlElementView widget.
class _WebSvgViewer extends StatelessWidget {
  final String svgContent;
  const _WebSvgViewer({required this.svgContent});

  @override
  Widget build(BuildContext context) {
    return renderSvgWidget(svgContent);
  }
}
