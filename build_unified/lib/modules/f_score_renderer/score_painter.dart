/// Flutter CustomPainter for rendering score
/// This is the ONLY file with Flutter dependencies

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'models.dart';

/// CustomPainter that executes render commands on Canvas
class ScorePainter extends CustomPainter {
  final List<RenderCommand> commands;
  final Size? preferredSize;

  ScorePainter({
    required this.commands,
    this.preferredSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Execute each render command
    for (final command in commands) {
      _executeCommand(canvas, size, command);
    }
  }

  void _executeCommand(Canvas canvas, Size size, RenderCommand command) {
    switch (command) {
      case DrawLine cmd:
        _drawLine(canvas, cmd);
      case DrawOval cmd:
        _drawOval(canvas, cmd);
      case DrawRect cmd:
        _drawRect(canvas, cmd);
      case DrawText cmd:
        _drawText(canvas, cmd);
      case DrawPath cmd:
        _drawPath(canvas, cmd);
    }
  }

  void _drawLine(Canvas canvas, DrawLine cmd) {
    final paint = Paint()
      ..color = _parseColor(cmd.color)
      ..strokeWidth = cmd.strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(cmd.x1, cmd.y1),
      Offset(cmd.x2, cmd.y2),
      paint,
    );
  }

  void _drawOval(Canvas canvas, DrawOval cmd) {
    final paint = Paint()
      ..color = _parseColor(cmd.color)
      ..strokeWidth = cmd.strokeWidth
      ..style = cmd.filled ? PaintingStyle.fill : PaintingStyle.stroke;

    final rect = ui.Rect.fromLTWH(
      cmd.cx - cmd.rx,
      cmd.cy - cmd.ry,
      cmd.rx * 2,
      cmd.ry * 2,
    );

    if (cmd.rotation != 0.0) {
      canvas.save();
      canvas.translate(cmd.cx, cmd.cy);
      canvas.rotate(cmd.rotation);
      canvas.translate(-cmd.cx, -cmd.cy);
      canvas.drawOval(rect, paint);
      canvas.restore();
    } else {
      canvas.drawOval(rect, paint);
    }
  }

  void _drawRect(Canvas canvas, DrawRect cmd) {
    final paint = Paint()
      ..color = _parseColor(cmd.color).withOpacity(cmd.opacity)
      ..strokeWidth = cmd.strokeWidth
      ..style = cmd.filled ? PaintingStyle.fill : PaintingStyle.stroke;

    final rect = ui.Rect.fromLTWH(cmd.x, cmd.y, cmd.width, cmd.height);
    canvas.drawRect(rect, paint);
  }

  void _drawText(Canvas canvas, DrawText cmd) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: cmd.text,
        style: TextStyle(
          color: _parseColor(cmd.color),
          fontSize: cmd.fontSize,
          fontWeight: cmd.fontWeight == 'bold' ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(cmd.x, cmd.y));
  }

  void _drawPath(Canvas canvas, DrawPath cmd) {
    if (cmd.points.isEmpty) return;

    final path = Path();
    path.moveTo(cmd.points[0].$1, cmd.points[0].$2);

    for (int i = 1; i < cmd.points.length; i++) {
      path.lineTo(cmd.points[i].$1, cmd.points[i].$2);
    }

    final paint = Paint()
      ..color = _parseColor(cmd.color)
      ..strokeWidth = cmd.strokeWidth
      ..style = cmd.filled ? PaintingStyle.fill : PaintingStyle.stroke;

    canvas.drawPath(path, paint);
  }

  /// Parse hex color string to Flutter Color
  Color _parseColor(String colorStr) {
    // Remove '#' if present
    String hexColor = colorStr.replaceFirst('#', '');

    // Named colors
    switch (hexColor.toLowerCase()) {
      case 'white':
        return Colors.white;
      case 'black':
        return Colors.black;
      case 'blue':
        return Colors.blue;
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'gray':
      case 'grey':
        return Colors.grey;
      default:
        break;
    }

    // Hex color parsing
    try {
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      } else if (hexColor.length == 8) {
        return Color(int.parse(hexColor, radix: 16));
      }
    } catch (e) {
      // Fall through to default
    }

    return Colors.black;
  }

  @override
  bool shouldRepaint(ScorePainter oldDelegate) {
    return oldDelegate.commands != commands;
  }

  @override
  bool shouldRebuildSemantics(ScorePainter oldDelegate) {
    return false;
  }
}

/// Widget wrapper for ScorePainter
class ScoreView extends StatelessWidget {
  final List<RenderCommand> commands;
  final double width;
  final double height;
  final BoxDecoration? decoration;

  const ScoreView({
    Key? key,
    required this.commands,
    required this.width,
    required this.height,
    this.decoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: decoration,
      child: CustomPaint(
        painter: ScorePainter(commands: commands),
        size: Size(width, height),
      ),
    );
  }
}
