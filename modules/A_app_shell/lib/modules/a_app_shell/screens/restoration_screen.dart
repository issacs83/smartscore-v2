import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/restoration_service.dart';
import '../widgets/image_comparison_slider.dart';

class RestorationScreen extends StatefulWidget {
  final String? serverUrl;

  const RestorationScreen({
    Key? key,
    this.serverUrl,
  }) : super(key: key);

  @override
  State<RestorationScreen> createState() => _RestorationScreenState();
}

class _RestorationScreenState extends State<RestorationScreen> {
  late RestorationService _restorationService;
  RestorationResult? _result;
  bool _isLoading = false;
  String? _error;
  Uint8List? _selectedImage;

  @override
  void initState() {
    super.initState();
    _restorationService = RestorationService(serverUrl: widget.serverUrl);
  }

  /// Handle file selection from web file input
  void _selectImage() {
    final html.FileUploadInputElement input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.click();

    input.onChange.listen((e) async {
      final files = input.files;
      if (files!.isEmpty) return;

      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);

      reader.onLoad.listen((e) async {
        final imageData = Uint8List.fromList(reader.result as List<int>);
        setState(() {
          _selectedImage = imageData;
          _result = null;
          _error = null;
        });

        await _restoreImage(imageData);
      });
    });
  }

  /// Send image to restoration server
  Future<void> _restoreImage(Uint8List imageData) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _restorationService.restoreImage(imageData);
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restoration failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sheet Music Restoration'),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upload Section
            _buildUploadSection(context, isMobile),
            const SizedBox(height: 24),

            // Comparison Section
            if (_result != null) ...[
              _buildComparisonSection(context, isMobile),
              const SizedBox(height: 24),
            ],

            // Pipeline Steps
            if (_result != null && _result!.pipelineSteps.isNotEmpty) ...[
              _buildPipelineStepsSection(context, isMobile),
              const SizedBox(height: 24),
            ],

            // Quality Score
            if (_result != null) ...[
              _buildQualityScoreSection(context, isMobile),
              const SizedBox(height: 24),
            ],

            // Error Message
            if (_error != null) _buildErrorSection(context),
          ],
        ),
      ),
    );
  }

  /// Build the upload section
  Widget _buildUploadSection(BuildContext context, bool isMobile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_selectedImage != null)
              Column(
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: isMobile ? 200 : 300,
                      maxWidth: double.infinity,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Image.memory(
                      _selectedImage!,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _selectImage,
              icon: const Icon(Icons.image),
              label: Text(
                _selectedImage == null
                    ? 'Select Sheet Music Image'
                    : 'Select Different Image',
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Processing image...'),
            ],
          ],
        ),
      ),
    );
  }

  /// Build the comparison section
  Widget _buildComparisonSection(BuildContext context, bool isMobile) {
    if (_result == null) return const SizedBox.shrink();

    final width = isMobile ? 280.0 : 600.0;
    final height = isMobile ? 200.0 : 400.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comparison',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ImageComparisonSlider(
                  beforeImage: MemoryImage(_result!.originalImage),
                  afterImage: MemoryImage(_result!.restoredImage),
                  width: width,
                  height: height,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Drag the divider left/right to compare original and restored images',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build the pipeline steps section
  Widget _buildPipelineStepsSection(BuildContext context, bool isMobile) {
    if (_result == null) return const SizedBox.shrink();

    final steps = [
      'page_detected',
      'perspective',
      'deskewed',
      'grayscale',
      'contrast',
      'binary',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pipeline Steps',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final step in steps)
                    if (_result!.pipelineSteps.containsKey(step))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.grey[50],
                              ),
                              child: Image.memory(
                                _result!.pipelineSteps[step]!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatStepName(step),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the quality score section
  Widget _buildQualityScoreSection(BuildContext context, bool isMobile) {
    if (_result == null) return const SizedBox.shrink();

    final score = _result!.qualityScore;
    final scoreColor = _getScoreColor(score.overall);

    final components = [
      ('Contrast', score.contrast, 0.25),
      ('Sharpness', score.sharpness, 0.20),
      ('Line Straightness', score.lineStraightness, 0.20),
      ('Noise Level', score.noiseLevel, 0.15),
      ('Coverage', score.coverage, 0.10),
      ('Binarization', score.binarizationQuality, 0.10),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quality Score',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            // Overall score
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.1),
                border: Border.all(color: scoreColor, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Overall Score',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(score.overall * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Component breakdown
            Text(
              'Component Breakdown',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            for (final (name, value, _) in components) ...[
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 20,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getScoreColor(value),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${(value * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  /// Build error section
  Widget _buildErrorSection(BuildContext context) {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 24),
            const SizedBox(height: 8),
            Text(
              'Error',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: Colors.red, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _selectImage,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  /// Format step name for display
  String _formatStepName(String step) {
    return step
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Get color based on score value
  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.amber;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
  }
}
