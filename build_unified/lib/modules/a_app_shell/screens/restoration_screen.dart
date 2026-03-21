import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/restoration_provider.dart';
import '../state/score_library_provider.dart';
import '../services/restoration_service.dart';
import '../widgets/image_comparison_slider.dart';
import '../widgets/quality_score_card.dart';

/// Screen for restoring score images via Module C and comparing results
class RestorationScreen extends StatefulWidget {
  final String scoreId;

  const RestorationScreen({
    required this.scoreId,
    super.key,
  });

  @override
  State<RestorationScreen> createState() => _RestorationScreenState();
}

class _RestorationScreenState extends State<RestorationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _optionsPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndRestore();
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final provider =
          Provider.of<RestorationProvider>(context, listen: false);
      switch (_tabController.index) {
        case 0:
          provider.setComparisonMode(ComparisonMode.original);
          break;
        case 1:
          provider.setComparisonMode(ComparisonMode.restored);
          break;
        case 2:
          provider.setComparisonMode(ComparisonMode.comparison);
          break;
        case 3:
          provider.setComparisonMode(ComparisonMode.quality);
          break;
      }
    }
  }

  Future<void> _loadAndRestore() async {
    final restorationProvider =
        Provider.of<RestorationProvider>(context, listen: false);
    final libraryProvider =
        Provider.of<ScoreLibraryProvider>(context, listen: false);

    // Load original image from Module B
    final scoreData = await libraryProvider.getScore(widget.scoreId);
    if (scoreData == null || !mounted) return;

    // Try to get image bytes from score data
    final imageBytes = await libraryProvider.getImageBytes(widget.scoreId);
    if (imageBytes == null || !mounted) return;

    // Start restoration
    final fileName = scoreData['title'] as String? ?? 'score_image.jpg';
    await restorationProvider.startRestoration(imageBytes, fileName);

    // Switch to comparison tab on success
    if (mounted && restorationProvider.hasResult) {
      _tabController.animateTo(2);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RestorationProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('이미지 복원'),
            bottom: provider.hasResult
                ? TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: '원본'),
                      Tab(text: '복원'),
                      Tab(text: '비교'),
                      Tab(text: '품질'),
                    ],
                  )
                : null,
          ),
          body: Stack(
            children: [
              _buildBody(provider),
              if (kDebugMode) _buildDebugInfoBar(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(RestorationProvider provider) {
    switch (provider.state) {
      case RestorationState.idle:
        return const Center(
          child: Text('이미지를 불러오는 중...'),
        );

      case RestorationState.loading:
        return _buildLoadingView(provider);

      case RestorationState.error:
        return _buildErrorView(provider);

      case RestorationState.success:
        return _buildSuccessView(provider);
    }
  }

  Widget _buildLoadingView(RestorationProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          const SizedBox(height: 24),
          const Text(
            '이미지 복원 중... (약 5-15초)',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            '잠시만 기다려주세요',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          // Show file size warning if image is large
          if (provider.imageSizeWarning && provider.imageSizeInfo != null) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '이미지 크기가 큽니다 (${provider.imageSizeInfo}MB). '
                      '처리 시간이 길어질 수 있습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorView(RestorationProvider provider) {
    final errorIcon = _getErrorIcon(provider.errorCode);
    final errorColor = _getErrorColor(provider.errorCode);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              errorIcon,
              size: 64,
              color: errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              _getErrorTitle(provider.errorCode),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage ?? '알 수 없는 오류가 발생했습니다.',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (provider.errorCode != null) ...[
              const SizedBox(height: 4),
              Text(
                '오류 코드: ${provider.errorCode}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Prominent retry button
            SizedBox(
              width: 200,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => provider.retry(),
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text(
                  '다시 시도',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('돌아가기'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon(String? code) {
    switch (code) {
      case 'E-C01':
      case 'E-C02':
        return Icons.photo_size_select_large;
      case 'E-C03':
      case 'E-C04':
        return Icons.broken_image;
      case 'E-C08':
        return Icons.timer_off;
      case 'E-C10':
      case 'E-C99':
        return Icons.cloud_off;
      default:
        return Icons.error_outline;
    }
  }

  Color _getErrorColor(String? code) {
    switch (code) {
      case 'E-C08':
        return Colors.orange;
      case 'E-C10':
      case 'E-C99':
        return Colors.blue.shade700;
      default:
        return Colors.red;
    }
  }

  String _getErrorTitle(String? code) {
    switch (code) {
      case 'E-C01':
        return '이미지가 너무 작습니다';
      case 'E-C02':
        return '이미지가 너무 큽니다';
      case 'E-C03':
        return '지원하지 않는 형식';
      case 'E-C04':
        return '손상된 파일';
      case 'E-C05':
        return '페이지 감지 실패';
      case 'E-C06':
        return '이진화 실패';
      case 'E-C07':
        return '메모리 부족';
      case 'E-C08':
        return '처리 시간 초과';
      case 'E-C10':
        return '서버 연결 거부';
      case 'E-C99':
        return '서버에 연결할 수 없습니다';
      default:
        return '복원 실패';
    }
  }

  Widget _buildSuccessView(RestorationProvider provider) {
    return Column(
      children: [
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOriginalTab(provider),
              _buildRestoredTab(provider),
              _buildComparisonTab(provider),
              _buildQualityTab(provider),
            ],
          ),
        ),

        // Options panel
        _buildOptionsPanel(provider),
      ],
    );
  }

  Widget _buildOriginalTab(RestorationProvider provider) {
    if (provider.originalImageBytes == null) {
      return const Center(child: Text('원본 이미지를 찾을 수 없습니다.'));
    }
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.memory(
          provider.originalImageBytes!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildRestoredTab(RestorationProvider provider) {
    final imageBytes = provider.currentRestoredBytes;
    if (imageBytes == null) {
      return const Center(child: Text('복원된 이미지를 찾을 수 없습니다.'));
    }

    return Column(
      children: [
        // Toggle binary/grayscale
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('이진화')),
              ButtonSegment(value: false, label: Text('그레이스케일')),
            ],
            selected: {provider.showBinary},
            onSelectionChanged: (selected) {
              provider.toggleBinaryGrayscale();
            },
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonTab(RestorationProvider provider) {
    if (provider.originalImageBytes == null ||
        provider.currentRestoredBytes == null) {
      return const Center(child: Text('비교할 이미지가 없습니다.'));
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: ImageComparisonSlider(
        originalImage: provider.originalImageBytes!,
        restoredImage: provider.currentRestoredBytes!,
      ),
    );
  }

  Widget _buildQualityTab(RestorationProvider provider) {
    final result = provider.result;
    if (result == null) {
      return const Center(child: Text('품질 정보가 없습니다.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          QualityScoreCard(
            overallScore: result.qualityScore,
            components: result.qualityComponents,
            processingTimeMs: result.processingTimeMs,
            skewAngle: result.skewAngle,
          ),
          if (result.qualityScore < 0.3) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '이미지 품질이 낮습니다',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '다시 촬영을 권장합니다. '
                            '균일한 조명에서 정면으로 촬영해주세요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!result.pageDetected) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '페이지 경계를 감지하지 못했습니다. '
                        '원근 보정이 건너뛰어졌습니다.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Step times
          if (result.stepTimesMs.isNotEmpty) _buildStepTimes(result),
        ],
      ),
    );
  }

  Widget _buildStepTimes(RestorationResult result) {
    final stepLabels = <String, String>{
      'detect_page_bounds': '페이지 감지',
      'correct_perspective': '원근 보정',
      'detect_skew': '기울기 감지',
      'correct_skew': '기울기 보정',
      'convert_grayscale': '그레이스케일',
      'remove_shadows': '그림자 제거',
      'enhance_contrast': '대비 향상',
      'binarize': '이진화',
      'compute_quality': '품질 계산',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '처리 단계별 시간',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ...result.stepTimesMs.entries.map((entry) {
              final label = stepLabels[entry.key] ?? entry.key;
              final timeMs = entry.value;
              final fraction = result.processingTimeMs > 0
                  ? (timeMs / result.processingTimeMs).clamp(0.0, 1.0)
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: fraction,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade300,
                        ),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${timeMs.round()}ms',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsPanel(RestorationProvider provider) {
    return ExpansionTile(
      title: const Text(
        '복원 옵션',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      initiallyExpanded: _optionsPanelExpanded,
      onExpansionChanged: (expanded) {
        setState(() => _optionsPanelExpanded = expanded);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              _buildToggleOption(
                '원근 보정',
                provider.options.perspectiveCorrection,
                (val) => provider.updateOptions(
                  provider.options.copyWith(perspectiveCorrection: val),
                ),
              ),
              _buildToggleOption(
                '기울기 보정',
                provider.options.deskew,
                (val) => provider.updateOptions(
                  provider.options.copyWith(deskew: val),
                ),
              ),
              _buildToggleOption(
                '그림자 제거',
                provider.options.shadowRemoval,
                (val) => provider.updateOptions(
                  provider.options.copyWith(shadowRemoval: val),
                ),
              ),
              _buildToggleOption(
                '대비 향상',
                provider.options.contrastEnhancement,
                (val) => provider.updateOptions(
                  provider.options.copyWith(contrastEnhancement: val),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('이진화 방식', style: TextStyle(fontSize: 14)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: provider.options.binarizationMethod,
                    items: const [
                      DropdownMenuItem(value: 'sauvola', child: Text('Sauvola')),
                      DropdownMenuItem(value: 'otsu', child: Text('Otsu')),
                      DropdownMenuItem(
                          value: 'adaptive', child: Text('Adaptive')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        provider.updateOptions(
                          provider.options.copyWith(binarizationMethod: val),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: provider.isLoading
                      ? null
                      : () => provider.retry(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('재처리'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleOption(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  /// Debug info bar shown at the bottom of the screen in debug mode only.
  Widget _buildDebugInfoBar(RestorationProvider provider) {
    final result = provider.result;

    // Determine current image type label
    String imageTypeLabel;
    switch (provider.comparisonMode) {
      case ComparisonMode.original:
        imageTypeLabel = '원본';
        break;
      case ComparisonMode.restored:
        imageTypeLabel = provider.showBinary ? '이진화' : '그레이스케일';
        break;
      case ComparisonMode.comparison:
        imageTypeLabel = '비교';
        break;
      case ComparisonMode.quality:
        imageTypeLabel = '품질';
        break;
    }

    final processingTime = result != null
        ? '${(result.processingTimeMs / 1000).toStringAsFixed(1)}초'
        : '-';
    final qualityScore = result != null
        ? result.qualityScore.toStringAsFixed(2)
        : '-';

    // Image dimensions info
    String dimsInfo = '-';
    final currentBytes = provider.comparisonMode == ComparisonMode.original
        ? provider.originalImageBytes
        : provider.currentRestoredBytes;
    if (currentBytes != null) {
      dimsInfo = '${(currentBytes.lengthInBytes / 1024).round()}KB';
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 30,
        color: Colors.black.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Text(
              '[$imageTypeLabel]',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            const SizedBox(width: 8),
            Text(
              processingTime,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const SizedBox(width: 8),
            Text(
              'Q:$qualityScore',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const SizedBox(width: 8),
            Text(
              dimsInfo,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const Spacer(),
            Text(
              provider.serverUrl,
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
