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
enum _ImportSource { camera, pdf, musicXml, image, url, demo }

// ============================================================
// ImportScreen
// ============================================================
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen>
    with SingleTickerProviderStateMixin {
  bool _isImporting = false;
  String _importStatusMessage = '';
  double _importProgress = 0.0;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnimation;

  static const String _demoXml = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work><work-title>Twinkle Twinkle Little Star</work-title></work>
  <identification><creator type="composer">Traditional</creator></identification>
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>1</divisions><key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
    </measure>
    <measure number="2">
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>2</duration><type>half</type></note>
    </measure>
    <measure number="3">
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
    </measure>
    <measure number="4">
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration><type>half</type></note>
    </measure>
  </part>
</score-partwise>''';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
  // Import handlers
  // -------------------------------------------------------
  Future<void> _handleImportSource(_ImportSource source) async {
    switch (source) {
      case _ImportSource.camera:
        context.push('/capture/camera');
      case _ImportSource.pdf:
        await _importDemoScore(label: 'PDF Score');
      case _ImportSource.musicXml:
        await _importDemoScore(label: 'MusicXML Score');
      case _ImportSource.image:
        await _importDemoScore(label: 'Scanned Score');
      case _ImportSource.url:
        await _showUrlImportSheet();
      case _ImportSource.demo:
        await _importDemoScore(label: 'Demo Score');
    }
  }

  Future<void> _importDemoScore({String label = 'Demo Score'}) async {
    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _importStatusMessage = 'Loading $label...';
    });

    try {
      final library =
          Provider.of<ScoreLibraryProvider>(context, listen: false);

      // Simulate progress
      for (var i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 80));
        if (!mounted) return;
        setState(() {
          _importProgress = (i + 1) / 10;
          _importStatusMessage = i < 3
              ? 'Reading file...'
              : i < 6
                  ? 'Parsing notation...'
                  : 'Finalizing...';
        });
      }

      final result = await library.moduleB
          ?.importMusicXmlFromString(_demoXml, 'Twinkle Twinkle Little Star');

      if (!mounted) return;
      setState(() {
        _importProgress = 1.0;
        _isImporting = false;
      });

      if (result?.isSuccess ?? false) {
        await library.loadLibrary();
        if (!mounted) return;
        final scoreId = result!.valueOrNull?.id;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Score imported successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (scoreId != null) {
          context.go('/viewer/$scoreId');
        } else {
          context.go('/');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Import failed: ${result?.errorOrNull ?? "Unknown"}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _showUrlImportSheet() async {
    final controller = TextEditingController();

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboard = clipboardData?.text ?? '';
    if (clipboard.startsWith('http://') || clipboard.startsWith('https://')) {
      controller.text = clipboard;
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.link_rounded,
                      color: scheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Import from URL',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Paste a direct link to a MusicXML or PDF file (e.g. IMSLP)',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'https://example.com/score.xml',
                  prefixIcon: Icon(
                    Icons.link_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.content_paste_rounded,
                        color: scheme.primary, size: 20),
                    tooltip: 'Paste',
                    onPressed: () async {
                      final data =
                          await Clipboard.getData(Clipboard.kTextPlain);
                      controller.text = data?.text ?? '';
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Import'),
                      onPressed: () {
                        final url = controller.text.trim();
                        if (url.isEmpty) return;
                        Navigator.of(ctx).pop();
                        _runUrlImport(url);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
  }

  Future<void> _runUrlImport(String url) async {
    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _importStatusMessage = 'Connecting...';
    });

    try {
      final library =
          Provider.of<ScoreLibraryProvider>(context, listen: false);

      final progressTimer = Timer.periodic(
          const Duration(milliseconds: 80), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _importProgress =
              (_importProgress + 0.04).clamp(0.0, 0.90);
          _importStatusMessage = _progressMessage(_importProgress);
        });
      });

      bool success = false;
      String? newScoreId;

      if (url.endsWith('.xml') ||
          url.endsWith('.mxl') ||
          url.contains('musicxml')) {
        final result = await library.moduleB?.importMusicXml(url);
        if (result?.isSuccess ?? false) {
          newScoreId = result!.valueOrNull!.id;
          success = true;
        }
      } else {
        final result = await library.moduleB?.importPdf(url);
        if (result?.isSuccess ?? false) {
          newScoreId = result!.valueOrNull!.id;
          success = true;
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
            content: Text(
                'Import failed: ${library.lastError ?? "Unknown error"}'),
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

  String _progressMessage(double progress) {
    if (progress < 0.2) return 'Reading file...';
    if (progress < 0.5) return 'Parsing notation...';
    if (progress < 0.8) return 'Processing score...';
    return 'Finalizing...';
  }

  // -------------------------------------------------------
  // Build
  // -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isImporting) return _buildImportingScreen(context);
    return _buildIdleScreen(context);
  }

  // -------------------------------------------------------
  // Importing progress screen
  // -------------------------------------------------------
  Widget _buildImportingScreen(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = (_importProgress * 100).round();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 36),
              Text(
                'Importing Score',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _importStatusMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _importProgress,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$percent%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 40),
              OutlinedButton.icon(
                onPressed: () => setState(() => _isImporting = false),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Idle import screen
  // -------------------------------------------------------
  Widget _buildIdleScreen(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Gradient hero AppBar
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => context.pop(),
              tooltip: 'Close',
            ),
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import Score',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Add music to your library',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppTheme.darkHeroGradient
                      : AppTheme.primaryGradientVertical,
                ),
                child: Stack(
                  children: [
                    // Decorative music elements
                    Positioned(
                      top: 20,
                      right: 24,
                      child: Opacity(
                        opacity: 0.15,
                        child: Icon(
                          Icons.library_music_outlined,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      right: 80,
                      child: Opacity(
                        opacity: 0.1,
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Demo Score — prominent banner
                      _DemoScoreBanner(
                        onTap: () =>
                            _handleImportSource(_ImportSource.demo),
                      ),
                      const SizedBox(height: 28),

                      // Section: Capture
                      _SectionLabel(label: 'Capture'),
                      const SizedBox(height: 10),
                      _CameraCard(
                        onTap: () =>
                            _handleImportSource(_ImportSource.camera),
                      ),
                      const SizedBox(height: 28),

                      // Section: From Files
                      _SectionLabel(label: 'From Files'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ImportOptionCard(
                              icon: Icons.picture_as_pdf_rounded,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFDC2626),
                                  Color(0xFFEF4444)
                                ],
                              ),
                              title: 'PDF',
                              subtitle: 'Sheet music PDF',
                              onTap: () =>
                                  _handleImportSource(_ImportSource.pdf),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ImportOptionCard(
                              icon: Icons.music_note_rounded,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2563EB),
                                  Color(0xFF3B82F6)
                                ],
                              ),
                              title: 'MusicXML',
                              subtitle: '.xml / .mxl',
                              onTap: () => _handleImportSource(
                                  _ImportSource.musicXml),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ImportOptionCard(
                              icon: Icons.image_rounded,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFEA580C),
                                  Color(0xFFF97316)
                                ],
                              ),
                              title: 'Image',
                              subtitle: 'JPG / PNG',
                              onTap: () =>
                                  _handleImportSource(_ImportSource.image),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Section: From Web
                      _SectionLabel(label: 'From Web'),
                      const SizedBox(height: 10),
                      _UrlImportCard(
                        onTap: () =>
                            _handleImportSource(_ImportSource.url),
                      ),
                      const SizedBox(height: 28),

                      // Recent imports
                      _RecentImportsSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Demo score prominent banner
// ============================================================
class _DemoScoreBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _DemoScoreBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E1B4B), Color(0xFF2E1065)],
                    )
                  : AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.play_circle_filled_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Try Demo Score',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                'Instant',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Load "Twinkle Twinkle" and explore the viewer',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Section label
// ============================================================
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

// ============================================================
// Camera card — large, gradient
// ============================================================
class _CameraCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CameraCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            height: 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1F2937), const Color(0xFF111827)]
                    : [const Color(0xFFF0F4FF), const Color(0xFFE0E7FF)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFE0E7FF),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5)
                            .withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan with Camera',
                        style:
                            Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Photograph printed music\nAuto-crop and deskew included',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Import option card — compact, gradient icon
// ============================================================
class _ImportOptionCard extends StatelessWidget {
  final IconData icon;
  final LinearGradient gradient;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImportOptionCard({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
          _clipboardUrl =
              text.length > 48 ? '${text.substring(0, 45)}...' : text;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.secondary,
                        scheme.secondary.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.secondary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.public_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Import from URL',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'IMSLP or any direct link to a score file',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (_hasClipboardUrl) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.content_paste_rounded,
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
                                    fontWeight: FontWeight.w500,
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Recent imports section
// ============================================================
class _RecentImportsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreLibraryProvider>(
      builder: (context, library, _) {
        final recent = library.allScores.take(3).toList();
        if (recent.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(label: 'Recent Imports'),
            const SizedBox(height: 10),
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
    final theme = Theme.of(context);
    final sourceType =
        (score['sourceType'] ?? '').toString().toLowerCase();
    final accentColor = _sourceColor(sourceType);
    final icon = _sourceIcon(sourceType);
    final dateImported = score['dateImported'] != null
        ? DateTime.tryParse(score['dateImported'])
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        tileColor: theme.brightness == Brightness.dark
            ? const Color(0xFF1F2937)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withValues(alpha: 0.2),
                accentColor.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        title: Text(
          score['title'] ?? 'Unknown',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          dateImported != null ? _relativeDate(dateImported) : '',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Icon(
          Icons.open_in_new_rounded,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant
              .withValues(alpha: 0.5),
        ),
        onTap: () => context.go('/viewer/${score['id']}'),
      ),
    );
  }
}

// ============================================================
// Shared helpers
// ============================================================
IconData _sourceIcon(String sourceType) {
  if (sourceType.contains('pdf')) return Icons.picture_as_pdf_rounded;
  if (sourceType.contains('musicxml') || sourceType.contains('xml')) {
    return Icons.music_note_rounded;
  }
  if (sourceType.contains('image')) return Icons.image_rounded;
  return Icons.description_rounded;
}

Color _sourceColor(String sourceType) {
  if (sourceType.contains('pdf')) return AppTheme.sourcePdf;
  if (sourceType.contains('musicxml') || sourceType.contains('xml')) {
    return AppTheme.sourceMusicXml;
  }
  if (sourceType.contains('image')) return AppTheme.sourceImage;
  return const Color(0xFF6B7280);
}

String _relativeDate(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 60) return 'Just now';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.month}/${date.day}/${date.year}';
}
