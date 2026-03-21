/// Hit testing for interactive score rendering
/// Pure Dart implementation with no Flutter dependencies

import 'models.dart';

/// Perform hit test on page layout
HitTestResult? hitTest(double x, double y, PageLayout layout) {
  // Search in order: note > rest > barline > measure > staff > empty

  // Check notes first (most specific)
  for (int sysIdx = 0; sysIdx < layout.systems.length; sysIdx++) {
    final system = layout.systems[sysIdx];

    for (final measure in system.measures) {
      for (final note in measure.notes) {
        if (!note.isRest && note.bounds.contains(x, y)) {
          return HitTestResult(
            type: HitType.note,
            measureNumber: measure.measureNumber,
            noteId: note.elementId,
            pitch: note.pitch,
            staffIndex: note.staff,
            systemIndex: sysIdx,
            confidence: 1.0,
          );
        }
      }

      // Check rests
      for (final note in measure.notes) {
        if (note.isRest && note.bounds.contains(x, y)) {
          return HitTestResult(
            type: HitType.rest,
            measureNumber: measure.measureNumber,
            noteId: note.elementId,
            staffIndex: note.staff,
            systemIndex: sysIdx,
            confidence: 1.0,
          );
        }
      }
    }
  }

  // Check measures (less specific)
  for (int sysIdx = 0; sysIdx < layout.systems.length; sysIdx++) {
    final system = layout.systems[sysIdx];

    for (final measure in system.measures) {
      if (measure.bounds.contains(x, y)) {
        return HitTestResult(
          type: HitType.measure,
          measureNumber: measure.measureNumber,
          systemIndex: sysIdx,
          confidence: 1.0,
        );
      }
    }
  }

  // Check staves
  for (int sysIdx = 0; sysIdx < layout.systems.length; sysIdx++) {
    final system = layout.systems[sysIdx];

    for (int staffIdx = 0; staffIdx < system.staves.length; staffIdx++) {
      final stave = system.staves[staffIdx];
      // Extend staff bounds horizontally to full usable width
      final extendedBounds = Rect(
        x: layout.pageMargins.left,
        y: stave.bounds.y,
        width: layout.canvasWidth - layout.pageMargins.left - layout.pageMargins.right,
        height: stave.bounds.height,
      );

      if (extendedBounds.contains(x, y)) {
        return HitTestResult(
          type: HitType.staff,
          staffIndex: staffIdx,
          systemIndex: sysIdx,
          confidence: 0.5,
        );
      }
    }
  }

  return HitTestResult(
    type: HitType.empty,
    confidence: 0.0,
  );
}

/// Check if point is on a barline
bool _isOnBarline(double x, double y, PageLayout layout, double tolerance) {
  for (final system in layout.systems) {
    for (final measure in system.measures) {
      // Check left barline
      final leftBarX = measure.bounds.x;
      if ((x - leftBarX).abs() < tolerance &&
          y >= measure.bounds.y &&
          y <= measure.bounds.y + measure.bounds.height) {
        return true;
      }

      // Check right barline
      final rightBarX = measure.bounds.x + measure.bounds.width;
      if ((x - rightBarX).abs() < tolerance &&
          y >= measure.bounds.y &&
          y <= measure.bounds.y + measure.bounds.height) {
        return true;
      }
    }
  }
  return false;
}

/// Get hitTest result with additional beat information
HitTestResult? hitTestWithBeat(
  double x,
  double y,
  PageLayout layout,
  Map<int, String> measureTimeSigs,
) {
  final result = hitTest(x, y, layout);
  if (result == null) return null;

  // Calculate beat position within measure
  if (result.measureNumber != null) {
    final timeSig = measureTimeSigs[result.measureNumber ?? 0] ?? '4/4';
    final parts = timeSig.split('/');
    if (parts.length == 2) {
      final numerator = int.tryParse(parts[0]) ?? 4;

      // Find measure in layout
      for (final system in layout.systems) {
        for (final measure in system.measures) {
          if (measure.measureNumber == result.measureNumber) {
            final measureWidth = measure.bounds.width;
            final relativeX = x - measure.bounds.x;
            final beatPosition = (relativeX / measureWidth) * numerator;

            return HitTestResult(
              type: result.type,
              measureNumber: result.measureNumber,
              noteId: result.noteId,
              pitch: result.pitch,
              beat: beatPosition.clamp(0.0, numerator.toDouble()),
              staffIndex: result.staffIndex,
              systemIndex: result.systemIndex,
              confidence: result.confidence,
            );
          }
        }
      }
    }
  }

  return result;
}

/// Get all notes intersecting with a region
List<NoteLayout> notesInRegion(
  Rect region,
  PageLayout layout,
) {
  final notes = <NoteLayout>[];

  for (final system in layout.systems) {
    for (final measure in system.measures) {
      for (final note in measure.notes) {
        if (note.bounds.intersects(region)) {
          notes.add(note);
        }
      }
    }
  }

  return notes;
}

/// Get all measures intersecting with a region
List<MeasureLayout> measuresInRegion(
  Rect region,
  PageLayout layout,
) {
  final measures = <MeasureLayout>[];

  for (final system in layout.systems) {
    for (final measure in system.measures) {
      if (measure.bounds.intersects(region)) {
        measures.add(measure);
      }
    }
  }

  return measures;
}

/// Find note at specific beat in measure
NoteLayout? noteAtBeat(
  int measureNumber,
  double beat,
  PageLayout layout,
) {
  for (final system in layout.systems) {
    for (final measure in system.measures) {
      if (measure.measureNumber == measureNumber) {
        // Find note closest to beat position
        NoteLayout? closest;
        double closestDistance = double.infinity;

        for (final note in measure.notes) {
          if (note.isRest) continue;

          // Estimate note position from measure width
          final noteBeat = (note.bounds.x - measure.bounds.x) / measure.bounds.width;
          final distance = (noteBeat - beat).abs();

          if (distance < closestDistance) {
            closest = note;
            closestDistance = distance;
          }
        }

        return closest;
      }
    }
  }

  return null;
}
