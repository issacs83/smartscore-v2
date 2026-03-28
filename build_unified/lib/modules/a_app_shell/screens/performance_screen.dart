import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../demo_data.dart';
import '../../../modules/g_audio_engine/models.dart';
import '../../../modules/h_follow_controller/follow_controller.dart';
import '../../../modules/h_follow_controller/models.dart';
import 'verovio_js_interop.dart' if (dart.library.html) 'verovio_js_interop_web.dart';

/// Performance mode — fullscreen score with audio following + auto page turn.
///
/// Designed for hands-free operation during piano performance.
class PerformanceScreen extends StatefulWidget {
  final String scoreId;
  const PerformanceScreen({required this.scoreId, super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final FollowController _controller = FollowController();
  bool _loading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _svgContent;
  bool _referenceLoaded = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onFollowUpdate);
    _controller.onPageTurn = _onPageTurn;
    _loadScore();
  }

  @override
  void dispose() {
    _controller.removeListener(_onFollowUpdate);
    _controller.dispose();
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

    // Load score into Verovio
    if (kIsWeb) {
      for (int i = 0; i < 60; i++) {
        if (verovioIsReady()) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      try {
        final svg = verovioLoadScore(xml);
        final pages = verovioGetPageCount();
        if (svg != null && svg.contains('<svg')) {
          setState(() {
            _svgContent = svg;
            _totalPages = pages;
            _loading = false;
          });
        } else {
          setState(() {
            _error = 'Score rendering failed';
            _loading = false;
          });
          return;
        }
      } catch (e) {
        setState(() {
          _error = 'Render error: $e';
          _loading = false;
        });
        return;
      }
    }

    // Load reference features for score following
    _loadReferenceFeatures(xml);
  }

  Future<void> _loadReferenceFeatures(String xml) async {
    if (!kIsWeb) return;

    try {
      final request = html.HttpRequest();
      request.open('POST', '/score/timing-map');
      request.timeout = 30000;
      request.setRequestHeader('Content-Type', 'application/json');
      request.send(jsonEncode({'musicxml': xml, 'tempo_bpm': 120}));
      await request.onLoad.first;

      if (request.status == 200) {
        final resp = jsonDecode(request.responseText ?? '{}');
        if (resp['success'] == true) {
          final measures = resp['measures'] as List;
          // Build measure-to-page mapping (simple: divide evenly)
          final measuresPerPage = (measures.length / _totalPages).ceil();
          final measureToPage = <int, int>{};
          for (int i = 0; i < measures.length; i++) {
            final m = measures[i];
            measureToPage[m['number'] as int] = i ~/ measuresPerPage;
          }

          // For now, use timing map as a simple reference
          // Full CENS reference would come from /score/reference-features
          // but that requires audio synthesis (FluidSynth)
          // Use a placeholder that enables the UI flow
          final frames = measures.map((m) {
            return ReferenceFrame(
              index: (m['number'] as int) - 1,
              timeSec: (m['start_sec'] as num).toDouble(),
              measure: m['number'] as int,
              beat: 1.0,
              chroma: ChromaVector(List.filled(12, 0.0)),
            );
          }).toList();

          _controller.loadReference(
            frames,
            totalMeasures: measures.length,
            totalPages: _totalPages,
            measureToPage: measureToPage,
          );

          setState(() => _referenceLoaded = true);
          debugPrint('[Performance] Reference loaded: ${measures.length} measures');
        }
      }
    } catch (e) {
      debugPrint('[Performance] Reference load failed: $e');
    }
  }

  void _onFollowUpdate() {
    if (mounted) setState(() {});
  }

  void _onPageTurn(PageTurnEvent event) {
    if (!mounted) return;
    _goToPage(event.toPage + 1); // 0-indexed → 1-indexed
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    if (kIsWeb) {
      try {
        final svg = verovioRenderPage(page);
        setState(() {
          _svgContent = svg;
          _currentPage = page;
        });
      } catch (e) {
        debugPrint('Page render error: $e');
      }
    }
  }

  Future<void> _toggleFollowing() async {
    if (_controller.isFollowing) {
      _controller.stop();
    } else {
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Score display (fullscreen)
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              )
            else if (_svgContent != null && kIsWeb)
              GestureDetector(
                onTap: () {
                  // Tap to toggle toolbar visibility or manual position
                },
                child: renderSvgWidget(_svgContent!),
              )
            else
              const Center(child: Text('No content')),

            // Top bar (minimal, transparent)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        _controller.stop();
                        context.go('/viewer/${widget.scoreId}');
                      },
                    ),
                    const Spacer(),
                    // Measure indicator
                    if (_controller.isFollowing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'M${_controller.currentMeasure}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Page indicator
                    Text(
                      '$_currentPage / $_totalPages',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom toolbar (floating)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildToolbar(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(ColorScheme colorScheme) {
    final isFollowing = _controller.isFollowing;
    final state = _controller.state;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // VU meter
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _controller.audioLevel.clamp(0, 1),
                  strokeWidth: 3,
                  color: _controller.audioLevel > 0.5
                      ? Colors.green
                      : Colors.grey.shade300,
                ),
                Icon(
                  Icons.mic,
                  size: 20,
                  color: isFollowing ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ),

          // Start/Stop button
          SizedBox(
            width: 56,
            height: 56,
            child: FloatingActionButton(
              onPressed: _referenceLoaded ? _toggleFollowing : null,
              backgroundColor: isFollowing
                  ? Colors.red
                  : (_referenceLoaded ? colorScheme.primary : Colors.grey),
              child: Icon(
                isFollowing ? Icons.stop : Icons.play_arrow,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),

          // Confidence indicator
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state == FollowState.following
                    ? '${(_controller.confidence * 100).round()}%'
                    : state == FollowState.loading
                        ? '...'
                        : state == FollowState.error
                            ? 'ERR'
                            : 'READY',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _confidenceColor(),
                ),
              ),
              Text(
                'confidence',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),

          // Page navigation
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () => _goToPage(_currentPage - 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () => _goToPage(_currentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _confidenceColor() {
    final conf = _controller.confidence;
    if (!_controller.isFollowing) return Colors.grey;
    if (conf > 0.7) return Colors.green;
    if (conf > 0.4) return Colors.orange;
    return Colors.red;
  }
}
