import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../state/score_library_provider.dart';
import '../state/score_renderer_provider.dart';
import '../state/device_provider.dart';
import '../state/ui_state_provider.dart';
import '../state/comparison_provider.dart';
import '../config.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({Key? key}) : super(key: key);

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSampleLoading = false;
  bool _sampleLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Panel'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'State'),
            Tab(text: 'Events'),
            Tab(text: 'Modules'),
            Tab(text: 'JSON'),
            Tab(text: 'Performance'),
            Tab(text: 'Samples'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStateTab(),
          _buildEventsTab(),
          _buildModulesTab(),
          _buildJsonTab(),
          _buildPerformanceTab(),
          _buildSamplesTab(),
        ],
      ),
    );
  }

  Future<void> _loadBeethovenSample(ScoreLibraryProvider library) async {
    setState(() { _isSampleLoading = true; });

    try {
      // Load page images
      int loadedPages = 0;
      for (int i = 1; i <= 6; i++) {
        final pageName = 'page_${i.toString().padLeft(3, '0')}.png';
        final bytes = await rootBundle.load(
          'test_assets/beethoven_op14_no2/original/$pageName');
        final imageBytes = bytes.buffer.asUint8List();

        final result = await library.moduleB?.importImage(
          imageBytes,
          'beethoven_op14_no2_$pageName',
        );
        if (result?.isSuccess ?? false) loadedPages++;
      }

      // Load MusicXML
      try {
        final xmlContent = await rootBundle.loadString(
          'test_assets/beethoven_op14_no2/original/sample_first_4_measures.musicxml');
        await library.moduleB?.importMusicXml(
          xmlContent,
          fileName: 'beethoven_op14_no2.musicxml',
        );
      } catch (_) {
        // MusicXML import is optional
      }

      await library.loadLibrary();

      setState(() { _isSampleLoading = false; _sampleLoaded = true; });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Beethoven 샘플 로드 완료 ($loadedPages 페이지)'),
          ),
        );
      }
    } catch (e) {
      setState(() { _isSampleLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('샘플 로드 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSamplesTab() {
    return Consumer<ScoreLibraryProvider>(
      builder: (context, library, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('테스트 샘플',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.music_note, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Beethoven Piano Sonata No. 10',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  'Op. 14 No. 2 — I. Allegro',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: const [
                          Chip(label: Text('G major')),
                          Chip(label: Text('2/4')),
                          Chip(label: Text('Piano')),
                          Chip(label: Text('6 pages')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isSampleLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_sampleLoaded)
                        Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text('샘플 로드 완료'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () => context.go('/'),
                              icon: const Icon(Icons.library_music),
                              label: const Text('라이브러리로 이동'),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _loadBeethovenSample(library),
                            icon: const Icon(Icons.download),
                            label: const Text('샘플 악보 불러오기'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStateTab() {
    return Consumer5<
        ScoreLibraryProvider,
        ScoreRendererProvider,
        DeviceProvider,
        UIStateProvider,
        ComparisonProvider>(
      builder: (context, library, renderer, devices, uiState, comparison, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection('Library State', library.dumpState()),
              _buildSection('Renderer State', renderer.dumpState()),
              _buildSection('Device State', devices.dumpState()),
              _buildSection('UI State', uiState.dumpState()),
              _buildSection('Comparison State', comparison.dumpState()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventsTab() {
    return Consumer<ScoreLibraryProvider>(
      builder: (context, library, _) {
        final events = <Map<String, dynamic>>[];  // eventLog not available on ScoreLibrary
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Event Log (Latest 50)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (events.isEmpty)
                const Text('No events recorded')
              else
                ...events.reversed.take(50).map((event) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event['type'] ?? 'Unknown',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            event['timestamp'] ?? '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (event['data'] != null)
                            Text(
                              'Data: ${event['data']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Module Status',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _buildModuleCard(
            'Module A (App Shell)',
            'Running',
            Colors.green,
            {'version': appVersion, 'flavor': buildFlavor.toString()},
          ),
          _buildModuleCard(
            'Module B (Score Input)',
            'Initialized',
            Colors.green,
            {'feature': 'PDF, Image, MusicXML import'},
          ),
          _buildModuleCard(
            'Module E (Music Normalizer)',
            'Ready',
            Colors.green,
            {'feature': 'MusicXML parsing, normalization'},
          ),
          _buildModuleCard(
            'Module F (Score Renderer)',
            'Ready',
            Colors.green,
            {'feature': 'Page rendering, layout engine'},
          ),
          _buildModuleCard(
            'Module K (External Device)',
            'Initialized',
            Colors.green,
            {'feature': 'Bluetooth, MIDI, keyboard support'},
          ),
        ],
      ),
    );
  }

  Widget _buildJsonTab() {
    return Consumer<ScoreLibraryProvider>(
      builder: (context, library, _) {
        if (library.selectedScoreId == null) {
          return const Center(
            child: Text('No score selected. Select a score to view its JSON.'),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Score JSON Inspector',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              SelectableText(
                'Score ID: ${library.selectedScoreId}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                'Raw Score JSON (Module E output):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  '{\n  "id": "...",\n  "title": "...",\n  "parts": [...],\n  "metadata": {...}\n}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontFamily: 'Courier',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Metrics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Target SLAs (p95)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          _buildMetricRow(
            'Cold Startup',
            '${PerformanceTargets.coldStartupMs}ms',
            Colors.blue,
          ),
          _buildMetricRow(
            'Route Navigation',
            '${PerformanceTargets.routeNavigationMs}ms',
            Colors.blue,
          ),
          _buildMetricRow(
            'Page Render',
            '${PerformanceTargets.pageRenderMs}ms',
            Colors.blue,
          ),
          _buildMetricRow(
            'Hit Test',
            '${PerformanceTargets.hitTestMs}ms',
            Colors.blue,
          ),
          _buildMetricRow(
            'Device Action',
            '${PerformanceTargets.deviceActionMs}ms',
            Colors.blue,
          ),
          _buildMetricRow(
            'Library Query (100 scores)',
            '${PerformanceTargets.libraryQueryMs}ms',
            Colors.blue,
          ),
          const SizedBox(height: 24),
          Text(
            'Memory Limits',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          _buildMetricRow(
            'Baseline',
            '${MemoryLimits.baseline}MB',
            Colors.orange,
          ),
          _buildMetricRow(
            'Peak',
            '${MemoryLimits.peak}MB',
            Colors.red,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Performance metrics collection started'),
                ),
              );
            },
            child: const Text('Start Profiling'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              _formatJson(data),
              style: const TextStyle(fontSize: 12, fontFamily: 'Courier'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(
    String name,
    String status,
    Color statusColor,
    Map<String, dynamic> info,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...info.entries.map((e) {
              return Text(
                '${e.key}: ${e.value}',
                style: Theme.of(context).textTheme.bodySmall,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String name, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatJson(Map<String, dynamic> data) {
    return data.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
  }
}
