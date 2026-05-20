import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/person.dart';
import '../constants/app_theme.dart';

class NodePainter {
  static const double size = kNodeSize;
  static const double half = size / 2;

  /// Paint a single person node at the given canvas offset.
  static void paintPerson(
    Canvas canvas,
    Person person,
    Offset center, {
    bool selected = false,
    bool isConnectSource = false,
  }) {
    final color = _colorFor(person);

    // Selection ring
    if (selected || isConnectSource) {
      final ringPaint = Paint()
        ..color = isConnectSource ? kAccentOrange : kAccentGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      _drawDashedRect(canvas, center, size + 10, ringPaint);
    }

    // Draw the main shape
    switch (person.specialType) {
      case SpecialType.pregnancy:
        _drawPregnancy(canvas, center, color);
      case SpecialType.miscarriage:
        _drawMiscarriage(canvas, center);
      case SpecialType.abortion:
        _drawAbortion(canvas, center);
      case SpecialType.stillbirth:
        _drawStillbirth(canvas, center, person.gender, color);
      default:
        _drawMainShape(canvas, center, person, color);
    }

    // Markers row below the shape
    _paintMarkers(canvas, center, person);

    // Label text
    _paintLabel(canvas, center, person);
  }

  // ----------------------------------------------------------------
  // Main shapes
  // ----------------------------------------------------------------
  static void _drawMainShape(
      Canvas canvas, Offset center, Person person, Color color) {
    final fillPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = person.markers.indexPerson ? 3.0 : 1.5;

    final rect = Rect.fromCenter(center: center, width: size - 4, height: size - 4);

    if (person.gender == Gender.male) {
      final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
      canvas.drawRRect(rRect, fillPaint);
      canvas.drawRRect(rRect, strokePaint);
    } else if (person.gender == Gender.female) {
      canvas.drawOval(rect, fillPaint);
      canvas.drawOval(rect, strokePaint);
    } else {
      // Diamond
      _drawDiamond(canvas, center, fillPaint, strokePaint);
    }

    // Adopted dashed border overlay
    if (person.markers.adopted) {
      final dashedPaint = Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      _drawDashedRect(canvas, center, size + 4, dashedPaint);
    }

    // Deceased X
    if (person.isDeceased) {
      _drawDeceasedX(canvas, center, color);
    }
  }

  static void _drawDiamond(Canvas canvas, Offset c, Paint fill, Paint stroke) {
    final path = Path()
      ..moveTo(c.dx, c.dy - half + 2)
      ..lineTo(c.dx + half - 2, c.dy)
      ..lineTo(c.dx, c.dy + half - 2)
      ..lineTo(c.dx - half + 2, c.dy)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  static void _drawDeceasedX(Canvas canvas, Offset c, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final inset = half - 6;
    canvas.drawLine(
      Offset(c.dx - inset, c.dy - inset),
      Offset(c.dx + inset, c.dy + inset),
      paint,
    );
    canvas.drawLine(
      Offset(c.dx + inset, c.dy - inset),
      Offset(c.dx - inset, c.dy + inset),
      paint,
    );
  }

  // ----------------------------------------------------------------
  // Special types
  // ----------------------------------------------------------------
  static void _drawPregnancy(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = const Color(0xFF6BFFB8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()
      ..color = const Color(0xFF6BFFB8).withOpacity(0.12)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(center.dx, center.dy - half + 2)
      ..lineTo(center.dx + half - 2, center.dy + half - 2)
      ..lineTo(center.dx - half + 2, center.dy + half - 2)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, paint);
  }

  static void _drawMiscarriage(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = kText2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..moveTo(center.dx, center.dy - half + 2)
      ..lineTo(center.dx + half - 2, center.dy + half - 2)
      ..lineTo(center.dx - half + 2, center.dy + half - 2)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(center.dx - half + 4, center.dy - half + 4),
      Offset(center.dx + half - 4, center.dy + half - 4),
      paint,
    );
  }

