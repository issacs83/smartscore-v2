/// Tests for layout engine
/// Tests proportional spacing, staff layout, and pitch positioning

import 'package:test/test.dart';
import 'package:smartscore_build/modules/f_score_renderer/models.dart';
import 'package:smartscore_build/modules/f_score_renderer/layout_engine.dart';

void main() {
  group('Layout Engine Tests', () {
    late LayoutConfig config;
    late Score fourMeasureScore;

    setUp(() {
      config = LayoutConfig(
        measuresPerSystem: 4,
        systemsPerPage: 6,
        staffLineSpacing: 12.0,
        pageWidth: 816.0,
        pageHeight: 1056.0,
        leftMargin: 40.0,
        rightMargin: 40.0,
        topMargin: 40.0,
        bottomMargin: 40.0,
        zoom: 1.0,
      );

      // Create a 4-measure score with different note durations
      final part = Part(
        id: 'P1',
        name: 'Piano',
        instrument: 'piano',
        staves: ['S1'],
        clef: 'treble',
      );

      // Measure 0: whole note (duration 1.0)
      final measure0 = Measure(
        number: 0,
        timeSignature: '4/4',
        keySignature: 'C major',
        notes: [
          Note(
            id: 'N1',
            step: 'C',
            octave: 4,
            alter: 0,
            noteType: 'whole',
            staff: 0,
            voice: 0,
            duration: 1.0,
          ),
        ],
        rests: [],
      );

      // Measure 1: half note + half note (duration 1.0)
      final measure1 = Measure(
        number: 1,
        notes: [
          Note(
            id: 'N2',
            step: 'D',
            alter: 0,
            octave: 4,
            noteType: 'half',
            staff: 0,
            voice: 0,
            duration: 0.5,
          ),
          Note(
            id: 'N3',
            step: 'E',
            alter: 0,
            octave: 4,
            noteType: 'half',
            staff: 0,
            voice: 0,
            duration: 0.5,
          ),
        ],
        rests: [],
      );

      // Measure 2: 4 quarter notes (duration 1.0)
      final measure2 = Measure(
        number: 2,
        notes: [
          Note(
            id: 'N4',
            step: 'F',
            alter: 0,
            octave: 4,
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
          ),
          Note(
            id: 'N5',
            step: 'G',
            alter: 0,
            octave: 4,
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
          ),
          Note(
            id: 'N6',
            step: 'A',
            alter: 0,
            octave: 4,
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
          ),
          Note(
            id: 'N7',
            step: 'B',
            alter: 0,
            octave: 4,
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
          ),
        ],
        rests: [],
      );

      // Measure 3: 8 eighth notes (duration 1.0)
      final measure3 = Measure(
        number: 3,
        notes: List.generate(
          8,
          (i) => Note(
            id: 'N${8 + i}',
            step: 'C',
            alter: 0,
            octave: 5,
            noteType: 'eighth',
            staff: 0,
            voice: 0,
            duration: 0.125,
          ),
        ),
        rests: [],
      );

      fourMeasureScore = Score(
        format: '1.0',
        parts: [part],
        measures: [measure0, measure1, measure2, measure3],
      );
    });

    test('Four-measure score produces one system', () {
      final layout = computePageLayout(fourMeasureScore, 0, 0, config);

      expect(layout.systems.length, 1);
      expect(layout.systems[0].measures.length, 4);
    });

    test('Measures have proportional widths based on duration', () {
      final layout = computePageLayout(fourMeasureScore, 0, 0, config);
      final system = layout.systems[0];
      final measures = system.measures;

      // All measures have equal duration (1.0), so equal widths
      final width0 = measures[0].bounds.width;
      final width1 = measures[1].bounds.width;
      final width2 = measures[2].bounds.width;
      final width3 = measures[3].bounds.width;

      // Widths should be approximately equal (within tolerance for floating point)
      expect((width0 - width1).abs(), lessThan(1.0));
      expect((width1 - width2).abs(), lessThan(1.0));
      expect((width2 - width3).abs(), lessThan(1.0));
    });

    test('Whole note measure is readable', () {
      final layout = computePageLayout(fourMeasureScore, 0, 0, config);
      final measure = layout.systems[0].measures[0];

      expect(measure.notes.length, 1);
      expect(measure.notes[0].noteType, 'whole');
      expect(measure.notes[0].bounds.width, greaterThan(0));
      expect(measure.notes[0].bounds.height, greaterThan(0));
    });

    test('Grand staff layout has correct gap', () {
      // Create grand staff version
      final part = Part(
        id: 'P1',
        name: 'Piano',
        instrument: 'piano',
        staves: ['S1', 'S2'],
        clef: 'treble_bass',
      );

      final measure = Measure(
        number: 0,
        notes: [
          Note(
            id: 'N1',
            step: 'C',
            alter: 0,
            octave: 4,
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
          ),
        ],
        rests: [],
      );

      final grandStaffScore = Score(
        format: '1.0',
        parts: [part],
        measures: [measure],
      );

      final layout = computePageLayout(grandStaffScore, 0, 0, config);
      final system = layout.systems[0];

      // Should have 2 staves with gap between them
      expect(system.staves.length, 2);

      final trebleBounds = system.staves[0].bounds;
      final bassBounds = system.staves[1].bounds;

      // Bass staff should be below treble staff
      expect(bassBounds.y, greaterThan(trebleBounds.y + trebleBounds.height));

      // Gap should be significant (at least 25 pixels)
      final gap = bassBounds.y - (trebleBounds.y + trebleBounds.height);
      expect(gap, greaterThanOrEqualTo(25.0));
    });

    test('pitchToStaffY: Treble clef E4 on bottom line', () {
      final config = LayoutConfig(staffLineSpacing: 12.0);

      // Create score with E4 note
      final measure = Measure(
        number: 0,
        notes: [
          Note(
            id: 'N1',
            step: 'E',
            alter: 0,
            octave: 4,
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
          ),
        ],
        rests: [],
      );

      final score = Score(
        format: '1.0',
        parts: [
          Part(
            id: 'P1',
            name: 'Test',
            instrument: 'test',
            staves: ['S1'],
            clef: 'treble',
          )
        ],
        measures: [measure],
      );

      final layout = computePageLayout(score, 0, 0, config);
      final noteLayout = layout.systems[0].measures[0].notes[0];

      // E4 should be on the bottom line
      // Bottom line is at the bottom of the staff
      final stave = layout.systems[0].staves[0];
      final bottomLineY = stave.bounds.y + (4 * config.staffLineSpacing);

      // Note Y should be approximately on bottom line
      expect((noteLayout.bounds.y - bottomLineY).abs(), lessThan(2.0));
    });

    test('pitchToStaffY: Treble clef pitch range', () {
      final config = LayoutConfig(staffLineSpacing: 12.0);

      final notes = [
        ('C', 4, 'C4'),
        ('E', 4, 'E4'),
        ('G', 4, 'G4'),
        ('B', 4, 'B4'),
        ('C', 5, 'C5'),
      ];

      for (final (step, octave, _) in notes) {
        final measure = Measure(
          number: 0,
          notes: [
            Note(
              id: 'N1',
              step: step,
              octave: octave,
              alter: 0,
              noteType: 'quarter',
              staff: 0,
              voice: 0,
              duration: 0.25,
            ),
          ],
          rests: [],
        );

        final score = Score(
          format: '1.0',
          parts: [
            Part(
              id: 'P1',
              name: 'Test',
              instrument: 'test',
              staves: ['S1'],
              clef: 'treble',
            )
          ],
          measures: [measure],
        );

        final layout = computePageLayout(score, 0, 0, config);
        final noteLayout = layout.systems[0].measures[0].notes[0];

        // All notes should be within staff bounds (with some ledger space)
        final stave = layout.systems[0].staves[0];
        expect(noteLayout.bounds.y, lessThan(stave.bounds.y + 100));
        expect(noteLayout.bounds.y, greaterThan(stave.bounds.y - 100));
      }
    });

    test('pitchToStaffY: Bass clef G2 on bottom line', () {
      final config = LayoutConfig(staffLineSpacing: 12.0);

      final measure = Measure(
        number: 0,
        notes: [
          Note(
            id: 'N1',
            step: 'G',
            alter: 0,
            octave: 2,
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
          ),
        ],
        rests: [],
      );

      final score = Score(
        format: '1.0',
        parts: [
          Part(
            id: 'P1',
            name: 'Test',
            instrument: 'test',
            staves: ['S1'],
            clef: 'bass',
          )
        ],
        measures: [measure],
      );

      final layout = computePageLayout(score, 0, 0, config);
      final noteLayout = layout.systems[0].measures[0].notes[0];

      // G2 should be on the bottom line
      final stave = layout.systems[0].staves[0];
      final bottomLineY = stave.bounds.y + (4 * config.staffLineSpacing);

      expect((noteLayout.bounds.y - bottomLineY).abs(), lessThan(2.0));
    });

    test('pitchToStaffY: Bass clef pitch range', () {
      final config = LayoutConfig(staffLineSpacing: 12.0);

      final notes = [
        ('C', 3, 'C3'),
        ('E', 3, 'E3'),
        ('G', 3, 'G3'),
        ('B', 3, 'B3'),
      ];

      for (final (step, octave, _) in notes) {
        final measure = Measure(
          number: 0,
          notes: [
            Note(
              id: 'N1',
              step: step,
              octave: octave,
              alter: 0,
              noteType: 'quarter',
              staff: 0,
              voice: 0,
              duration: 0.25,
            ),
          ],
          rests: [],
        );

        final score = Score(
          format: '1.0',
          parts: [
            Part(
              id: 'P1',
              name: 'Test',
              instrument: 'test',
              staves: ['S1'],
              clef: 'bass',
            )
          ],
          measures: [measure],
        );

        final layout = computePageLayout(score, 0, 0, config);
        final noteLayout = layout.systems[0].measures[0].notes[0];

        final stave = layout.systems[0].staves[0];
        expect(noteLayout.bounds.y, lessThan(stave.bounds.y + 100));
        expect(noteLayout.bounds.y, greaterThan(stave.bounds.y - 100));
      }
    });

    test('Ledger lines computation for notes outside staff', () {
      final config = LayoutConfig(staffLineSpacing: 12.0);

      // C5 is above the staff in treble clef
      final measure = Measure(
        number: 0,
        notes: [
          Note(
            id: 'N1',
            step: 'C',
            alter: 0,
            octave: 5,
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
          ),
        ],
        rests: [],
      );

      final score = Score(
        format: '1.0',
        parts: [
          Part(
            id: 'P1',
            name: 'Test',
            instrument: 'test',
            staves: ['S1'],
            clef: 'treble',
          )
        ],
        measures: [measure],
      );

      final layout = computePageLayout(score, 0, 0, config);
      final noteLayout = layout.systems[0].measures[0].notes[0];

      // C5 should be above the staff
      final stave = layout.systems[0].staves[0];
      expect(noteLayout.bounds.y, lessThan(stave.bounds.y));
    });

    test('Empty score returns one empty page', () {
      final emptyScore = Score(
        format: '1.0',
        parts: [],
        measures: [],
      );

      final layout = computePageLayout(emptyScore, 0, 0, config);

      expect(layout.isEmpty, true);
      expect(layout.systems.length, 0);
    });

    test('Invalid page index returns empty layout', () {
      final layout = computePageLayout(fourMeasureScore, 0, 99, config);

      expect(layout.isEmpty, true);
      expect(layout.systems.length, 0);
    });
  });
}
