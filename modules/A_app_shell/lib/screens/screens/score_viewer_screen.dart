import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/score_library_provider.dart';
import '../state/score_renderer_provider.dart';
import '../state/ui_state_provider.dart';
import '../state/device_provider.dart';
import '../widgets/page_indicator.dart';

class ScoreViewerScreen extends StatefulWidget {
  final String scoreId;

  const ScoreViewerScreen({
    required this.scoreId,
    Key? key,
  }) : super(key: key);

  @override
  State<ScoreViewerScreen> createState() => _ScoreViewerScreenState();
}

class _ScoreViewerScreenState extends State<ScoreViewerScreen> {
  bool _showDebugOverlay = false;
  bool _isFullscreen = false;
  Map<String, dynamic>? _scoreData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScore();
  }

  Future<void> _loadScore() async {
    final library = Provider.of<ScoreLibraryProvider>(context, listen: false);
    final scoreData = await library.getScore(widget.scoreId);

    if (!mounted) return;

    setState(() {
      _scoreData = scoreData;
      _isLoading = false;
    });

    // Initialize device provider
    if (mounted) {
      Provider.of<DeviceProvider>(context, listen: false).initialize();
    }
  }

  void _nextPage() {
    if (_scoreData != null) {
      final renderer =
          Provider.of<ScoreRendererProvider>(context, listen: false);
      final layoutConfig =
          Provider.of<UIStateProvider>(context, listen: false)
              .getLayoutConfig();
      renderer.nextPage(_scoreData!['scoreJson'] ?? {}, layoutConfig.toJson());
    }
  }

  void _previousPage() {
    if (_scoreData != null) {
      final renderer =
          Provider.of<ScoreRendererProvider>(context, listen: false);
      final layoutConfig =
          Provider.of<UIStateProvider>(context, listen: false)
              .getLayoutConfig();
      renderer.previousPage(_scoreData!['scoreJson'] ?? {}, layoutConfig.toJson());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_scoreData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Score Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Score not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer2<ScoreRendererProvider, UIStateProvider>(
      builder: (context, renderer, uiState, _) {
        return Scaffold(
          appBar: _isFullscreen
              ? null
              : AppBar(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_scoreData!['title'] ?? 'Unknown Score'),
                      if (_scoreData!['composer'] != null &&
                          (_scoreData!['composer'] as String).isNotEmpty)
                        Text(
                          _scoreData!['composer'],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  elevation: 2,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.fullscreen),
                      onPressed: () {
                        setState(() => _isFullscreen = !_isFullscreen);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.bug_report),
                      onPressed: () {
                        setState(() => _showDebugOverlay = !_showDebugOverlay);
                      },
                    ),
                  ],
                ),
          body: GestureDetector(
            onTapDown: (details) => _handleTap(details.globalPosition),
            onHorizontalDragEnd: (details) => _handleSwipe(details),
            child: Stack(
              children: [
                // Main score viewer canvas
                Container(
                  color: Colors.white,
                  child: Center(
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 800,
                          height: 1100,
                          child: _buildScoreCanvas(renderer),
                        ),
                      ),
                    ),
                  ),
                ),

                // Page indicators
                if (!_isFullscreen)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: _buildPageIndicator(renderer),
                  ),

                // Debug overlay
                if (_showDebugOverlay)
                  Positioned(
                    top: 80,
                    right: 10,
                    child: _buildDebugOverlay(renderer),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: _isFullscreen
              ? null
              : BottomAppBar(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: renderer.currentPage > 0 ? _previousPage : null,
                      ),
                      Text(
                        'Page ${renderer.currentPage + 1} of ${renderer.totalPages}',
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: renderer.currentPage < renderer.totalPages - 1
                            ? _nextPage
                            : null,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildScoreCanvas(ScoreRendererProvider renderer) {
    // Placeholder canvas for score rendering
    // In production, this would use Module F's ScorePainter
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Page ${renderer.currentPage + 1}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Score rendering (Module F)\nPlaceholder for ScorePainter',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(ScoreRendererProvider renderer) {
    return PageIndicator(
      currentPage: renderer.currentPage,
      totalPages: renderer.totalPages,
      onPageChanged: (page) {
        // Page change would trigger re-render via Module F
      },
    );
  }

  Widget _buildDebugOverlay(ScoreRendererProvider renderer) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Debug Info',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Text('Current Page: ${renderer.currentPage}'),
              Text('Total Pages: ${renderer.totalPages}'),
              Text('Is Rendering: ${renderer.isRendering}'),
              if (renderer.lastError != null)
                Text('Error: ${renderer.lastError}'),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(Offset position) {
    // Tap on left/right 15% zones for page navigation
    final screenWidth = MediaQuery.of(context).size.width;
    final leftZone = screenWidth * 0.15;
    final rightZone = screenWidth * 0.85;

    if (position.dx < leftZone) {
      _previousPage();
    } else if (position.dx > rightZone) {
      _nextPage();
    }
  }

  void _handleSwipe(DragEndDetails details) {
    // Swipe left/right for page navigation
    if (details.velocity.pixelsPerSecond.dx > 300) {
      // Swipe right = previous page
      _previousPage();
    } else if (details.velocity.pixelsPerSecond.dx < -300) {
      // Swipe left = next page
      _nextPage();
    }
  }
}
