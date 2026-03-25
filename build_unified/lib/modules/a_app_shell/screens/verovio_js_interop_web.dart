/// Web implementation: calls Verovio JS functions defined in index.html
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

bool verovioIsReady() {
  try {
    final result = js.context.callMethod('verovioIsReady');
    return result == true;
  } catch (_) {
    return false;
  }
}

String verovioLoadScore(String musicXml) {
  try {
    final result = js.context.callMethod('verovioLoadScore', [musicXml]);
    return result?.toString() ?? '';
  } catch (e) {
    return '<p>Error: $e</p>';
  }
}

String verovioRenderPage(int page) {
  try {
    final result = js.context.callMethod('verovioRenderPage', [page]);
    return result?.toString() ?? '';
  } catch (e) {
    return '';
  }
}

int verovioGetPageCount() {
  try {
    final result = js.context.callMethod('verovioGetPageCount');
    return (result as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
}

String verovioGetMidi() {
  try {
    return js.context.callMethod('verovioGetMidi')?.toString() ?? '';
  } catch (_) {
    return '';
  }
}

String verovioGetTimemap() {
  try {
    return js.context.callMethod('verovioGetTimemap')?.toString() ?? '[]';
  } catch (_) {
    return '[]';
  }
}

void verovioPlay() {
  try {
    js.context.callMethod('verovioPlay');
  } catch (_) {}
}

void verovioStop() {
  try {
    js.context.callMethod('verovioStop');
  } catch (_) {}
}

void verovioPause() {
  try {
    js.context.callMethod('verovioPause');
  } catch (_) {}
}

void verovioSetTempo(int bpm) {
  try {
    js.context.callMethod('verovioSetTempo', [bpm]);
  } catch (_) {}
}

String verovioGetPlaybackState() {
  try {
    return js.context.callMethod('verovioGetPlaybackState')?.toString() ?? 'stopped';
  } catch (_) {
    return 'stopped';
  }
}

/// Renders SVG string as an HtmlElementView widget
Widget renderSvgWidget(String svgContent) {
  final viewId = 'svg-view-${svgContent.hashCode}';

  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int id) {
      final div = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'auto'
        ..style.padding = '8px'
        ..style.boxSizing = 'border-box'
        ..setInnerHtml(svgContent, treeSanitizer: html.NodeTreeSanitizer.trusted);
      // Make SVG responsive
      final svgs = div.querySelectorAll('svg');
      for (final svg in svgs) {
        (svg as html.Element).style.width = '100%';
        svg.style.height = 'auto';
      }
      return div;
    },
  );

  return HtmlElementView(viewType: viewId);
}
