/// Layout engine for computing score layout
/// Pure Dart implementation with no Flutter dependencies

import 'models.dart';

/// Compute complete page layout
PageLayout computePageLayout(
  Score score,
  int partIndex,
  int pageNumber,
  LayoutConfig config,
) {
  if (score.totalMeasures == 0) {
    return _emptyPageLayout(pageNumber, config);
  }

  if (pageNumber < 0 || pageNumber >= getTotalPages(score.totalMeasures, config)) {
    return _emptyPageLayout(pageNumber, config);
  }

  // Calculate measure ranges for pagination
  final measuresPerPage = config.measuresPerSystem * config.systemsPerPage;
  final startMeasure = pageNumber * measuresPerPage;
  final endMeasure = ((pageNumber + 1) * measuresPerPage)
      .clamp(0, score.totalMeasures)
      .toInt();

  // Get part info
  final part = partIndex < score.parts.length ? score.parts[partIndex] : null;
  if (part == null) {
    return _emptyPageLayout(pageNumber, config);
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
  final usableHeight =
      config.pageHeight - config.topMargin - config.bottomMargin;

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
      score,
      systemMeasures,
      systemIndex,
      currentY,
      usableWidth,
      part.clef,
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
    totalPages: getTotalPages(score.totalMeasures, config),
    canvasWidth: config.pageWidth,
    canvasHeight: config.pageHeight,
    systems: systems,
    pageMargins: margins,
    config: config,
  );
}

/// Compute single system (row of measures)
SystemLayout _computeSystemLayout(
  Score score,
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
    if (measureIdx < score.measures.length) {
      final measure = score.measures[measureIdx];
      double measureDuration = 0.0;

      // Sum all note and rest durations
      for (final note in measure.notes) {
        measureDuration += note.duration;
      }
      for (final rest in measure.rests) {
        measureDuration += rest.duration;
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
    if (measureIdx >= score.measures.length) break;

    final measure = score.measures[measureIdx];
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
  Measure measure,
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

  // Add notes
  for (final note in measure.notes) {
    final effectiveStaff = (note.staff >= staveCount) ? staveCount - 1 : note.staff;
    final noteY = _pitchToStaffY(note.step, note.octave, clefType, effectiveStaff, config);

    final noteLayout = NoteLayout(
      elementId: note.id,
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
      stemDirection: note.octave >= 5 ? 'down' : 'up',
      dots: note.dots,
      accidental: note.accidental,
      isInChord: note.isInChord,
      hasArticulation: note.hasArticulation,
      hasDynamic: note.hasDynamic,
    );

    noteLayouts.add(noteLayout);
  }

  // Add rests
  for (final rest in measure.rests) {
    final effectiveStaff = (rest.staff >= staveCount) ? staveCount - 1 : rest.staff;
    // Rests typically centered on middle line of staff
    final staveLayout =
        _buildStaves(clefType, yPosition, config)[effectiveStaff];
    final restY = staveLayout.bounds.y + (config.staffHeight / 2);

    final restLayout = NoteLayout(
      elementId: rest.id,
      pitch: Pitch(step: 'B', octave: 4),
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
  }

  final bounds = Rect(
    x: xPosition,
    y: yPosition,
    width: width,
    height: config.systemHeight,
  );

  // Build staves for bounds
  final staves = _buildStaves(clefType, yPosition, config);

  return MeasureLayout(
    measureNumber: measureIndex,
    bounds: bounds,
    notes: noteLayouts,
    staves: staves,
    timeSignature: measure.timeSignature,
    keySignature: measure.keySignature,
    hasRepeatStart: measure.hasRepeatStart,
    hasRepeatEnd: measure.hasRepeatEnd,
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
  // MIDI values: C=0, D=2, E=4, F=5, G=7, A=9, B=11
  final stepValues = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
  final midiNote = (octave + 1) * 12 + (stepValues[step] ?? 0);

  // Determine reference MIDI for bottom line based on clef
  int referenceLineMidi;

  if (clefType == 'treble') {
    referenceLineMidi = 52; // E4
  } else if (clefType == 'bass') {
    referenceLineMidi = 43; // G2
  } else if (clefType == 'alto') {
    referenceLineMidi = 48; // C4
  } else if (clefType == 'tenor') {
    referenceLineMidi = 45; // A3
  } else {
    // Grand staff: use treble for upper staff, bass for lower
    if (staffIndex == 0) {
      referenceLineMidi = 52; // E4 treble
    } else {
      referenceLineMidi = 43; // G2 bass
    }
  }

  // Calculate semitones from reference line
  final semitoneDistance = referenceLineMidi - midiNote;

  // Each staff line/space is a whole step (2 semitones)
  // Bottom line is Y=0, moving up is negative Y
  final lineDistance = semitoneDistance / 2.0;

  // Build staves to get Y origin
  final staves = _buildStaves(clefType, 0, config);
  if (staffIndex >= staves.length) return 0;

  final stave = staves[staffIndex];
  final staffBottomY = stave.bounds.y + config.staffHeight;
  final staffLineSpacing = config.staffLineSpacing;

  return staffBottomY - (lineDistance * staffLineSpacing);
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
