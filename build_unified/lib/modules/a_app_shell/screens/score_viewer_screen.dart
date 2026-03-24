import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/device_provider.dart';
import '../state/score_library_provider.dart';
import '../state/score_renderer_provider.dart';
import '../state/ui_state_provider.dart';
import '../theme.dart';
import '../../e_music_normalizer/score_json.dart' as score_model;
import '../../f_score_renderer/score_painter.dart';
import '../../k_external_device/device_action.dart';

// ============================================================
// Display mode
// ============================================================
enum _DisplayMode { single, doublePage, scroll }

extension _DisplayModeLabel on _DisplayMode {
  String get label {
    switch (this) {
      case _DisplayMode.single:
        return 'Single Page';
      case _DisplayMode.doublePage:
        return 'Double Page';
      case _DisplayMode.scroll:
        return 'Scroll';
    }
  }

  IconData get icon {
    switch (this) {
      case _DisplayMode.single:
        return Icons.book_outlined;
      case _DisplayMode.doublePage:
        return Icons.menu_book_outlined;
      case _DisplayMode.scroll:
        return Icons.view_agenda_outlined;
    }
  }
}

// ============================================================
// ScoreViewerScreen
// ============================================================
class ScoreViewerScreen extends StatefulWidget {
  final String scoreId;

  const ScoreViewerScreen({
    required this.scoreId,
    super.key,
  });

  @override
  State<ScoreViewerScreen> createState() => _ScoreViewerScreenState();
}

