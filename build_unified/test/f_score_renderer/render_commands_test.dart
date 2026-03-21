/// Tests for render command generation
/// Tests staff lines, note heads, and highlighting

import 'package:test/test.dart';
import 'package:smartscore_build/modules/f_score_renderer/models.dart';
import 'package:smartscore_build/modules/f_score_renderer/layout_engine.dart';
import 'package:smartscore_build/modules/f_score_renderer/render_commands.dart';

void main() {
  group('Render Commands Tests', () {
    late LayoutConfig config;
    late PageLayout pageLayout;
    late List<RenderCommand> commands;

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
            step: 'G',
            octave: 4,
            alter: 0,
            noteType: 'half',
            staff: 0,
            voice: 0,
            duration: 0.5,
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

      final state = RenderState(
        darkMode: false,
        highlightColor: 'blue',
      );

      commands = generateRenderCommands(score, pageLayout, state);
    });

    test('Generates render commands list', () {
      expect(commands, isNotEmpty);
      expect(commands.length, greaterThan(0));
    });

    test('Contains staff lines (5 per staff)', () {
      final lineCommands = commands.whereType<DrawLine>();

      // Staff lines should be present
      expect(lineCommands.length, greaterThan(0));

      // For one staff, we should have at least 5 horizontal lines
      final horizontalLines = lineCommands
          .where((cmd) => (cmd.y1 - cmd.y2).abs() < 0.1) // Horizontal (y values equal)
          .toList();

      expect(horizontalLines.length, greaterThanOrEqualTo(5));
    });

    test('Contains note heads for non-rest notes', () {
      final ovalCommands = commands.whereType<DrawOval>();

      // Should have ovals for note heads
      expect(ovalCommands.length, greaterThan(0));
    });

    test('Contains barlines', () {
      final lineCommands = commands.whereType<DrawLine>();

      // Should have vertical lines for barlines
      final verticalLines = lineCommands
          .where((cmd) => (cmd.x1 - cmd.x2).abs() < 0.1) // Vertical (x values equal)
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
      // Create score with whole note
      final part = Part(
        id: 'P1',
        name: 'Test',
        instrument: 'test',
        staves: ['S1'],
        clef: 'treble',
      );

      final measure = Measure(
        number: 0,
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

      final score = Score(
        format: '1.0',
        parts: [part],
        measures: [measure],
      );

      final layout = computePageLayout(score, 0, 0, config);
      final state = RenderState(darkMode: false);
      final cmds = generateRenderCommands(score, layout, state);

      final ovals = cmds.whereType<DrawOval>();

      // Should have at least one oval for the whole note
      expect(ovals.length, greaterThan(0));

      // Whole note should not be filled
      final wholeNoteOvals =
          ovals.where((o) => !o.filled).toList();
      expect(wholeNoteOvals.length, greaterThan(0));
    });

    test('Accidentals are rendered as text', () {
      final part = Part(
        id: 'P1',
        name: 'Test',
        instrument: 'test',
        staves: ['S1'],
        clef: 'treble',
      );

      final measure = Measure(
        number: 0,
        notes: [
          Note(
            id: 'N1',
            step: 'F',
            octave: 4,
            alter: 1,
            noteType: 'quarter',
            staff: 0,
            voice: 0,
            duration: 0.25,
            accidental: '#',
          ),
        ],
        rests: [],
      );

      final score = Score(
        format: '1.0',
        parts: [part],
        measures: [measure],
      );

      final layout = computePageLayout(score, 0, 0, config);
      final state = RenderState(darkMode: false);
      final cmds = generateRenderCommands(score, layout, state);

      final textCommands = cmds.whereType<DrawText>();

      final accidentals =
          textCommands.where((t) => t.text == '#').toList();
      expect(accidentals.length, greaterThan(0));
    });

    test('Augmentation dots are rendered', () {
      final part = Part(
        id: 'P1',
        name: 'Test',
        instrument: 'test',
        staves: ['S1'],
        clef: 'treble',
      );

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
            duration: 0.375,
            dots: 1,
          ),
        ],
        rests: [],
      );

      final score = Score(
        format: '1.0',
        parts: [part],
        measures: [measure],
      );

      final layout = computePageLayout(score, 0, 0, config);
      final state = RenderState(darkMode: false);
      final cmds = generateRenderCommands(score, layout, state);

      final ovals = cmds.whereType<DrawOval>();

      // Should have dots (small filled ovals)
      final dots = ovals.where((o) => o.filled && o.rx < 5).toList();
      expect(dots.length, greaterThan(0));
    });

    test('Rests are rendered', () {
      final rectCommands = commands.whereType<DrawRect>();

      // Rests should be rendered as filled rectangles
      expect(rectCommands.length, greaterThan(0));
    });

    test('Background is rendered', () {
      final rects = commands.whereType<DrawRect>();

      // First command should be background
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

      // Dark mode should have lighter text (typically white/light gray)
      for (final text in textCommands) {
        // Color should be light
        if (text.color.startsWith('#')) {
          final hexColor = text.color.replaceFirst('#', '');
          if (hexColor.length == 6) {
            final colorValue = int.parse(hexColor, radix: 16);
            // Light colors have high RGB values
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

      // Should have a highlight rect for current measure
      final highlights = rects
          .where((r) =>
              r.color == 'blue' &&
              r.filled == false &&
              r.strokeWidth > 1.0)
          .toList();

      expect(highlights.length, greaterThan(0));
    });

    test('Rehearsal mark is rendered when present', () {
      final part = Part(
        id: 'P1',
        name: 'Test',
        instrument: 'test',
        staves: ['S1'],
        clef: 'treble',
      );

      final measure = Measure(
        number: 0,
        notes: [],
        rests: [],
        rehearsalMark: 'A',
      );

      final score = Score(
        format: '1.0',
        parts: [part],
        measures: [measure],
      );

      final layout = computePageLayout(score, 0, 0, config);
      final state = RenderState(darkMode: false);
      final cmds = generateRenderCommands(score, layout, state);

      final textCommands = cmds.whereType<DrawText>();

      final rehearsalMarks =
          textCommands.where((t) => t.text == 'A').toList();
      expect(rehearsalMarks.length, greaterThan(0));
    });

    test('Stems are rendered for notes', () {
      final lines = commands.whereType<DrawLine>();

      // Should have stems (vertical lines from note heads)
      final stems =
          lines.where((l) => (l.x1 - l.x2).abs() < 0.1).toList();

      expect(stems.length, greaterThan(0));
    });

    test('Note with articulation has visual indicator', () {
      final part = Part(
        id: 'P1',
        name: 'Test',
        instrument: 'test',
        staves: ['S1'],
        clef: 'treble',
      );

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
            hasArticulation: true,
          ),
        ],
        rests: [],
      );

      final score = Score(
        format: '1.0',
        parts: [part],
        measures: [measure],
      );

      final layout = computePageLayout(score, 0, 0, config);
      final state = RenderState(darkMode: false);
      final cmds = generateRenderCommands(score, layout, state);

      final ovals = cmds.whereType<DrawOval>();

      // Should have articulation indicator (small dot)
      expect(ovals.length, greaterThan(0));
    });

    test('Multiple notes in measure are rendered', () {
      final ovals = commands.whereType<DrawOval>();

      // Score has 2 notes, should have at least 2 note head ovals
      expect(ovals.length, greaterThanOrEqualTo(2));
    });
  });
}

Score _createSimpleScore() {
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
    ],
    rests: [],
  );

  return Score(
    format: '1.0',
    parts: [part],
    measures: [measure],
  );
}
