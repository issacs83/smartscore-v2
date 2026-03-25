/// Flutter Web implementation of VerovioView.
/// Uses dart:html IFrameElement + HtmlElementView to embed verovio.html.
// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Renders MusicXML using the Verovio WASM engraving engine (Flutter Web).
///
/// Embeds `verovio.html` as an iframe via [HtmlElementView] and communicates
/// with it using `window.postMessage`:
///
///   Flutter -> iframe:
///     `{ "type": "loadScore", "xml": "<...>" }`
///     `{ "type": "nextPage" }`
///     `{ "type": "prevPage" }`
///
///   iframe -> Flutter:
///     `{ "type": "pageChanged", "current": N, "total": M }`
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
  late final String _viewId;
  html.IFrameElement? _iframe;
  bool _iframeLoaded = false;
  html.EventListener? _messageListener;

  @override
  void initState() {
    super.initState();
    _viewId = 'verovio-iframe-${DateTime.now().microsecondsSinceEpoch}';
    _buildIframe();
  }

  @override
  void didUpdateWidget(VerovioView old) {
    super.didUpdateWidget(old);
    if (old.musicXml != widget.musicXml) {
      _sendLoadScore();
    }
  }

  @override
  void dispose() {
    if (_messageListener != null) {
      html.window.removeEventListener('message', _messageListener!);
      _messageListener = null;
    }
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Setup
  // ------------------------------------------------------------------

  void _buildIframe() {
    final iframe = html.IFrameElement()
      ..src = 'verovio.html'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';

    iframe.onLoad.listen((_) {
      _iframeLoaded = true;
      _sendLoadScore();
    });

    _iframe = iframe;

    // Register the view factory only once per unique viewId.
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int id) => iframe,
    );

    // Receive messages from the iframe.
    _messageListener = (html.Event event) {
      if (event is html.MessageEvent) {
        _onIframeMessage(event);
      }
    };
    html.window.addEventListener('message', _messageListener!);
  }

  // ------------------------------------------------------------------
  // postMessage helpers
  // ------------------------------------------------------------------

  void _sendLoadScore() {
    if (!_iframeLoaded || _iframe == null) return;
    final payload = jsonEncode({'type': 'loadScore', 'xml': widget.musicXml});
    _iframe!.contentWindow?.postMessage(payload, '*');
  }

  void _send(String type) {
    if (!_iframeLoaded || _iframe == null) return;
    _iframe!.contentWindow?.postMessage(jsonEncode({'type': type}), '*');
  }

  void _onIframeMessage(html.MessageEvent event) {
    try {
      final raw = event.data;
      if (raw == null) return;
      final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
      if (data['type'] == 'pageChanged') {
        final current = (data['current'] as num).toInt();
        final total = (data['total'] as num).toInt();
        widget.onPageChanged?.call(current, total);
      }
    } catch (_) {
      // Ignore messages from other origins or malformed payloads.
    }
  }

  // ------------------------------------------------------------------
  // Public API (called via GlobalKey)
  // ------------------------------------------------------------------

  void nextPage() => _send('nextPage');
  void prevPage() => _send('prevPage');

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
