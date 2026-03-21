import 'score_json.dart';

/// Validation report for a Score
class ValidationReport {
  final List<ValidationIssue> errors;
  final List<ValidationIssue> warnings;
  final double score;

  ValidationReport({
    required this.errors,
    required this.warnings,
    required this.score,
  });

  bool get isValid => errors.isEmpty;

  @override
  String toString() => 'ValidationReport: ${errors.length} errors, ${warnings.length} warnings, score=$score';
}

/// A single validation issue
class ValidationIssue {
  final String category;
  final String message;
  final String? path;
  final int? measureNumber;

  ValidationIssue({
    required this.category,
    required this.message,
    this.path,
    this.measureNumber,
  });

  @override
  String toString() {
    final location = [
      if (measureNumber != null) 'measure $measureNumber',
      if (path != null) path,
    ].join(' > ');
    return '$category: $message${location.isNotEmpty ? ' ($location)' : ''}';
  }
}

/// Validates Score JSON structure, completeness, and consistency
class ScoreValidator {
  Score? _score;

  ValidationReport validate(Score score) {
    _score = score;
    final errors = <ValidationIssue>[];
    final warnings = <ValidationIssue>[];

    // Basic structure validation
    errors.addAll(_validateStructure());

    // Pitch range validation
    errors.addAll(_validatePitchRanges());
    warnings.addAll(_warnPitchOutOfTypical());

    // Measure duration consistency
    errors.addAll(_validateMeasureDurations());

    // Additional consistency checks
    warnings.addAll(_checkChordValidity());
    warnings.addAll(_checkTimeSignatureConsistency());

    // Calculate overall validation score (0.0 to 1.0)
    final totalIssues = errors.length + (warnings.length / 2).ceil();
    const maxExpectedIssues = 20;
    final validationScore = (1.0 - (totalIssues / maxExpectedIssues).clamp(0.0, 1.0)).clamp(0.0, 1.0);

    return ValidationReport(
      errors: errors,
      warnings: warnings,
      score: validationScore,
    );
  }

  List<ValidationIssue> _validateStructure() {
    final issues = <ValidationIssue>[];
    if (_score == null) return issues;

    // Validate using Score.validate()
    final structureErrors = _score!.validate();
    for (final error in structureErrors) {
      issues.add(ValidationIssue(
        category: error.category,
        message: error.message,
        path: error.path,
      ));
    }

    return issues;
  }

  List<ValidationIssue> _validatePitchRanges() {
    final issues = <ValidationIssue>[];
    if (_score == null) return issues;

    final instrumentRanges = _getInstrumentRanges();

    for (final part in _score!.parts) {
      final range = instrumentRanges[part.instrumentType];
      if (range == null) continue;

      for (final measure in part.measures) {
        for (final element in measure.elements) {
          if (element is NoteElement) {
            final midi = element.pitch.midiNumber;
            final minValue = range['min'] as int? ?? 0;
            final maxValue = range['max'] as int? ?? 127;
            if (midi < minValue || midi > maxValue) {
              issues.add(ValidationIssue(
                category: 'PitchRangeViolation',
                message: 'Note MIDI $midi outside ${part.instrumentType.value} range ($minValue-$maxValue)',
                path: '${part.id}/measures[${measure.number}]',
                measureNumber: measure.number,
              ));
            }
          }
        }
      }
    }

    return issues;
  }

  List<ValidationIssue> _warnPitchOutOfTypical() {
    final issues = <ValidationIssue>[];
    if (_score == null) return issues;

    final typicalRanges = _getTypicalRanges();

    for (final part in _score!.parts) {
      final range = typicalRanges[part.instrumentType];
      if (range == null) continue;

      for (final measure in part.measures) {
        for (final element in measure.elements) {
          if (element is NoteElement) {
            final midi = element.pitch.midiNumber;
            final minValue = range['min'] as int? ?? 0;
            final maxValue = range['max'] as int? ?? 127;
            if (midi < minValue || midi > maxValue) {
              issues.add(ValidationIssue(
                category: 'PitchOutOfTypical',
                message: 'Note MIDI $midi outside typical ${part.instrumentType.value} range ($minValue-$maxValue)',
                path: '${part.id}/measures[${measure.number}]',
                measureNumber: measure.number,
              ));
            }
          }
        }
      }
    }

    return issues;
  }

  List<ValidationIssue> _validateMeasureDurations() {
    final issues = <ValidationIssue>[];
    if (_score == null) return issues;

    for (final part in _score!.parts) {
      for (final measure in part.measures) {
        if (measure.timeSignature == null) continue;

        final expectedDuration = _parseTimeSignatureDuration(measure.timeSignature!);
        if (expectedDuration == 0) continue;

        int actualDuration = 0;
        for (final element in measure.elements) {
          if (element is NoteElement || element is RestElement) {
            final duration = element is NoteElement ? element.duration : (element as RestElement).duration;

            // Duration already includes dot adjustments from the parser
            // Only count non-chord members or first chord member
            if (element is NoteElement) {
              if (!element.isChordMember) {
                actualDuration += duration;
              }
            } else {
              actualDuration += duration;
            }
          }
        }

        if (actualDuration != expectedDuration) {
          issues.add(ValidationIssue(
            category: 'MeasureDurationMismatch',
            message: 'Measure duration $actualDuration does not match time signature expectation $expectedDuration',
            path: '${part.id}/measures[${measure.number}]',
            measureNumber: measure.number,
          ));
        }
      }
    }

    return issues;
  }

