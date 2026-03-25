/// Non-web stub for VerovioView.
/// On mobile/desktop the viewer shows a placeholder.
import 'package:flutter/material.dart';

/// Renders MusicXML using the Verovio WASM engraving engine.
///
/// This is the non-web stub. Only Flutter Web is currently supported.
class VerovioView extends StatefulWidget {
  final String musicXml;
  final String title;
  final void Function(int current, int total)? onPageChanged;

  const VerovioView({
    required this.musicXml,
    required this.title,
    this.onPageChanged,
    super.key,
  });

  @override
  State<VerovioView> createState() => VerovioViewState();
}

class VerovioViewState extends State<VerovioView> {
  /// No-op on non-web platforms.
  void nextPage() {}

  /// No-op on non-web platforms.
  void prevPage() {}

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_off_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Music notation rendering\nis only available on Web.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