class _ScoreViewerScreenState extends State<ScoreViewerScreen>
    with TickerProviderStateMixin {
  // ---- data ----
  Map<String, dynamic>? _scoreData;
  score_model.Score? _parsedScore;
  bool _isLoading = true;

  // ---- toolbar animation ----
  late final AnimationController _toolbarAnimCtrl;
  late final Animation<double> _toolbarOpacity;
  bool _toolbarsVisible = true;
  Timer? _autoHideTimer;

  // ---- display state ----
  _DisplayMode _displayMode = _DisplayMode.single;
  bool _annotationMode = false;
  bool _isPlaybackBarVisible = false;
  double _tempo = 92.0;
  bool _metronomeOn = false;
  bool _isPlaying = false;

  // ---- device subscription ----
  StreamSubscription<DeviceAction>? _deviceSub;

  @override
  void initState() {
    super.initState();
    _toolbarAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _toolbarOpacity = CurvedAnimation(
      parent: _toolbarAnimCtrl,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScore();
      _initDeviceListener();
      _scheduleAutoHide();
    });
  }

  @override
  void dispose() {
    _toolbarAnimCtrl.dispose();
    _autoHideTimer?.cancel();
    _deviceSub?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------
  // Data loading
  // -------------------------------------------------------
  Future<void> _loadScore() async {
    final library = Provider.of<ScoreLibraryProvider>(context, listen: false);
    final scoreData = await library.getScore(widget.scoreId);

    if (!mounted) return;

    setState(() {
      _scoreData = scoreData;
      _isLoading = false;
    });

    if (scoreData != null) {
      _renderCurrentPage();
    }
  }

  void _renderCurrentPage() {
    final score = _getParsedScore();
    if (score == null) return;
    final renderer =
        Provider.of<ScoreRendererProvider>(context, listen: false);
    final layoutConfig =
        Provider.of<UIStateProvider>(context, listen: false).getLayoutConfig();
    renderer.renderPage(score, 0, renderer.currentPage, layoutConfig);
  }

  score_model.Score? _getParsedScore() {
    if (_parsedScore != null) return _parsedScore;
    if (_scoreData == null) return null;
    try {
      final raw = _scoreData!['scoreJson'];
      if (raw is Map<String, dynamic>) {
        _parsedScore = score_model.Score.fromJson(raw);
      }
    } catch (e) {
      debugPrint('[ScoreViewerScreen] Score parse error: $e');
    }
    return _parsedScore;
  }

  // -------------------------------------------------------
  // Device listener
  // -------------------------------------------------------
  void _initDeviceListener() {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    deviceProvider.initialize();

    // Subscribe to device actions for page turning
    _deviceSub = deviceProvider.onDeviceAction.listen(_handleDeviceAction);
  }

  void _handleDeviceAction(DeviceAction action) {
    switch (action) {
      case DeviceAction.nextPage:
        _nextPage();
      case DeviceAction.previousPage:
        _previousPage();
      default:
        break;
    }
  }

  // -------------------------------------------------------
  // Page navigation
  // -------------------------------------------------------
  void _nextPage() {
    final score = _getParsedScore();
    if (score == null) return;
    final renderer =
        Provider.of<ScoreRendererProvider>(context, listen: false);
    final layoutConfig =
        Provider.of<UIStateProvider>(context, listen: false).getLayoutConfig();
    renderer.nextPage(score, 0, layoutConfig);
    _showToolbarsTemporarily();
  }

  void _previousPage() {
    final score = _getParsedScore();
    if (score == null) return;
    final renderer =
        Provider.of<ScoreRendererProvider>(context, listen: false);
    final layoutConfig =
        Provider.of<UIStateProvider>(context, listen: false).getLayoutConfig();
    renderer.previousPage(score, 0, layoutConfig);
    _showToolbarsTemporarily();
  }

  void _jumpToPage(int page) {
    final score = _getParsedScore();
    if (score == null) return;
    final renderer =
        Provider.of<ScoreRendererProvider>(context, listen: false);
    final layoutConfig =
        Provider.of<UIStateProvider>(context, listen: false).getLayoutConfig();
    renderer.renderPage(score, 0, page, layoutConfig);
  }

  // -------------------------------------------------------
  // Toolbar auto-hide
  // -------------------------------------------------------
  void _toggleToolbars() {
    if (_annotationMode) return; // toolbars always visible in annotation mode
    if (_toolbarsVisible) {
      _hideToolbars();
    } else {
      _showToolbars();
    }
  }

  void _showToolbars() {
    _autoHideTimer?.cancel();
    _toolbarsVisible = true;
    _toolbarAnimCtrl.forward();
    _scheduleAutoHide();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _hideToolbars() {
    _autoHideTimer?.cancel();
    _toolbarsVisible = false;
    _toolbarAnimCtrl.reverse();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _showToolbarsTemporarily() {
    _showToolbars();
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_annotationMode) {
        _hideToolbars();
      }
    });
  }

  // -------------------------------------------------------
  // Tap and swipe handling
  // -------------------------------------------------------
  void _handleTapDown(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    final x = details.localPosition.dx;

    if (x < width * 0.15) {
      _previousPage();
    } else if (x > width * 0.85) {
      _nextPage();
    } else {
      _toggleToolbars();
    }
  }

  void _handleHorizontalSwipeEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity > 300) {
      _previousPage();
    } else if (velocity < -300) {
      _nextPage();
    }
  }

  // -------------------------------------------------------
  // Display mode picker
  // -------------------------------------------------------
  void _showDisplayModeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Display Mode',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ..._DisplayMode.values.map((mode) => RadioListTile<_DisplayMode>(
                  title: Text(mode.label),
                  secondary: Icon(mode.icon),
                  value: mode,
                  groupValue: _displayMode,
                  onChanged: (val) {
                    if (val != null) setState(() => _displayMode = val);
                    Navigator.of(ctx).pop();
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Page jump dialog
  // -------------------------------------------------------
  Future<void> _showPageJumpDialog(BuildContext context, int totalPages) async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '1 – $totalPages',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              Navigator.of(ctx).pop(n);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result >= 1 && result <= totalPages) {
      _jumpToPage(result - 1);
    }
  }

  // -------------------------------------------------------
  // Build
  // -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor:
            Theme.of(context).extension<ScoreColors>()?.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_scoreData == null) {
      return _buildNotFoundScreen(context);
    }

    return Consumer2<ScoreRendererProvider, UIStateProvider>(
      builder: (context, renderer, uiState, _) {
        return Scaffold(
          backgroundColor:
              _buildScoreBackground(context, uiState.darkMode),
          body: GestureDetector(
            onTapDown: _handleTapDown,
            onHorizontalDragEnd: _handleHorizontalSwipeEnd,
            child: Stack(
              children: [
                // Score canvas (fills entire screen)
                _buildScoreCanvas(context, renderer, uiState),

                // Top toolbar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _toolbarOpacity,
                    child: _buildTopToolbar(context, renderer, uiState),
                  ),
                ),

                // Bottom toolbar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _toolbarOpacity,
                    child: _buildBottomToolbar(context, renderer),
                  ),
                ),

                // Annotation toolbar (left rail, only in annotation mode)
                if (_annotationMode)
                  Positioned(
                    left: 0,
                    top: 80,
                    bottom: 80,
                    child: _buildAnnotationRail(context),
                  ),

                // Page tap zone indicators (brief flash, hidden normally)
                // Left zone
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width * 0.15,
                  child: const _TapZoneIndicator(alignment: Alignment.centerLeft),
                ),
                // Right zone
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width * 0.15,
                  child: const _TapZoneIndicator(alignment: Alignment.centerRight),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _buildScoreBackground(BuildContext context, bool isDark) {
    final scoreColors = Theme.of(context).extension<ScoreColors>();
    return scoreColors?.background ?? Colors.white;
  }

  // -------------------------------------------------------
  // Score canvas
  // -------------------------------------------------------
  Widget _buildScoreCanvas(
    BuildContext context,
    ScoreRendererProvider renderer,
    UIStateProvider uiState,
  ) {
    if (renderer.isRendering) {
      return const Center(child: CircularProgressIndicator());
    }

    if (renderer.lastError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Render error: ${renderer.lastError}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final commands = renderer.currentRenderCommands;
    final config = uiState.getLayoutConfig();

    if (commands.isEmpty && _getParsedScore() == null) {
      return _buildScorePlaceholder(context, renderer);
    }

    // Render with ScorePainter (Module F)
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      boundaryMargin: const EdgeInsets.all(20),
      child: Center(
        child: ScoreView(
          commands: commands,
          width: config.pageWidth * config.zoom,
          height: config.pageHeight * config.zoom,
          decoration: BoxDecoration(
            color: _buildScoreBackground(context, uiState.darkMode),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Placeholder shown when score has no render commands yet (e.g. data loaded
  // but renderer not yet triggered)
  Widget _buildScorePlaceholder(
      BuildContext context, ScoreRendererProvider renderer) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Page ${renderer.currentPage + 1}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Score rendering not available for this format.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Top toolbar
  // -------------------------------------------------------
  Widget _buildTopToolbar(
    BuildContext context,
    ScoreRendererProvider renderer,
    UIStateProvider uiState,
  ) {
    final title = _scoreData!['title'] ?? 'Score';
    final composer = _scoreData!['composer'] ?? '';
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface.withValues(alpha: 0.95),
            scheme.surface.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
                tooltip: 'Back',
              ),
              // Title/Composer
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (composer.isNotEmpty)
                      Text(
                        composer,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Display mode
              IconButton(
                icon: Icon(_displayMode.icon),
                tooltip: 'Display Mode',
                onPressed: () => _showDisplayModeSheet(context),
              ),
              // Annotation toggle
              IconButton(
                icon: Icon(
                  _annotationMode ? Icons.edit : Icons.edit_outlined,
                  color: _annotationMode ? scheme.primary : null,
                ),
                tooltip: _annotationMode ? 'Exit Annotation' : 'Annotate',
                onPressed: () {
                  setState(() => _annotationMode = !_annotationMode);
                  if (_annotationMode) {
                    _autoHideTimer?.cancel();
                    _showToolbars();
                  } else {
                    _scheduleAutoHide();
                  }
                },
              ),
              // Night mode quick toggle
              IconButton(
                icon: Icon(
                  uiState.darkMode
                      ? Icons.brightness_7_outlined
                      : Icons.brightness_4_outlined,
                ),
                tooltip: uiState.darkMode ? 'Light Mode' : 'Night Mode',
                onPressed: () => uiState.setDarkMode(!uiState.darkMode),
              ),
              // More menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) =>
                    _handleMoreMenuAction(context, value, renderer),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'jump',
                    child: ListTile(
                      leading: Icon(Icons.skip_next_outlined),
                      title: Text('Jump to Page'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'playback',
                    child: ListTile(
                      leading: Icon(Icons.play_circle_outline),
                      title: Text('Playback Controls'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'info',
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Score Info'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMoreMenuAction(
    BuildContext context,
    String action,
    ScoreRendererProvider renderer,
  ) {
    switch (action) {
      case 'jump':
        _showPageJumpDialog(context, renderer.totalPages);
      case 'playback':
        setState(() => _isPlaybackBarVisible = !_isPlaybackBarVisible);
      case 'info':
        _showScoreInfoSheet(context);
    }
  }

  // -------------------------------------------------------
  // Bottom toolbar
  // -------------------------------------------------------
  Widget _buildBottomToolbar(
      BuildContext context, ScoreRendererProvider renderer) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            scheme.surface.withValues(alpha: 0.95),
            scheme.surface.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Playback bar (optional, shown when enabled)
            if (_isPlaybackBarVisible) _buildPlaybackBar(context),
            // Page navigation row
            _buildPageNavigationRow(context, renderer),
          ],
        ),
      ),
    );
  }

  Widget _buildPageNavigationRow(
      BuildContext context, ScoreRendererProvider renderer) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          // Previous page
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: renderer.currentPage > 0 ? _previousPage : null,
            tooltip: 'Previous Page',
          ),
          // Page indicator (tap to jump)
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  _showPageJumpDialog(context, renderer.totalPages),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${renderer.currentPage + 1} / ${renderer.totalPages}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
          ),
          // Next page
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: renderer.currentPage < renderer.totalPages - 1
                ? _nextPage
                : null,
            tooltip: 'Next Page',
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Transport controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: () {},
                tooltip: 'Start',
              ),
              IconButton(
                icon: const Icon(Icons.replay_10),
                onPressed: () {},
                tooltip: 'Back 10s',
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: scheme.onPrimary,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _isPlaying = !_isPlaying),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10),
                onPressed: () {},
                tooltip: 'Forward 10s',
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: () {},
                tooltip: 'End',
              ),
            ],
          ),
          // Tempo and metronome row
          Row(
            children: [
              // Metronome toggle
              IconButton(
                icon: Icon(
                  Icons.music_note,
                  color: _metronomeOn ? scheme.primary : null,
                ),
                onPressed: () => setState(() => _metronomeOn = !_metronomeOn),
                tooltip: 'Metronome',
              ),
              // Tempo label
              Text(
                '${_tempo.round()} BPM',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              // Tempo slider
              Expanded(
                child: Slider(
                  value: _tempo,
                  min: 40,
                  max: 240,
                  divisions: 200,
                  label: '${_tempo.round()}',
                  onChanged: (v) => setState(() => _tempo = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Annotation toolbar (left rail)
  // -------------------------------------------------------
  Widget _buildAnnotationRail(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 52,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AnnotationTool(icon: Icons.edit, tooltip: 'Pen'),
          _AnnotationTool(icon: Icons.highlight, tooltip: 'Highlight'),
          _AnnotationTool(icon: Icons.text_fields, tooltip: 'Text'),
          _AnnotationTool(icon: Icons.auto_fix_high, tooltip: 'Stamp'),
          _AnnotationTool(icon: Icons.auto_fix_off, tooltip: 'Eraser'),
          const Divider(height: 1, indent: 8, endIndent: 8),
          _AnnotationTool(icon: Icons.layers_outlined, tooltip: 'Layers'),
          const Divider(height: 1, indent: 8, endIndent: 8),
          _AnnotationTool(icon: Icons.undo, tooltip: 'Undo'),
          _AnnotationTool(icon: Icons.redo, tooltip: 'Redo'),
          const SizedBox(height: 8),
          // Done button
          GestureDetector(
            onTap: () => setState(() => _annotationMode = false),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check, color: scheme.onPrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Score info sheet
  // -------------------------------------------------------
  void _showScoreInfoSheet(BuildContext context) {
    final data = _scoreData!;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['title'] ?? 'Unknown',
              style: Theme.of(ctx).textTheme.headlineSmall,
            ),
            if ((data['composer'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                data['composer'],
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Pages',
              value: '${data['pageCount'] ?? 0}',
            ),
            _InfoRow(
              label: 'Source',
              value: data['sourceType'] ?? 'unknown',
            ),
            _InfoRow(
              label: 'Imported',
              value: data['dateImported'] != null
                  ? DateTime.parse(data['dateImported']).toLocal().toString().split('.')[0]
                  : 'Unknown',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Not found screen
  // -------------------------------------------------------
  Widget _buildNotFoundScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Score Not Found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text('Score not found'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Annotation tool button
// ============================================================
class _AnnotationTool extends StatelessWidget {
  final IconData icon;
  final String tooltip;

  const _AnnotationTool({required this.icon, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

// ============================================================
// Tap zone visual indicator (transparent by default)
// ============================================================
class _TapZoneIndicator extends StatelessWidget {
  final Alignment alignment;
  const _TapZoneIndicator({required this.alignment});

  @override
  Widget build(BuildContext context) {
    // Invisible touch target — purely for visual guidance
    return Container(color: Colors.transparent);
  }
}

// ============================================================
// Info row helper
// ============================================================
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
