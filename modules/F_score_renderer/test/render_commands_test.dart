/// Tests for render command generation
/// Tests staff lines, note heads, and highlighting

import 'package:test/test.dart';
import 'package:smartscore_build/modules/f_score_renderer/models.dart';
import 'package:smartscore_build/modules/f_score_renderer/layout_engine.dart';
import 'package:smartscore_build/modules/f_score_renderer/render_commands.dart';
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
  String? rehearsalMark,
  List<score_model.Element> elements = const [],
}) {
  return score_model.Measure(
    number: number,
    elements: elements,
    timeSignature: timeSignature,
    rehearsalMark: rehearsalMark,
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
  int dots = 0,
  List<String> articulations = const [],
  String? dynamicMarking,
}) {
  return score_model.NoteElement(
    pitch: score_model.Pitch(step: step, octave: octave, alter: alter),
    duration: duration,
    noteType: noteType,
    staff: staff,
    voice: voice,
    dots: dots,
    articulations: articulations,
    dynamicMarking: dynamicMarking,
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

score_model.Score _createSimpleScore() {
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

  return _makeScore(parts: [part]);
}

void main() {
  group('Render Commands Tests', () {
    late LayoutConfig config;
    late PageLayout pageLayout;
    late List<RenderCommand> commands;
    late score_model.Score testScore;

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
          _makeNote(step: 'G', octave: 4, noteType: 'half', duration: 8),
          _makeRest(noteType: 'quarter', duration: 4),
        ],
      );

      final part = _makePart(
        measures: [measure],
        clefs: [score_model.Clef(sign: 'G', line: 2, staff: 0)],
      );

      testScore = _makeScore(parts: [part]);
      pageLayout = computePageLayout(testScore, 0, 0, config);

      final state = RenderState(
        darkMode: false,
        highlightColor: 'blue',
      );

      commands = generateRenderCommands(testScore, pageLayout, state);
    });

    test('Generates render commands list', () {
      expect(commands, isNotEmpty);
      expect(commands.length, greaterThan(0));
    });

    test('Contains staff lines (5 per staff)', () {
      final lineCommands = commands.whereType<DrawLine>();
      expect(lineCommands.length, greaterThan(0));

      final horizontalLines = lineCommands
          .where((cmd) => (cmd.y1 - cmd.y2).abs() < 0.1)
          .toList();

      expect(horizontalLines.length, greaterThanOrEqualTo(5));
    });

    test('Contains note heads for non-rest notes', () {
      final ovalCommands = commands.whereType<DrawOval>();
      expect(ovalCommands.length, greaterThan(0));
    });

    test('Contains barlines', () {
      final lineCommands = commands.whereType<DrawLine>();
      final verticalLines = lineCommands
          .where((cmd) => (cmd.x1 - cmd.x2).abs() < 0.1)
          .toList();

      expect(verticalLines.length, greaterThan(0));
    });

    test('Time signature is rendered', () {
      final textCommands = commands.whereType<DrawText>();
      final timeSigTexts = textCommands
          .where((cmd) => cmd.text.contains('/'))
          .toList();

      expect(timeSigTexts.length, greaterThan(0));
      expect(timeSigTexts[0].text, contains('4/4'));
    });

    test('Whole notes are hollow (not filled)', () {
      final measure = _makeMeasure(
        number: 0,
        elements: [
          _makeNote(step: 'C', octave: 4, noteType: 'whole', duration: 16),
        ],
      );

      final part = _makePart(
        measures: [measure],
        clefs: [score_model.Clef(sign: 'G', line: 2, staff: 0)],
      );

      final score = _makeScore(parts: [part]);
      final layout = computePageLayout(score, 0, 0, config);
      final state = RenderState(darkMode: false);
      final cmds = generateRenderCommands(score, layout, state);

      final ovals = cmds.whereType<DrawOval>();
      expect(ovals.length, greaterThan(0));

      final wholeNoteOvals = ovals.where((o) => !o.filled).toList();
      expect(wholeNoteOvals.length, greaterThan(0));
    });

    test('Accidentals are rendered as text', () {
      final measure = _makeMeasure(
        number: 0,
        elements: [
          _makeNote(step: 'F', octave: 4, alter: 1, noteType: 'quarter', duration: 4),
        ],
      );

      final part = _makePart(
        measures: [measure],
        clefs: [score_model.Clef(sign: 'G', line: 2, staff: 0)],
      );

      final score = _makeScore(parts: [part]);
      final layout = computePageLayout(score, 0, 0, config);
      final state = RenderState(darkMode: false);
      final cmds = generateRenderCommands(score, layout, state);

      final textCommands = cmds.whereType<DrawText>();
      final accidentals = textCommands.where((t) => t.text == '#').toList();
      expect(accidentals.length, greaterThan(0));
    });

    test('Augmentation dots are rendered', () {
      final measure = _makeMeasure(
        number: 0,
        elements: [
          _makeNote(step: 'C', octave: 4, noteType: 'quarter', duration: 6, dots: 1),
        ],
      );

      final part = _makePart(
        measures: [measure],
        clefs: [score_model.Clef(sign: 'G', line: 2, staff: 0)],
      );

      final score = _makeScore(parts: [part]);
      final layout = computePageLayout(score, 0, 0, config);
      final state = RenderState(darkMode: false);
      final cmds = generateRenderCommands(score, layout, state);

      final ovals = cmds.whereType<DrawOval>();
      final dots = ovals.where((o) => o.filled && o.rx < 5).toList();
      expect(dots.length, greaterThan(0));
    });

    test('Rests are rendered', () {
      final rectCommands = commands.whereType<DrawRect>();
      expect(rectCommands.length, greaterThan(0));
    });

    test('Background is rendered', () {
      final rects = commands.whereType<DrawRect>();
      final backgroundRects = rects
          .where((r) =>
              r.x == 0 &&
              r.y == 0 &&
              r.width == pageLayout.canvasWidth &&
              r.height == pageLayout.canvasHeight)
          .toList();

      expect(backgroundRects.length, greaterThan(0));
    });

    test('Dark mode changes text color', () {
      final state = RenderState(darkMode: true);
      final cmds = generateRenderCommands(_createSimpleScore(), pageLayout, state);

      final textCommands = cmds.whereType<DrawText>();
      for (final text in textCommands) {
        if (text.color.startsWith('#')) {
          final hexColor = text.color.replaceFirst('#', '');
          if (hexColor.length == 6) {
            final colorValue = int.parse(hexColor, radix: 16);
            expect(colorValue, greaterThan(0x999999));
          }
        }
      }
    });

    test('Highlight command present for current measure', () {
      final state = RenderState(
        currentMeasure: 0,
        highlightColor: 'blue',
      );

      final cmds = generateRenderCommands(_createSimpleScore(), pageLayout, state);

      final rects = cmds.whereType<DrawRect>();
      final highlights = rects
          .where((r) =>
              r.color == 'blue' &&
              r.filled == false &&
              r.strokeWidth > 1.0)
          .toList();

      expect(highlights.length, greaterThan(0));
    });

    test('Rehearsal mark is rendered when present', () {
      final measure = _makeMeasure(
        number: 0,
        rehearsalMark: 'A',
        elements: [],
      );

      final part = _makePart(
        measures: [measure],
        clefs: [score_model.Clef(sign: 'G', line: 2, staff: 0)],
      );

      final score = _makeScore(parts: [part]);
      final layout = computePageLayout(score, 0, 0, config);
      final state = RenderState(darkMode: false);
      final cmds = generateRenderCommands(score, layout, state);

      final textCommands = cmds.whereType<DrawText>();
      final rehearsalMarks = textCommands.where((t) => t.text == 'A').toList();
      expect(rehearsalMarks.length, greaterThan(0));
    });

    test('Stems are rendered for notes', () {
      final lines = commands.whereType<DrawLine>();
      final stems = lines.where((l) => (l.x1 - l.x2).abs() < 0.1).toList();
      expect(stems.length, greaterThan(0));
    });

    test('Note with articulation has visual indicator', () {
      final measure = _makeMeasure(
        number: 0,
        elements: [
          _makeNote(
            step: 'C',
            octave: 4,
            noteType: 'quarter',
            duration: 4,
            articulations: ['staccato'],
          ),
        ],
      );

      final part = _makePart(
        measures: [measure],
        clefs: [score_model.Clef(sign: 'G', line: 2, staff: 0)],
      );

      final score = _makeScore(parts: [part]);
      final layout = computePageLayout(score, 0, 0, config);
      final state = RenderState(darkMode: false);
      final cmds = generateRenderCommands(score, layout, state);

      final ovals = cmds.whereType<DrawOval>();
      expect(ovals.length, greaterThan(0));
    });

    test('Multiple notes in measure are rendered', () {
      final ovals = commands.whereType<DrawOval>();
      expect(ovals.length, greaterThanOrEqualTo(2));
    });
  });
}
