/// Pure Dart models for score rendering (no Flutter dependencies)

import '../e_music_normalizer/score_json.dart' as score_model;

/// Simple rectangle model (no Flutter dependency)
class Rect {
  final double x;
  final double y;
  final double width;
  final double height;

  Rect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  bool contains(double px, double py) {
    return px >= x && px <= x + width && py >= y && py <= y + height;
  }

  bool intersects(Rect other) {
    return !(x + width < other.x ||
        x > other.x + other.width ||
        y + height < other.y ||
        y > other.y + other.height);
  }

  @override
  String toString() => 'Rect(x: $x, y: $y, w: $width, h: $height)';
}

/// Layout configuration for rendering
class LayoutConfig {
  final int measuresPerSystem;
  final int systemsPerPage;
  final double staffLineSpacing; // pixels between staff lines
  final double pageWidth; // pixels
  final double pageHeight; // pixels
  final double leftMargin;
  final double rightMargin;
  final double topMargin;
  final double bottomMargin;
  final double zoom; // 0.5 to 4.0
  final bool darkMode;
  final String paperSize; // "A4" or "Letter"
  final bool showMeasureNumbers;
  final bool showRehearsalMarks;
  final String currentPositionColor;
  final double currentPositionOpacity;

  LayoutConfig({
    this.measuresPerSystem = 4,
    this.systemsPerPage = 6,
    this.staffLineSpacing = 12.0,
    this.pageWidth = 816.0, // A4 at 96dpi
    this.pageHeight = 1056.0,
    this.leftMargin = 40.0,
    this.rightMargin = 40.0,
    this.topMargin = 40.0,
    this.bottomMargin = 40.0,
    this.zoom = 1.0,
    this.darkMode = false,
    this.paperSize = "A4",
    this.showMeasureNumbers = true,
    this.showRehearsalMarks = true,
    this.currentPositionColor = "blue",
    this.currentPositionOpacity = 0.5,
  });

  double get staffHeight => staffLineSpacing * 4; // 4 spaces between 5 lines
  double get systemHeight => staffHeight * 1.5; // Add space between staves

  LayoutConfig copyWith({
    int? measuresPerSystem,
    int? systemsPerPage,
    double? staffLineSpacing,
    double? pageWidth,
    double? pageHeight,
    double? leftMargin,
    double? rightMargin,
    double? topMargin,
    double? bottomMargin,
    double? zoom,
    bool? darkMode,
    String? paperSize,
    bool? showMeasureNumbers,
    bool? showRehearsalMarks,
    String? currentPositionColor,
    double? currentPositionOpacity,
  }) {
    return LayoutConfig(
      measuresPerSystem: measuresPerSystem ?? this.measuresPerSystem,
      systemsPerPage: systemsPerPage ?? this.systemsPerPage,
      staffLineSpacing: staffLineSpacing ?? this.staffLineSpacing,
      pageWidth: pageWidth ?? this.pageWidth,
      pageHeight: pageHeight ?? this.pageHeight,
      leftMargin: leftMargin ?? this.leftMargin,
      rightMargin: rightMargin ?? this.rightMargin,
      topMargin: topMargin ?? this.topMargin,
      bottomMargin: bottomMargin ?? this.bottomMargin,
      zoom: zoom ?? this.zoom,
      darkMode: darkMode ?? this.darkMode,
      paperSize: paperSize ?? this.paperSize,
      showMeasureNumbers: showMeasureNumbers ?? this.showMeasureNumbers,
      showRehearsalMarks: showRehearsalMarks ?? this.showRehearsalMarks,
      currentPositionColor:
          currentPositionColor ?? this.currentPositionColor,
      currentPositionOpacity:
          currentPositionOpacity ?? this.currentPositionOpacity,
    );
  }
}

/// Staff layout information
class StaveLayout {
  final String clefType; // treble, bass, alto, tenor
  final Rect bounds;
  final int staffIndex; // 0-indexed within system
  final double lineSpacing;

  StaveLayout({
    required this.clefType,
    required this.bounds,
    required this.staffIndex,
    required this.lineSpacing,
  });
}

/// Note layout information
class NoteLayout {
  final String elementId;
  final score_model.Pitch pitch;
  final String noteType; // whole, half, quarter, eighth, sixteenth
  final Rect bounds; // note head bounds
  final int staff; // 0-indexed within part
  final int voice; // 0-indexed
  final bool isRest;
  final String stemDirection; // up, down, none
  final Rect? stemBounds;
  final Rect? beamBounds;
  final int dots;
  final String? accidental; // #, b, ♮
  final bool isInChord;
  final bool hasArticulation;
  final bool hasDynamic;

