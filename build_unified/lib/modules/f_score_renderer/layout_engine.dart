/// Layout engine for computing score layout
/// Pure Dart implementation with no Flutter dependencies

import 'models.dart';
import '../e_music_normalizer/score_json.dart' as score_model;

/// Convert noteType string to fractional duration (fraction of whole note)
double _noteTypeFraction(String noteType) {
  return switch (noteType) {
    'whole' => 1.0,
    'half' => 0.5,
    'quarter' => 0.25,
    'eighth' => 0.125,
    'sixteenth' => 0.0625,
    'thirty-second' => 0.03125,
    _ => 0.25,
  };
}

/// Derive accidental string from alter value
String? _alterToAccidental(int alter) {
  return switch (alter) {
    -2 => 'bb',
    -1 => 'b',
    1 => '#',
    2 => '##',
    _ => null,
  };
}

/// Compute complete page layout
PageLayout computePageLayout(
  score_model.Score score,
  int partIndex,
  int pageNumber,
  LayoutConfig config,
) {
  // Get part
  if (partIndex < 0 || partIndex >= score.parts.length) {
    return _emptyPageLayout(pageNumber, config);
  }

  final part = score.parts[partIndex];
  final totalMeasures = part.measures.length;

  if (totalMeasures == 0) {
    return _emptyPageLayout(pageNumber, config);
  }

  if (pageNumber < 0 || pageNumber >= getTotalPages(totalMeasures, config)) {
    return _emptyPageLayout(pageNumber, config);
  }

  // Calculate measure ranges for pagination
  final measuresPerPage = config.measuresPerSystem * config.systemsPerPage;
  final startMeasure = pageNumber * measuresPerPage;
  final endMeasure = ((pageNumber + 1) * measuresPerPage)
      .clamp(0, totalMeasures)
      .toInt();

  // Determine clef from first measure
  String clefType = 'treble';
  if (part.measures.isNotEmpty && part.measures[0].clefs.isNotEmpty) {
    final sign = part.measures[0].clefs[0].sign;
    clefType = switch (sign) {
      'G' => 'treble',
      'F' => 'bass',
      'C' => 'alto',
      _ => 'treble',
    };
  }

  // Build systems for this page
  final systems = <SystemLayout>[];
  final margins = PageMargins(
    top: config.topMargin,
    bottom: config.bottomMargin,
    left: config.leftMargin,
    right: config.rightMargin,
  );

  final usableWidth = config.pageWidth - config.leftMargin - config.rightMargin;

  double currentY = config.topMargin;
  int systemIndex = 0;

  for (int measureIdx = startMeasure; measureIdx < endMeasure;) {
    final systemMeasures = <int>[];
    final systemEndMeasure = (measureIdx + config.measuresPerSystem)
        .clamp(0, endMeasure)
        .toInt();

    for (int m = measureIdx; m < systemEndMeasure; m++) {
      systemMeasures.add(m);
    }

    if (systemMeasures.isEmpty) break;

    // Calculate proportional widths for measures in this system
    final systemLayout = _computeSystemLayout(
      part,
      systemMeasures,
      systemIndex,
      currentY,
      usableWidth,
      clefType,
      config,
    );

    systems.add(systemLayout);
    currentY += systemLayout.height + 20.0; // 20px gap between systems
    measureIdx = systemEndMeasure;
    systemIndex++;

    if (systemIndex >= config.systemsPerPage) break;
  }

  return PageLayout(
    pageNumber: pageNumber,
    totalPages: getTotalPages(totalMeasures, config),
    canvasWidth: config.pageWidth,
    canvasHeight: config.pageHeight,
    systems: systems,
    pageMargins: margins,
    config: config,
  );
}

