/// Generate platform-agnostic render commands from layout
/// Pure Dart implementation with no Flutter dependencies

import 'models.dart';

/// Generate render commands for a page
List<RenderCommand> generateRenderCommands(
  Score score,
  PageLayout layout,
  RenderState state,
) {
  final commands = <RenderCommand>[];
  final config = layout.config;

  // Background
  commands.add(DrawRect(
    x: 0,
    y: 0,
    width: layout.canvasWidth,
    height: layout.canvasHeight,
    filled: true,
    color: state.darkMode ? '#1a1a1a' : '#ffffff',
  ));

  // Page border
  commands.add(DrawRect(
    x: layout.pageMargins.left,
    y: layout.pageMargins.top,
    width: layout.canvasWidth - layout.pageMargins.left - layout.pageMargins.right,
    height: layout.canvasHeight - layout.pageMargins.top - layout.pageMargins.bottom,
    filled: false,
    strokeWidth: 1.0,
    color: state.darkMode ? '#444444' : '#cccccc',
  ));

  // Render each system
  for (final system in layout.systems) {
    // Render staves (5 lines per staff)
    for (final stave in system.staves) {
      _addStaffLines(commands, stave, config, state);
    }

    // Render measures
    for (final measure in system.measures) {
      _addMeasureElements(commands, measure, config, state);
    }

    // Render highlights for current measure
    if (state.currentMeasure != null) {
      for (final measure in system.measures) {
        if (measure.measureNumber == state.currentMeasure) {
          commands.add(DrawRect(
            x: measure.bounds.x,
            y: measure.bounds.y,
            width: measure.bounds.width,
            height: measure.bounds.height,
            filled: false,
            strokeWidth: 3.0,
            color: state.highlightColor,
            opacity: config.currentPositionOpacity,
          ));
        }
      }
    }
  }

  return commands;
}

/// Add staff lines to command list
void _addStaffLines(
  List<RenderCommand> commands,
  StaveLayout stave,
  LayoutConfig config,
  RenderState state,
) {
  final lineColor = state.darkMode ? '#cccccc' : '#000000';
  final y = stave.bounds.y;
  final x1 = stave.bounds.x;
  final x2 = stave.bounds.x + stave.bounds.width;
  final spacing = config.staffLineSpacing;

  // 5 staff lines
  for (int i = 0; i < 5; i++) {
    final lineY = y + (i * spacing);
    commands.add(DrawLine(
      x1: x1,
      y1: lineY,
      x2: x2,
      y2: lineY,
      strokeWidth: 1.0,
      color: lineColor,
    ));
  }
}

/// Add measure elements to command list
void _addMeasureElements(
  List<RenderCommand> commands,
  MeasureLayout measure,
  LayoutConfig config,
  RenderState state,
) {
  final textColor = state.darkMode ? '#ffffff' : '#000000';

  // Measure number (if enabled)
  if (config.showMeasureNumbers && measure.measureNumber % 5 == 0) {
    commands.add(DrawText(
      text: (measure.measureNumber + 1).toString(),
      x: measure.bounds.x + 5,
      y: measure.bounds.y - 15,
      fontSize: 10.0,
      color: textColor,
    ));
  }

  // Time signature (at measure start)
  if (measure.timeSignature != null && measure.measureNumber == 0) {
    commands.add(DrawText(
      text: measure.timeSignature!,
      x: measure.bounds.x + 5,
      y: measure.bounds.y + (config.staffHeight / 2),
      fontSize: 14.0,
      color: textColor,
      fontWeight: 'bold',
    ));
  }

  // Key signature (at measure start)
  if (measure.keySignature != null && measure.measureNumber == 0) {
    commands.add(DrawText(
      text: measure.keySignature!,
      x: measure.bounds.x + 35,
      y: measure.bounds.y + (config.staffHeight / 2),
      fontSize: 12.0,
      color: textColor,
    ));
  }

  // Rehearsal mark (if present)
  if (measure.rehearsalMark != null && config.showRehearsalMarks) {
    commands.add(DrawRect(
      x: measure.bounds.x + (measure.bounds.width / 2) - 12,
      y: measure.bounds.y - 20,
      width: 24,
      height: 20,
      filled: false,
      strokeWidth: 1.0,
      color: textColor,
    ));

    commands.add(DrawText(
      text: measure.rehearsalMark!,
      x: measure.bounds.x + (measure.bounds.width / 2) - 5,
      y: measure.bounds.y - 15,
      fontSize: 12.0,
      color: textColor,
      fontWeight: 'bold',
    ));
  }

  // Render notes and rests
  for (final note in measure.notes) {
    _addNoteElement(commands, note, measure, config, state);
  }

  // Barlines
  _addBarlines(commands, measure, config, state);

  // Repeat signs
  if (measure.hasRepeatStart) {
    _addRepeatStartSign(commands, measure, config, state);
  }

  if (measure.hasRepeatEnd) {
    _addRepeatEndSign(commands, measure, config, state);
  }
}

