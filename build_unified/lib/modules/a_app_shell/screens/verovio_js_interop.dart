/// Stub implementation for non-web platforms
import 'package:flutter/material.dart';

bool verovioIsReady() => false;
String verovioLoadScore(String musicXml) => '';
String verovioRenderPage(int page) => '';
int verovioGetPageCount() => 0;
Widget renderSvgWidget(String svgContent) =>
    const Center(child: Text('Not available on this platform'));

String verovioGetMidi() => '';
String verovioGetTimemap() => '[]';
void verovioPlay() {}
void verovioStop() {}
void verovioPause() {}
void verovioSetTempo(int bpm) {}
String verovioGetPlaybackState() => 'stopped';