/// Compute single system (row of measures)
SystemLayout _computeSystemLayout(
  score_model.Part part,
  List<int> measureIndices,
  int systemNumber,
  double yPosition,
  double usableWidth,
  String clefType,
  LayoutConfig config,
) {
  // Calculate total duration of measures in system for proportional spacing
  double totalDuration = 0.0;
  final measureDurations = <int, double>{};

  for (final measureIdx in measureIndices) {
    if (measureIdx < part.measures.length) {
      final measure = part.measures[measureIdx];
      double measureDuration = 0.0;

      // Sum all note and rest durations using element types
      for (final element in measure.elements) {
        if (element is score_model.NoteElement) {
          measureDuration += _noteTypeFraction(element.noteType);
        } else if (element is score_model.RestElement) {
          measureDuration += _noteTypeFraction(element.noteType);
        }
      }

      // Default to 1.0 (4/4) if empty
      if (measureDuration == 0.0) measureDuration = 1.0;

      measureDurations[measureIdx] = measureDuration;
      totalDuration += measureDuration;
    }
  }

  // Prevent division by zero
  if (totalDuration == 0.0) totalDuration = 1.0;

  // Create measure layouts with proportional widths
  final measures = <MeasureLayout>[];
  double currentX = config.leftMargin;

  for (final measureIdx in measureIndices) {
    if (measureIdx >= part.measures.length) break;

    final measure = part.measures[measureIdx];
    final proportionalWidth =
        (measureDurations[measureIdx] ?? 1.0) / totalDuration * usableWidth;

    final measureLayout = _computeMeasureLayout(
      measure,
      measureIdx,
      currentX,
      yPosition,
      proportionalWidth,
      clefType,
      config,
    );

    measures.add(measureLayout);
    currentX += proportionalWidth;
  }

  // Build staves for system
  final staves = _buildStaves(clefType, yPosition, config);

  // Calculate system height
  final staffCount = staves.length;
  double systemHeight = (staffCount * config.systemHeight) + 20.0;

  // Account for grand staff gap
  if (clefType.contains('grand') || clefType == 'treble_bass') {
    systemHeight += 30.0; // Extra gap between treble and bass staves
  }

  return SystemLayout(
    systemNumber: systemNumber,
    yPosition: yPosition,
    height: systemHeight,
    measures: measures,
    startMeasure: measureIndices.first,
    endMeasure: measureIndices.last,
    staves: staves,
  );
}

/// Build staves for a system
List<StaveLayout> _buildStaves(
  String clefType,
  double yPosition,
  LayoutConfig config,
) {
  final staves = <StaveLayout>[];
  double currentY = yPosition;

  if (clefType == 'grand' || clefType == 'treble_bass') {
    // Treble staff
    final trebleBounds = Rect(
      x: 0,
      y: currentY,
      width: config.pageWidth,
      height: config.staffHeight,
    );
    staves.add(StaveLayout(
      clefType: 'treble',
      bounds: trebleBounds,
      staffIndex: 0,
      lineSpacing: config.staffLineSpacing,
    ));
    currentY += config.staffHeight + 30.0; // Gap for grand staff

    // Bass staff
    final bassBounds = Rect(
      x: 0,
      y: currentY,
      width: config.pageWidth,
      height: config.staffHeight,
    );
    staves.add(StaveLayout(
      clefType: 'bass',
      bounds: bassBounds,
      staffIndex: 1,
      lineSpacing: config.staffLineSpacing,
    ));
  } else {
    // Single staff
    final bounds = Rect(
      x: 0,
      y: currentY,
      width: config.pageWidth,
      height: config.staffHeight,
    );
    staves.add(StaveLayout(
      clefType: clefType,
      bounds: bounds,
      staffIndex: 0,
      lineSpacing: config.staffLineSpacing,
    ));
  }

  return staves;
}

/// Compute single measure layout
MeasureLayout _computeMeasureLayout(
  score_model.Measure measure,
  int measureIndex,
  double xPosition,
  double yPosition,
  double width,
  String clefType,
  LayoutConfig config,
) {
  // Create note layouts
  final noteLayouts = <NoteLayout>[];
  final staveCount = clefType == 'grand' || clefType == 'treble_bass' ? 2 : 1;

  // Process notes
  int noteIdx = 0;
  for (final note in measure.elements.whereType<score_model.NoteElement>()) {
    final effectiveStaff = (note.staff >= staveCount) ? staveCount - 1 : note.staff;
    final noteY = _pitchToStaffY(note.pitch.step, note.pitch.octave, clefType, effectiveStaff, config);

    final noteLayout = NoteLayout(
      elementId: 'note_${measureIndex}_$noteIdx',
      pitch: note.pitch,
      noteType: note.noteType,
      bounds: Rect(
        x: xPosition + width * 0.2,
        y: noteY,
        width: 8.0,
        height: 10.0,
      ),
      staff: effectiveStaff,
      voice: note.voice,
      isRest: false,
      stemDirection: note.pitch.octave >= 5 ? 'down' : 'up',
      dots: note.dots,
      accidental: _alterToAccidental(note.pitch.alter),
      isInChord: note.isChordMember,
      hasArticulation: note.articulations.isNotEmpty,
      hasDynamic: note.dynamicMarking != null,
    );

    noteLayouts.add(noteLayout);
    noteIdx++;
  }

  // Process rests
  int restIdx = 0;
  for (final rest in measure.elements.whereType<score_model.RestElement>()) {
    final effectiveStaff = (rest.staff >= staveCount) ? staveCount - 1 : rest.staff;
    // Rests typically centered on middle line of staff
    final staveLayout =
        _buildStaves(clefType, yPosition, config)[effectiveStaff];
    final restY = staveLayout.bounds.y + (config.staffHeight / 2);

    final restLayout = NoteLayout(
      elementId: 'rest_${measureIndex}_$restIdx',
      pitch: score_model.Pitch(step: 'B', octave: 4),
      noteType: rest.noteType,
      bounds: Rect(
        x: xPosition + width * 0.4,
        y: restY,
        width: 6.0,
        height: 8.0,
      ),
      staff: effectiveStaff,
      voice: rest.voice,
      isRest: true,
      dots: rest.dots,
    );

    noteLayouts.add(restLayout);
    restIdx++;
  }

  final bounds = Rect(
    x: xPosition,
    y: yPosition,
    width: width,
    height: config.systemHeight,
  );

  // Build staves for bounds
  final staves = _buildStaves(clefType, yPosition, config);

  // Derive key signature string
  String? keySignatureStr;
  if (measure.keySignature != null) {
    keySignatureStr = '${measure.keySignature!.step} ${measure.keySignature!.tonality}';
  }

  return MeasureLayout(
    measureNumber: measureIndex,
    bounds: bounds,
    notes: noteLayouts,
    staves: staves,
    timeSignature: measure.timeSignature,
    keySignature: keySignatureStr,
    hasRepeatStart: measure.repeatStart,
    hasRepeatEnd: measure.repeatEnd,
    rehearsalMark: measure.rehearsalMark,
    startMeasure: measureIndex,
    endMeasure: measureIndex,
  );
}

