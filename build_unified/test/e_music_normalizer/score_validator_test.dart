import 'package:test/test.dart';
import 'package:smartscore_build/modules/e_music_normalizer/score_json.dart';
import 'package:smartscore_build/modules/e_music_normalizer/score_validator.dart';

void main() {
  group('ScoreValidator Tests', () {
    test('Valid score passes validation', () {
      final score = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Test Score',
        composer: 'Test Composer',
        parts: [
          Part(
            id: 'P1',
            name: 'Melody',
            instrumentType: InstrumentType.voice,
            staveCount: 1,
            measures: [
              Measure(
                number: 0,
                elements: [
                  NoteElement(
                    pitch: Pitch(step: 'C', octave: 4),
                    duration: 64,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                  ),
                  NoteElement(
                    pitch: Pitch(step: 'D', octave: 4),
                    duration: 64,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                  ),
                  NoteElement(
                    pitch: Pitch(step: 'E', octave: 4),
                    duration: 64,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                  ),
                  NoteElement(
                    pitch: Pitch(step: 'F', octave: 4),
                    duration: 64,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                  ),
                ],
                timeSignature: '4/4',
              ),
            ],
          ),
        ],
        metadata: ScoreMetadata(
          format: '1.0',
          source: 'test',
        ),
      );

      final validator = ScoreValidator();
      final report = validator.validate(score);

      expect(report.isValid, isTrue);
      expect(report.errors, isEmpty);
      expect(report.score, greaterThanOrEqualTo(0.8));
    });

    test('Empty measures flagged as duration mismatch', () {
      final score = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Test',
        composer: '',
        parts: [
          Part(
            id: 'P1',
            name: 'Part',
            instrumentType: InstrumentType.piano,
            staveCount: 1,
            measures: [
              Measure(
                number: 0,
                elements: [],
                timeSignature: '4/4',
              ),
            ],
          ),
        ],
        metadata: ScoreMetadata(format: '1.0', source: 'test'),
      );

      final validator = ScoreValidator();
      final report = validator.validate(score);

      expect(report.errors, isNotEmpty);
      expect(
        report.errors.any((e) => e.category == 'MeasureDurationMismatch'),
        isTrue,
      );
    });

    test('Wrong measure duration flagged', () {
      final score = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Test',
        composer: '',
        parts: [
          Part(
            id: 'P1',
            name: 'Part',
            instrumentType: InstrumentType.piano,
            staveCount: 1,
            measures: [
              Measure(
                number: 0,
                elements: [
                  NoteElement(
                    pitch: Pitch(step: 'C', octave: 4),
                    duration: 64,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                  ),
                  // Only 1 quarter note in 4/4 time (needs 4)
                ],
                timeSignature: '4/4',
              ),
            ],
          ),
        ],
        metadata: ScoreMetadata(format: '1.0', source: 'test'),
      );

      final validator = ScoreValidator();
      final report = validator.validate(score);

      expect(report.errors, isNotEmpty);
      expect(
        report.errors.any((e) => e.category == 'MeasureDurationMismatch'),
        isTrue,
      );
    });

    test('Pitch out of instrument range warned', () {
      final score = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Test',
        composer: '',
        parts: [
          Part(
            id: 'P1',
            name: 'Part',
            instrumentType: InstrumentType.violin,
            staveCount: 1,
            measures: [
              Measure(
                number: 0,
                elements: [
                  NoteElement(
                    pitch: Pitch(step: 'C', octave: 1), // Very low for violin
                    duration: 64,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                  ),
                ],
                timeSignature: '4/4',
              ),
            ],
          ),
        ],
        metadata: ScoreMetadata(format: '1.0', source: 'test'),
      );

      final validator = ScoreValidator();
      final report = validator.validate(score);

      expect(
        report.warnings.any((w) => w.category == 'PitchOutOfTypical'),
        isTrue,
      );
    });

    test('Pitch out of absolute range errors', () {
      final score = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Test',
        composer: '',
        parts: [
          Part(
            id: 'P1',
            name: 'Part',
            instrumentType: InstrumentType.flute,
            staveCount: 1,
            measures: [
              Measure(
                number: 0,
                elements: [
                  NoteElement(
                    pitch: Pitch(step: 'C', octave: 0), // Below flute range
                    duration: 64,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                  ),
                ],
                timeSignature: '4/4',
              ),
            ],
          ),
        ],
        metadata: ScoreMetadata(format: '1.0', source: 'test'),
      );

      final validator = ScoreValidator();
      final report = validator.validate(score);

      expect(
        report.errors.any((e) => e.category == 'PitchRangeViolation'),
        isTrue,
      );
    });

    test('Chord with mismatched durations warned', () {
      final score = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Test',
        composer: '',
        parts: [
          Part(
            id: 'P1',
            name: 'Part',
            instrumentType: InstrumentType.piano,
            staveCount: 1,
            measures: [
              Measure(
                number: 0,
                elements: [
                  NoteElement(
                    pitch: Pitch(step: 'C', octave: 4),
                    duration: 64,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                    isChordMember: true,
                  ),
                  NoteElement(
                    pitch: Pitch(step: 'E', octave: 4),
                    duration: 128, // Different duration
                    noteType: 'half',
                    voice: 0,
                    staff: 0,
                    isChordMember: true,
                  ),
                  NoteElement(
                    pitch: Pitch(step: 'G', octave: 4),
                    duration: 64,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                  ),
                ],
                timeSignature: '4/4',
              ),
            ],
          ),
        ],
        metadata: ScoreMetadata(format: '1.0', source: 'test'),
      );

      final validator = ScoreValidator();
      final report = validator.validate(score);

      expect(
        report.warnings.any((w) => w.category == 'InvalidChord'),
        isTrue,
      );
    });

    test('Missing time signature in first measure', () {
      final score = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Test',
        composer: '',
        parts: [
          Part(
            id: 'P1',
            name: 'Part',
            instrumentType: InstrumentType.piano,
            staveCount: 1,
            measures: [
              Measure(
                number: 0,
                elements: [
                  NoteElement(
                    pitch: Pitch(step: 'C', octave: 4),
                    duration: 64,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                  ),
                ],
                // No timeSignature
              ),
            ],
          ),
        ],
        metadata: ScoreMetadata(format: '1.0', source: 'test'),
      );

      final validator = ScoreValidator();
      final report = validator.validate(score);

      expect(
        report.warnings.any((w) => w.category == 'MissingTimeSignature'),
        isTrue,
      );
    });

    test('ValidationReport with errors', () {
      final errors = [
        ValidationIssue(
          category: 'Test',
          message: 'Test error',
          measureNumber: 0,
        ),
      ];
      final report = ValidationReport(
        errors: errors,
        warnings: [],
        score: 0.5,
      );

      expect(report.isValid, isFalse);
      expect(report.errors.length, equals(1));
      expect(report.score, equals(0.5));
    });

    test('Multiple part validation', () {
      final score = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Test',
        composer: '',
        parts: [
          Part(
            id: 'P1',
            name: 'Violin',
            instrumentType: InstrumentType.violin,
            staveCount: 1,
            measures: [
              Measure(
                number: 0,
                elements: [
                  NoteElement(
                    pitch: Pitch(step: 'G', octave: 4),
                    duration: 256,
                    noteType: 'whole',
                    voice: 0,
                    staff: 0,
                  ),
                ],
                timeSignature: '4/4',
              ),
            ],
          ),
          Part(
            id: 'P2',
            name: 'Piano',
            instrumentType: InstrumentType.piano,
            staveCount: 2,
            measures: [
              Measure(
                number: 0,
                elements: [
                  NoteElement(
                    pitch: Pitch(step: 'C', octave: 3),
                    duration: 256,
                    noteType: 'whole',
                    voice: 0,
                    staff: 0,
                  ),
                ],
                timeSignature: '4/4',
              ),
            ],
          ),
        ],
        metadata: ScoreMetadata(format: '1.0', source: 'test'),
      );

      final validator = ScoreValidator();
      final report = validator.validate(score);

      expect(report.isValid, isTrue);
      expect(report.score, greaterThanOrEqualTo(0.8));
    });

    test('Dotted notes duration calculation', () {
      final score = Score(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'Test',
        composer: '',
        parts: [
          Part(
            id: 'P1',
            name: 'Part',
            instrumentType: InstrumentType.piano,
            staveCount: 1,
            measures: [
              Measure(
                number: 0,
                elements: [
                  NoteElement(
                    pitch: Pitch(step: 'C', octave: 4),
                    duration: 96, // Dotted quarter = 96 (64 + 32)
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                    dots: 1,
                  ),
                  NoteElement(
                    pitch: Pitch(step: 'D', octave: 4),
                    duration: 96,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                    dots: 1,
                  ),
                  NoteElement(
                    pitch: Pitch(step: 'E', octave: 4),
                    duration: 64,
                    noteType: 'quarter',
                    voice: 0,
                    staff: 0,
                  ),
                ],
                timeSignature: '4/4',
              ),
            ],
          ),
        ],
        metadata: ScoreMetadata(format: '1.0', source: 'test'),
      );

      final validator = ScoreValidator();
      final report = validator.validate(score);

      // Duration: 96 + 96 + 64 = 256 (4/4 in 256ths) ✓
      expect(
        report.errors.where((e) => e.category == 'MeasureDurationMismatch'),
        isEmpty,
      );
    });

    test('Report toString', () {
      final report = ValidationReport(
        errors: [
          ValidationIssue(
            category: 'Test',
            message: 'Test error',
            path: 'measures[0]',
          ),
        ],
        warnings: [],
        score: 0.9,
      );

      final str = report.toString();
      expect(str, contains('errors'));
      expect(str, contains('warnings'));
      expect(str, contains('score=0.9'));
    });

    test('ValidationIssue toString with all fields', () {
      final issue = ValidationIssue(
        category: 'TestCategory',
        message: 'Test message',
        path: 'parts[0]',
        measureNumber: 5,
      );

      final str = issue.toString();
      expect(str, contains('TestCategory'));
      expect(str, contains('Test message'));
      expect(str, contains('measure 5'));
      expect(str, contains('parts[0]'));
    });
  });
}