  List<ValidationIssue> _checkChordValidity() {
    final issues = <ValidationIssue>[];
    if (_score == null) return issues;

    for (final part in _score!.parts) {
      for (final measure in part.measures) {
        // Build a map of positions to chord notes
        final notesByPosition = <String, List<NoteElement>>{};

        for (final element in measure.elements) {
          if (element is NoteElement && element.isChordMember) {
            final key = '${element.voice}-${element.staff}';
            notesByPosition.putIfAbsent(key, () => []).add(element);
          }
        }

        // Validate chord consistency
        for (final notes in notesByPosition.values) {
          final firstDuration = notes.first.duration;
          for (final note in notes.skip(1)) {
            if (note.duration != firstDuration) {
              issues.add(ValidationIssue(
                category: 'InvalidChord',
                message: 'Chord member durations do not match: ${note.duration} vs $firstDuration',
                path: '${part.id}/measures[${measure.number}]',
                measureNumber: measure.number,
              ));
            }
          }
        }
      }
    }

    return issues;
  }

  List<ValidationIssue> _checkTimeSignatureConsistency() {
    final issues = <ValidationIssue>[];
    if (_score == null) return issues;

    for (final part in _score!.parts) {
      String? lastTimeSignature;
      for (final measure in part.measures) {
        if (measure.timeSignature != null) {
          lastTimeSignature = measure.timeSignature;
        } else if (lastTimeSignature == null && measure.number == 0) {
          issues.add(ValidationIssue(
            category: 'MissingTimeSignature',
            message: 'First measure lacks time signature',
            path: '${part.id}/measures[0]',
            measureNumber: 0,
          ));
        }
      }
    }

    return issues;
  }

  /// Parse time signature string into duration units (256ths of whole note)
  int _parseTimeSignatureDuration(String timeSignature) {
    try {
      final parts = timeSignature.split('/');
      final numerator = int.parse(parts[0]);
      final denominator = int.parse(parts[1]);

      // Duration = (numerator / denominator) * 256
      return ((numerator / denominator) * 256).toInt();
    } catch (e) {
      return 0;
    }
  }

  /// Get absolute pitch ranges per instrument type
  Map<InstrumentType, Map<String, int>> _getInstrumentRanges() {
    return {
      InstrumentType.violin: {'min': 55, 'max': 103}, // G3 to G7
      InstrumentType.viola: {'min': 48, 'max': 96},   // C3 to C7
      InstrumentType.cello: {'min': 36, 'max': 84},   // C2 to C6
      InstrumentType.bass: {'min': 28, 'max': 76},    // E1 to E5
      InstrumentType.flute: {'min': 60, 'max': 108},  // C4 to C8
      InstrumentType.oboe: {'min': 58, 'max': 91},    // Bb3 to B6
      InstrumentType.clarinet: {'min': 50, 'max': 94},// D3 to D7
      InstrumentType.bassoon: {'min': 34, 'max': 82}, // Bb1 to B5
      InstrumentType.horn: {'min': 34, 'max': 91},    // Bb1 to B6
      InstrumentType.trumpet: {'min': 55, 'max': 94}, // G3 to D7
      InstrumentType.trombone: {'min': 40, 'max': 85},// E2 to F6
      InstrumentType.tuba: {'min': 28, 'max': 73},    // E1 to D5
      InstrumentType.piano: {'min': 21, 'max': 108},  // A0 to C8
      InstrumentType.guitar: {'min': 40, 'max': 88},  // E2 to E6
      InstrumentType.voice: {'min': 40, 'max': 84},   // E2 to C6
      InstrumentType.generic: {'min': 0, 'max': 127}, // Full MIDI range
    };
  }

  /// Get typical pitch ranges per instrument (warning threshold)
  Map<InstrumentType, Map<String, int>> _getTypicalRanges() {
    return {
      InstrumentType.violin: {'min': 60, 'max': 96},  // C4 to C7 (typical)
      InstrumentType.viola: {'min': 55, 'max': 88},   // G3 to E6
      InstrumentType.cello: {'min': 48, 'max': 76},   // C3 to E5
      InstrumentType.bass: {'min': 41, 'max': 67},    // F2 to G4
      InstrumentType.flute: {'min': 72, 'max': 96},   // C5 to C7
      InstrumentType.oboe: {'min': 67, 'max': 86},    // G4 to D6
      InstrumentType.clarinet: {'min': 64, 'max': 86},// E4 to D6
      InstrumentType.bassoon: {'min': 46, 'max': 74}, // Bb2 to D5
      InstrumentType.horn: {'min': 48, 'max': 79},    // C3 to G5
      InstrumentType.trumpet: {'min': 65, 'max': 88}, // F4 to E6
      InstrumentType.trombone: {'min': 52, 'max': 81},// E3 to A5
      InstrumentType.tuba: {'min': 41, 'max': 65},    // F2 to F4
      InstrumentType.piano: {'min': 21, 'max': 108},  // A0 to C8
      InstrumentType.guitar: {'min': 52, 'max': 84},  // E3 to C6
      InstrumentType.voice: {'min': 48, 'max': 79},   // C3 to G5
      InstrumentType.generic: {'min': 0, 'max': 127}, // Full MIDI range
    };
  }
}