/// Convert MIDI note to staff Y position
/// Correct music theory: treble clef E4=bottom line, bass clef G2=bottom line
double _pitchToStaffY(
  String step,
  int octave,
  String clefType,
  int staffIndex,
  LayoutConfig config,
) {
  // Diatonic step index within an octave (C=0, D=1, E=2, F=3, G=4, A=5, B=6)
  final diatonicSteps = {'C': 0, 'D': 1, 'E': 2, 'F': 3, 'G': 4, 'A': 5, 'B': 6};
  final noteStep = diatonicSteps[step] ?? 0;

  // Total diatonic position from C0 (absolute diatonic index)
  final notePos = octave * 7 + noteStep;

  // Reference: bottom line of staff in diatonic position
  // Treble clef: bottom line = E4 = 4*7+2 = 30
  // Bass clef: bottom line = G2 = 2*7+4 = 18
  int referencePos;
  if (clefType == 'treble') {
    referencePos = 30; // E4
  } else if (clefType == 'bass') {
    referencePos = 18; // G2
  } else if (clefType == 'alto') {
    referencePos = 24; // B3 (middle line = C4)
  } else if (clefType == 'tenor') {
    referencePos = 22; // A3
  } else {
    referencePos = (staffIndex == 0) ? 30 : 18;
  }

  // Distance in diatonic steps from bottom line
  // Positive = above bottom line, negative = below
  final stepsFromBottom = (notePos - referencePos).toDouble();

  // Build staves to get Y origin
  final staves = _buildStaves(clefType, 0, config);
  if (staffIndex >= staves.length) return 0;

  final stave = staves[staffIndex];
  final staffBottomY = stave.bounds.y + config.staffHeight;
  final halfSpacing = config.staffLineSpacing / 2.0;

  // Each diatonic step = half a staff line spacing
  // Moving up = negative Y (screen coordinates)
  return staffBottomY - (stepsFromBottom * halfSpacing);
}

/// Get total number of pages
int getTotalPages(int totalMeasures, LayoutConfig config) {
  if (totalMeasures == 0) return 1;
  final measuresPerPage = config.measuresPerSystem * config.systemsPerPage;
  return ((totalMeasures + measuresPerPage - 1) / measuresPerPage).ceil();
}

/// Get page for measure
int getPageForMeasure(int measure, LayoutConfig config, int totalMeasures) {
  if (measure < 0 || measure >= totalMeasures) return 0;
  final measuresPerPage = config.measuresPerSystem * config.systemsPerPage;
  return (measure / measuresPerPage).floor();
}

/// Get measure range for page
(int, int) getMeasureRange(int page, LayoutConfig config, int totalMeasures) {
  final measuresPerPage = config.measuresPerSystem * config.systemsPerPage;
  final start = page * measuresPerPage;
  final end = ((page + 1) * measuresPerPage).clamp(0, totalMeasures);
  return (start, end);
}

/// Create empty page layout
PageLayout _emptyPageLayout(int pageNumber, LayoutConfig config) {
  return PageLayout(
    pageNumber: pageNumber,
    totalPages: 1,
    canvasWidth: config.pageWidth,
    canvasHeight: config.pageHeight,
    systems: [],
    pageMargins: PageMargins(
      top: config.topMargin,
      bottom: config.bottomMargin,
      left: config.leftMargin,
      right: config.rightMargin,
    ),
    config: config,
  );
}