/// Add note or rest to command list
void _addNoteElement(
  List<RenderCommand> commands,
  NoteLayout note,
  MeasureLayout measure,
  LayoutConfig config,
  RenderState state,
) {
  final noteColor = state.darkMode ? '#ffffff' : '#000000';

  if (note.isRest) {
    // Render rest symbol (simplified vertical rectangle)
    commands.add(DrawRect(
      x: note.bounds.x,
      y: note.bounds.y - (note.bounds.height / 2),
      width: note.bounds.width,
      height: note.bounds.height,
      filled: true,
      color: noteColor,
    ));
  } else {
    // Render note head (oval)
    final isWholeNote = note.noteType == 'whole';
    commands.add(DrawOval(
      cx: note.bounds.x + (note.bounds.width / 2),
      cy: note.bounds.y + (note.bounds.height / 2),
      rx: note.bounds.width / 2,
      ry: note.bounds.height / 2,
      filled: !isWholeNote, // Whole notes are hollow
      color: noteColor,
      strokeWidth: 1.5,
    ));

    // Render stem (if not whole note)
    if (note.noteType != 'whole' && note.stemDirection != 'none') {
      final stemX =
          note.stemDirection == 'up' ? note.bounds.x + note.bounds.width : note.bounds.x;
      final stemTopY = note.bounds.y - 35;
      final stemBottomY = note.bounds.y + note.bounds.height;

      commands.add(DrawLine(
        x1: stemX,
        y1: stemTopY,
        x2: stemX,
        y2: stemBottomY,
        strokeWidth: 1.0,
        color: noteColor,
      ));
    }

    // Render accidental (if present)
    if (note.accidental != null) {
      commands.add(DrawText(
        text: note.accidental!,
        x: note.bounds.x - 8,
        y: note.bounds.y,
        fontSize: 10.0,
        color: noteColor,
      ));
    }

    // Render augmentation dots
    for (int i = 0; i < note.dots; i++) {
      commands.add(DrawOval(
        cx: note.bounds.x + note.bounds.width + 6 + (i * 4),
        cy: note.bounds.y + (note.bounds.height / 2),
        rx: 1.5,
        ry: 1.5,
        filled: true,
        color: noteColor,
      ));
    }

    // Render articulations
    if (note.hasArticulation) {
      // Simplified: just a dot above/below
      commands.add(DrawOval(
        cx: note.bounds.x + (note.bounds.width / 2),
        cy: note.bounds.y - 12,
        rx: 2.0,
        ry: 2.0,
        filled: true,
        color: noteColor,
      ));
    }

    // Render dynamics
    if (note.hasDynamic) {
      commands.add(DrawText(
        text: 'mp',
        x: note.bounds.x - 5,
        y: measure.bounds.y + config.staffHeight + 8,
        fontSize: 9.0,
        color: noteColor,
      ));
    }
  }
}

/// Add barlines to command list
void _addBarlines(
  List<RenderCommand> commands,
  MeasureLayout measure,
  LayoutConfig config,
  RenderState state,
) {
  final lineColor = state.darkMode ? '#cccccc' : '#000000';
  final x = measure.bounds.x + measure.bounds.width;
  final y1 = measure.bounds.y;
  final y2 = measure.bounds.y + measure.bounds.height;

  // Right barline (single)
  commands.add(DrawLine(
    x1: x,
    y1: y1,
    x2: x,
    y2: y2,
    strokeWidth: 1.0,
    color: lineColor,
  ));

  // Last measure gets final barline (double)
  if (measure.hasRepeatEnd) {
    commands.add(DrawLine(
      x1: x + 3,
      y1: y1,
      x2: x + 3,
      y2: y2,
      strokeWidth: 2.0,
      color: lineColor,
    ));
  }
}

/// Add repeat start sign
void _addRepeatStartSign(
  List<RenderCommand> commands,
  MeasureLayout measure,
  LayoutConfig config,
  RenderState state,
) {
  final lineColor = state.darkMode ? '#cccccc' : '#000000';
  final x = measure.bounds.x;
  final y1 = measure.bounds.y;
  final y2 = measure.bounds.y + measure.bounds.height;

  // Repeat start: two thin lines, then thick line
  commands.add(DrawLine(
    x1: x - 4,
    y1: y1,
    x2: x - 4,
    y2: y2,
    strokeWidth: 1.0,
    color: lineColor,
  ));

  commands.add(DrawLine(
    x1: x - 2,
    y1: y1,
    x2: x - 2,
    y2: y2,
    strokeWidth: 2.0,
    color: lineColor,
  ));

  // Dots
  final dotY1 = y1 + (config.staffLineSpacing * 1.5);
  final dotY2 = y1 + (config.staffLineSpacing * 2.5);

  commands.add(DrawOval(
    cx: x + 4,
    cy: dotY1,
    rx: 2.0,
    ry: 2.0,
    filled: true,
    color: lineColor,
  ));

  commands.add(DrawOval(
    cx: x + 4,
    cy: dotY2,
    rx: 2.0,
    ry: 2.0,
    filled: true,
    color: lineColor,
  ));
}

/// Add repeat end sign
void _addRepeatEndSign(
  List<RenderCommand> commands,
  MeasureLayout measure,
  LayoutConfig config,
  RenderState state,
) {
  final lineColor = state.darkMode ? '#cccccc' : '#000000';
  final x = measure.bounds.x + measure.bounds.width;
  final y1 = measure.bounds.y;
  final y2 = measure.bounds.y + measure.bounds.height;

  // Repeat end: thick line, then two thin lines
  commands.add(DrawLine(
    x1: x + 2,
    y1: y1,
    x2: x + 2,
    y2: y2,
    strokeWidth: 2.0,
    color: lineColor,
  ));

  commands.add(DrawLine(
    x1: x + 4,
    y1: y1,
    x2: x + 4,
    y2: y2,
    strokeWidth: 1.0,
    color: lineColor,
  ));

  // Dots
  final dotY1 = y1 + (config.staffLineSpacing * 1.5);
  final dotY2 = y1 + (config.staffLineSpacing * 2.5);

  commands.add(DrawOval(
    cx: x - 4,
    cy: dotY1,
    rx: 2.0,
    ry: 2.0,
    filled: true,
    color: lineColor,
  ));

  commands.add(DrawOval(
    cx: x - 4,
    cy: dotY2,
    rx: 2.0,
    ry: 2.0,
    filled: true,
    color: lineColor,
  ));
}
