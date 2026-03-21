/// Tests for hit testing
/// Tests hit detection on notes, measures, and empty areas

import 'package:test/test.dart';
import 'package:smartscore_build/modules/f_score_renderer/models.dart';
import 'package:smartscore_build/modules/f_score_renderer/layout_engine.dart';
import 'package:smartscore_build/modules/f_score_renderer/hit_test.dart';
import 'package:smartscore_build/modules/e_music_normalizer/score_json.dart' as score_model;

score_model.Score _makeScore({
  required List<score_model.Part> parts,
}) {
  return score_model.Score(
    id: '00000000-0000-0000-0000-000000000001',
    title: 'Test',
    composer: '',
    parts: parts,
    metadata: score_model.ScoreMetadata(format: '1.0', source: 'test'),
  );
}

score_model.Part _makePart({
  required List<score_model.Measure> measures,
  List<score_model.Clef>? clefs,
}) {
  if (clefs != null && measures.isNotEmpty) {
    measures = [
      measures[0].copyWith(clefs: clefs),
      ...measures.sublist(1),
    ];
  }
  return score_model.Part(
    id: 'P1',
    name: 'Test',
    instrumentType: score_model.InstrumentType.generic,
    staveCount: 1,
    measures: measures,
  );
}

score_model.Measure _makeMeasure({
  int number = 0,
  String? timeSignature,
  List<score_model.Element> elements = const [],
}) {
  return score_model.Measure(
    number: number,
    elements: elements,
    timeSignature: timeSignature,
  );
}

score_model.NoteElement _makeNote({
  String step = 'C',
  int octave = 4,
  int alter = 0,
  String noteType = 'quarter',
  int staff = 0,
  int voice = 0,
  int duration = 4,
}) {
  return score_model.NoteElement(
    pitch: score_model.Pitch(step: step, octave: octave, alter: alter),
    duration: duration,
    noteType: noteType,
    staff: staff,
    voice: voice,
  );
}

score_model.RestElement _makeRest({
  String noteType = 'quarter',
  int staff = 0,
  int voice = 0,
  int duration = 4,
}) {
  return score_model.RestElement(
    duration: duration,
    noteType: noteType,
    staff: staff,
    voice: voice,
  );
}

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

      final measure = _makeMeasure(
        number: 0,
        timeSignature: '4/4',
        elements: [
          _makeNote(step: 'C', octave: 4, noteType: 'quarter', duration: 4),
          _makeNote(step: 'D', octave: 4, noteType: 'quarter', duration: 4),
          _makeRest(noteType: 'quarter', duration: 4),
        ],
      );

      final part = _makePart(
        measures: [measure],
        clefs: [score_model.Clef(sign: 'G', line: 2, staff: 0)],
      );

      final score = _makeScore(parts: [part]);
      pageLayout = computePageLayout(score, 0, 0, config);
    });

    test('Hit on note returns correct note', () {
      final note = pageLayout.systems[0].measures[0].notes[0];

      final result = hitTest(
        note.bounds.x + (note.bounds.width / 2),
        note.bounds.y + (note.bounds.height / 2),
        pageLayout,
      );

      expect(result, isNotNull);
      expect(result!.type, HitType.note);
      expect(result.noteId, 'note_0_0');
      expect(result.measureNumber, 0);
      expect(result.confidence, 1.0);
    });

    test('Hit on rest returns correct rest', () {
      final rest = pageLayout.systems[0].measures[0].notes
          .firstWhere((n) => n.isRest);

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
      final result = hitTest(
        500.0,
        1000.0,
        pageLayout,
      );

      expect(
        result == null || result.type == HitType.staff || result.type == HitType.empty,
        true,
      );
    });

    test('Hit on staff returns staff type', () {
      final stave = pageLayout.systems[0].staves[0];

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

      final result = hitTest(
        note.bounds.x - 5,
        note.bounds.y - 5,
        pageLayout,
      );

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
      expect(result.noteId, 'note_0_1');
    });

    test('Multiple hits returns most specific element (note over measure)', () {
      final note = pageLayout.systems[0].measures[0].notes[0];

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

      final measure = _makeMeasure(
        number: 0,
        timeSignature: '4/4',
        elements: [
          _makeNote(step: 'C', octave: 4, noteType: 'quarter', duration: 4),
        ],
      );

      final part = _makePart(
        measures: [measure],
        clefs: [score_model.Clef(sign: 'G', line: 2, staff: 0)],
      );

      final score = _makeScore(parts: [part]);
      final layout = computePageLayout(score, 0, 0, config);
      final timeSigs = {0: '4/4'};

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

      final measure = _makeMeasure(
        number: 0,
        elements: [
          _makeNote(step: 'C', octave: 4, noteType: 'quarter', duration: 4),
          _makeNote(step: 'D', octave: 4, noteType: 'quarter', duration: 4),
        ],
      );

      final part = _makePart(
        measures: [measure],
        clefs: [score_model.Clef(sign: 'G', line: 2, staff: 0)],
      );

      final score = _makeScore(parts: [part]);
      final layout = computePageLayout(score, 0, 0, config);

      final region = layout.systems[0].measures[0].bounds;
      final notes = notesInRegion(region, layout);

      expect(notes.length, greaterThan(0));
    });

    test('measuresInRegion returns measures within region', () {
      final config = LayoutConfig();

      final measure = _makeMeasure(
        number: 0,
        elements: [
          _makeNote(step: 'C', octave: 4, noteType: 'quarter', duration: 4),
        ],
      );

      final part = _makePart(
        measures: [measure],
        clefs: [score_model.Clef(sign: 'G', line: 2, staff: 0)],
      );

      final score = _makeScore(parts: [part]);
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