  static void _drawAbortion(Canvas canvas, Offset center) {
    _drawMiscarriage(canvas, center);
    final dotPaint = Paint()..color = kText2..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, dotPaint);
  }

  static void _drawStillbirth(Canvas canvas, Offset center, Gender gender, Color color) {
    _drawMainShape(
      canvas,
      center,
      Person(id: '', gender: gender, position: center),
      color,
    );
    _drawDeceasedX(canvas, center, color);
  }

  // ----------------------------------------------------------------
  // Markers
  // ----------------------------------------------------------------
  static void _paintMarkers(Canvas canvas, Offset center, Person person) {
    if (!person.markers.hasAny) return;

    double mx = center.dx - half;
    final my = center.dy + half + 6;

    if (person.markers.substance) {
      canvas.drawRect(
        Rect.fromLTWH(mx, my, 8, 8),
        Paint()..color = kAccentOrange..style = PaintingStyle.fill,
      );
      mx += 10;
    }
    if (person.markers.mental) {
      canvas.drawCircle(
        Offset(mx + 4, my + 4),
        4,
        Paint()..color = kAccentPurple..style = PaintingStyle.fill,
      );
      mx += 10;
    }
    if (person.markers.physical) {
      final triPath = Path()
        ..moveTo(mx + 4, my)
        ..lineTo(mx + 8, my + 8)
        ..lineTo(mx, my + 8)
        ..close();
      canvas.drawPath(triPath, Paint()..color = kAccentRed..style = PaintingStyle.fill);
      mx += 10;
    }
    if (person.markers.abusePerpetrator) {
      _paintSmallText(canvas, 'A', Offset(mx, my), const Color(0xFFCC2222));
      mx += 10;
    }
    if (person.markers.abuseVictim) {
      _paintSmallText(canvas, 'V', Offset(mx, my), kAccentOrange);
      mx += 10;
    }
    if (person.markers.foster) {
      _paintSmallText(canvas, 'F', Offset(mx, my), kAccentGreen);
      mx += 10;
    }
    if (person.markers.indexPerson) {
      _paintSmallText(canvas, 'IP', Offset(mx, my), kAccent);
    }
  }

  static void _paintSmallText(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  // ----------------------------------------------------------------
  // Label
  // ----------------------------------------------------------------
  static void _paintLabel(Canvas canvas, Offset center, Person person) {
    final labelY = center.dy + half + 20;
    final name = person.name.isEmpty ? '?' : person.name;

    final nameTp = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(color: kText, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 100);
    nameTp.paint(canvas, Offset(center.dx - nameTp.width / 2, labelY));

    if (person.yearLabel.isNotEmpty) {
      final yearTp = TextPainter(
        text: TextSpan(
          text: person.yearLabel,
          style: const TextStyle(
            color: kText2,
            fontSize: 9,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 100);
      yearTp.paint(
        canvas,
        Offset(center.dx - yearTp.width / 2, labelY + 13),
      );
    }
  }

  // ----------------------------------------------------------------
  // Hit testing
  // ----------------------------------------------------------------
  static bool hitTest(Person person, Offset tapPoint) {
    final center = person.position + const Offset(half, half);
    final dist = (tapPoint - center).distance;
    return dist <= half + 8;
  }

  // ----------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------
  static Color _colorFor(Person person) {
    return switch (person.gender) {
      Gender.male    => kMaleColor,
      Gender.female  => kFemaleColor,
      Gender.unknown => kUnknownColor,
    };
  }

  static void _drawDashedRect(Canvas canvas, Offset center, double size, Paint paint) {
    const dashLen = 5.0;
    const gapLen = 3.0;
    final rect = Rect.fromCenter(center: center, width: size, height: size);
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint, dashLen, gapLen);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint, dashLen, gapLen);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint, dashLen, gapLen);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint, dashLen, gapLen);
  }

  static void _drawDashedLine(
      Canvas canvas, Offset p1, Offset p2, Paint paint, double dash, double gap) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final nx = dx / len;
    final ny = dy / len;
    double d = 0;
    bool drawing = true;
    while (d < len) {
      final segLen = drawing ? dash : gap;
      final end = (d + segLen).clamp(0, len) as double;
      if (drawing) {
        canvas.drawLine(
          Offset(p1.dx + nx * d, p1.dy + ny * d),
          Offset(p1.dx + nx * end, p1.dy + ny * end),
          paint,
        );
      }
      d += segLen;
      drawing = !drawing;
    }
  }
}