  NoteLayout({
    required this.elementId,
    required this.pitch,
    required this.noteType,
    required this.bounds,
    required this.staff,
    required this.voice,
    this.isRest = false,
    this.stemDirection = 'none',
    this.stemBounds,
    this.beamBounds,
    this.dots = 0,
    this.accidental,
    this.isInChord = false,
    this.hasArticulation = false,
    this.hasDynamic = false,
  });
}

/// Measure layout information
class MeasureLayout {
  final int measureNumber;
  final Rect bounds;
  final List<NoteLayout> notes;
  final List<StaveLayout> staves;
  final String? timeSignature;
  final String? keySignature;
  final bool hasRepeatStart;
  final bool hasRepeatEnd;
  final String? rehearsalMark;
  final int startMeasure;
  final int endMeasure;

  MeasureLayout({
    required this.measureNumber,
    required this.bounds,
    required this.notes,
    required this.staves,
    this.timeSignature,
    this.keySignature,
    this.hasRepeatStart = false,
    this.hasRepeatEnd = false,
    this.rehearsalMark,
    required this.startMeasure,
    required this.endMeasure,
  });
}

/// System layout information (row of measures)
class SystemLayout {
  final int systemNumber;
  final double yPosition;
  final double height;
  final List<MeasureLayout> measures;
  final int startMeasure;
  final int endMeasure;
  final List<StaveLayout> staves;

  SystemLayout({
    required this.systemNumber,
    required this.yPosition,
    required this.height,
    required this.measures,
    required this.startMeasure,
    required this.endMeasure,
    required this.staves,
  });
}

/// Complete page layout
class PageLayout {
  final int pageNumber;
  final int totalPages;
  final double canvasWidth;
  final double canvasHeight;
  final List<SystemLayout> systems;
  final PageMargins pageMargins;
  final LayoutConfig config;

  PageLayout({
    required this.pageNumber,
    required this.totalPages,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.systems,
    required this.pageMargins,
    required this.config,
  });

  bool get isEmpty => systems.isEmpty;
}

class PageMargins {
  final double top;
  final double bottom;
  final double left;
  final double right;

  PageMargins({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });
}

/// Hit test result
enum HitType { note, rest, measure, staff, barline, empty }

class HitTestResult {
  final HitType type;
  final int? measureNumber;
  final String? noteId;
  final score_model.Pitch? pitch;
  final double? beat;
  final int? staffIndex;
  final int? systemIndex;
  final double confidence;

  HitTestResult({
    required this.type,
    this.measureNumber,
    this.noteId,
    this.pitch,
    this.beat,
    this.staffIndex,
    this.systemIndex,
    this.confidence = 1.0,
  });
}

/// Abstract render command
sealed class RenderCommand {}

class DrawLine extends RenderCommand {
  final double x1, y1, x2, y2;
  final double strokeWidth;
  final String color; // hex or named

  DrawLine({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.strokeWidth = 1.0,
    this.color = '#000000',
  });
}

class DrawOval extends RenderCommand {
  final double cx, cy, rx, ry;
  final double rotation;
  final bool filled;
  final double strokeWidth;
  final String color;

  DrawOval({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    this.rotation = 0.0,
    this.filled = false,
    this.strokeWidth = 1.0,
    this.color = '#000000',
  });
}

class DrawRect extends RenderCommand {
  final double x, y, width, height;
  final bool filled;
  final double strokeWidth;
  final String color;
  final double opacity;

  DrawRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.filled = false,
    this.strokeWidth = 1.0,
    this.color = '#000000',
    this.opacity = 1.0,
  });
}

class DrawText extends RenderCommand {
  final String text;
  final double x, y;
  final double fontSize;
  final String color;
  final String fontWeight; // normal, bold

  DrawText({
    required this.text,
    required this.x,
    required this.y,
    this.fontSize = 12.0,
    this.color = '#000000',
    this.fontWeight = 'normal',
  });
}

class DrawPath extends RenderCommand {
  final List<(double, double)> points; // list of (x, y) tuples
  final double strokeWidth;
  final String color;
  final bool filled;

  DrawPath({
    required this.points,
    this.strokeWidth = 1.0,
    this.color = '#000000',
    this.filled = false,
  });
}

/// Render state for command generation
class RenderState {
  final int? currentMeasure;
  final double measureProgress; // 0.0-1.0
  final String highlightColor;
  final bool darkMode;

  RenderState({
    this.currentMeasure,
    this.measureProgress = 0.0,
    this.highlightColor = 'blue',
    this.darkMode = false,
  });
}

