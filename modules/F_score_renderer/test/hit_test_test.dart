/// Tests for hit testing
/// Tests hit detection on notes, measures, and empty areas

import 'package:test/test.dart';
import 'package:smartscore_build/modules/f_score_renderer/models.dart';
import 'package:smartscore_build/modules/f_score_renderer/layout_engine.dart';
import 'package:smartscore_build/modules/f_score_renderer/hit_test.dart';

void main() {
  group('Hit Test Tests', () {
    late LayoutConfig config;
    late PageLayout pageLayout;

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

      // Create a simple score
      final part = Part(
        id: 'P1',
        name: 'Test',
        instrument: 'test',
        staves: ['S1'],
        clef: 'treble',
      );

      final measure = Measure(
        number: 0,
        timeSignature: '4/4',
        notes: [
          Note(
            id: 'N1',
            step: 'C',
            octave: 4,
            alter: 0,
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
          ),
          Note(
            id: 'N2',
            step: 'D',
            octave: 4,
            alter: 0,
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
          ),
        ],
        rests: [
          Rest(
            id: 'R1',
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
          ),
        ],
      );

      final score = Score(
        format: '1.0',
        parts: [part],
        measures: [measure],
      );

      pageLayout = computePageLayout(score, 0, 0, config);
    });

    test('Hit on note returns correct note', () {
      final note = pageLayout.systems[0].measures[0].notes[0];

      // Click in the center of the note
      final result = hitTest(
        note.bounds.x + (note.bounds.width / 2),
        note.bounds.y + (note.bounds.height / 2),
        pageLayout,
      );

      expect(result, isNotNull);
      expect(result!.type, HitType.note);
      expect(result.noteId, 'N1');
      expect(result.measureNumber, 0);
      expect(result.confidence, 1.0);
    });

    test('Hit on rest returns correct rest', () {
      final rest = pageLayout.systems[0].measures[0].notes
          .firstWhere((n) => n.isRest);

      // Click in the center of the rest
      final result = hitTest(
        rest.bounds.x + (rest.bounds.width / 2),
        rest.bounds.y + (rest.bounds.height / 2),
        pageLayout,
      );

      expect(result, isNotNull);
      expect(result!.type, HitType.rest);
      expect(result.confidence, 1.0);
    });

    test('Hit on measure returns measure', () {
      final measure = pageLayout.systems[0].measures[0];

      // Click in an empty area of the measure (not on a note)
      final result = hitTest(
        measure.bounds.x + measure.bounds.width * 0.8,
        measure.bounds.y + measure.bounds.height * 0.5,
        pageLayout,
      );

      expect(result, isNotNull);
      expect(result!.type, HitType.measure);
      expect(result.measureNumber, 0);
    });

    test('Hit on empty area returns empty', () {
      // Click in area with no measures
      final result = hitTest(
        500.0,
        1000.0,
        pageLayout,
      );

      // May return staff or empty
      expect(
        result == null || result.type == HitType.staff || result.type == HitType.empty,
        true,
      );
    });

    test('Hit on staff returns staff type', () {
      final stave = pageLayout.systems[0].staves[0];

      // Click on the staff line
      final result = hitTest(
        stave.bounds.x + 50,
        stave.bounds.y + (stave.bounds.height / 2),
        pageLayout,
      );

      expect(result, isNotNull);
      expect(result!.type, HitType.staff);
      expect(result.staffIndex, 0);
    });

    test('Hit boundary: exactly on note bounds', () {
      final note = pageLayout.systems[0].measures[0].notes[0];

      // Hit exactly on the boundary
      final result = hitTest(
        note.bounds.x,
        note.bounds.y,
        pageLayout,
      );

      expect(result, isNotNull);
      expect(result!.type, HitType.note);
    });

    test('Hit boundary: just outside note bounds', () {
      final note = pageLayout.systems[0].measures[0].notes[0];

      // Hit just outside the note
      final result = hitTest(
        note.bounds.x - 5,
        note.bounds.y - 5,
        pageLayout,
      );

      // Should not hit the note
      if (result != null) {
        expect(result.type, isNot(HitType.note));
      }
    });

    test('Hit returns correct pitch for note', () {
      final note = pageLayout.systems[0].measures[0].notes[0];

      final result = hitTest(
        note.bounds.x + (note.bounds.width / 2),
        note.bounds.y + (note.bounds.height / 2),
        pageLayout,
      );

      expect(result, isNotNull);
      expect(result!.pitch, isNotNull);
      expect(result.pitch!.step, 'C');
      expect(result.pitch!.octave, 4);
    });

    test('Hit on second note returns second note', () {
      final notes = pageLayout.systems[0].measures[0].notes
          .where((n) => !n.isRest)
          .toList();

      expect(notes.length, greaterThanOrEqualTo(2));

      final secondNote = notes[1];

      final result = hitTest(
        secondNote.bounds.x + (secondNote.bounds.width / 2),
        secondNote.bounds.y + (secondNote.bounds.height / 2),
        pageLayout,
      );

      expect(result, isNotNull);
      expect(result!.type, HitType.note);
      expect(result.noteId, 'N2');
    });

    test('Multiple hits returns most specific element (note over measure)', () {
      final note = pageLayout.systems[0].measures[0].notes[0];

      // Point is on both note and measure; should return note
      final result = hitTest(
        note.bounds.x + (note.bounds.width / 2),
        note.bounds.y + (note.bounds.height / 2),
        pageLayout,
      );

      expect(result!.type, HitType.note);
    });
  });

  group('Hit Test with Beat Position', () {
    test('Beat calculation within measure', () {
      final config = LayoutConfig();

      final measure = Measure(
        number: 0,
        timeSignature: '4/4',
        notes: [
          Note(
            id: 'N1',
            step: 'C',
            octave: 4,
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
      final timeSigs = {0: '4/4'};

      // Click at start of measure
      final result = hitTestWithBeat(
        layout.systems[0].measures[0].bounds.x,
        layout.systems[0].measures[0].bounds.y +
            (layout.systems[0].measures[0].bounds.height / 2),
        layout,
        timeSigs,
      );

      expect(result, isNotNull);
      expect(result!.beat, isNotNull);
      expect(result.beat!, lessThan(1.0));
    });
  });

  group('Hit Test Utilities', () {
    test('notesInRegion returns notes within region', () {
      final config = LayoutConfig();

      final measure = Measure(
        number: 0,
        notes: [
          Note(
            id: 'N1',
            step: 'C',
            octave: 4,
            alter: 0,
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
          ),
          Note(
            id: 'N2',
            step: 'D',
            octave: 4,
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

      // Create a region covering the entire measure
      final region = layout.systems[0].measures[0].bounds;

      final notes = notesInRegion(region, layout);

      expect(notes.length, greaterThan(0));
    });

    test('measuresInRegion returns measures within region', () {
      final config = LayoutConfig();

      final measure = Measure(
        number: 0,
        notes: [
          Note(
            id: 'N1',
            step: 'C',
            octave: 4,
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

      final region = Rect(
        x: layout.systems[0].measures[0].bounds.x - 10,
        y: layout.systems[0].measures[0].bounds.y - 10,
        width: layout.systems[0].measures[0].bounds.width + 20,
        height: layout.systems[0].measures[0].bounds.height + 20,
      );

      final measures = measuresInRegion(region, layout);

      expect(measures.length, greaterThan(0));
    });
  });
}
