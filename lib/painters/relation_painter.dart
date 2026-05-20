import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/person.dart';
import '../models/relationship.dart';
import '../constants/app_theme.dart';

class RelationPainter {
  static const double _nodeHalf = kNodeSize / 2;

  static void paintRelationship(
    Canvas canvas,
    Relationship rel,
    Person source,
    Person target, {
    bool selected = false,
  }) {
    final p1 = source.position + const Offset(_nodeHalf, _nodeHalf);
    final p2 = target.position + const Offset(_nodeHalf, _nodeHalf);

    final color = kRelationshipColors[rel.type] ?? kText2;

    if (selected) {
      final haloPaint = Paint()
        ..color = kAccentGreen.withOpacity(0.25)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, haloPaint);
    }

    switch (rel.type) {
      case RelationshipType.married:
        _drawDoubleParallelLine(canvas, p1, p2, color, 3.0);
      case RelationshipType.partnership:
        _drawSingleLine(canvas, p1, p2, color, 1.5);
      case RelationshipType.separated:
        _drawDashedLine(canvas, p1, p2, color, 1.5, 8, 4);
      case RelationshipType.divorced:
        _drawDivorcedLine(canvas, p1, p2, color);
      case RelationshipType.engaged:
        _drawDashedLine(canvas, p1, p2, color, 1.5, 3, 3);
      case RelationshipType.parentChild:
        _drawSingleLine(canvas, p1, p2, color, 1.5);
      case RelationshipType.sibling:
        _drawSingleLine(canvas, p1, p2, color, 1.5);
      case RelationshipType.close:
        _drawDoubleParallelLine(canvas, p1, p2, color, 3.0);
      case RelationshipType.veryClose:
        _drawTripleParallelLine(canvas, p1, p2, color, 4.0);
      case RelationshipType.enmeshed:
        _drawTripleParallelLine(canvas, p1, p2, color, 4.0);
      case RelationshipType.distant:
        _drawSingleLine(canvas, p1, p2, color, 0.8);
      case RelationshipType.conflicted:
        _drawZigzag(canvas, p1, p2, color, 8, 8);
      case RelationshipType.estranged:
        _drawCutoffLine(canvas, p1, p2, color);
      case RelationshipType.fusedConflicted:
        _drawFusedConflicted(canvas, p1, p2, color);
      case RelationshipType.abusive:
        _drawZigzag(canvas, p1, p2, const Color(0xFFCC2222), 8, 8);
    }
  }

  static bool hitTest(Relationship rel, Person source, Person target, Offset tap) {
    final p1 = source.position + const Offset(_nodeHalf, _nodeHalf);
    final p2 = target.position + const Offset(_nodeHalf, _nodeHalf);
    return _distanceToSegment(tap, p1, p2) < 12.0;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLen2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLen2 == 0) return (p - a).distance;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLen2;
    final tClamped = t.clamp(0.0, 1.0);
    final closest = Offset(a.dx + ab.dx * tClamped, a.dy + ab.dy * tClamped);
    return (p - closest).distance;
  }

  static void _drawSingleLine(
      Canvas canvas, Offset p1, Offset p2, Color color, double width) {
    canvas.drawLine(
      p1, p2,
      Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round,
    );
  }

  static void _drawDoubleParallelLine(
      Canvas canvas, Offset p1, Offset p2, Color color, double offset) {
    final n = _normal(p1, p2);
    final paint = Paint()..color = color..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawLine(p1 + n * offset, p2 + n * offset, paint);
    canvas.drawLine(p1 - n * offset, p2 - n * offset, paint);
  }

  static void _drawTripleParallelLine(
      Canvas canvas, Offset p1, Offset p2, Color color, double offset) {
    final n = _normal(p1, p2);
    final paint = Paint()..color = color..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, paint);
    canvas.drawLine(p1 + n * offset, p2 + n * offset, paint);
    canvas.drawLine(p1 - n * offset, p2 - n * offset, paint);
  }

  static void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color,
      double width, double dashLen, double gapLen) {
    final paint = Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final nx = dx / len;
    final ny = dy / len;
    double d = 0;
    bool drawing = true;
    while (d < len) {
      final segEnd = (d + (drawing ? dashLen : gapLen)).clamp(0.0, len);
      if (drawing) {
        canvas.drawLine(
          Offset(p1.dx + nx * d, p1.dy + ny * d),
          Offset(p1.dx + nx * segEnd, p1.dy + ny * segEnd),
          paint,
        );
      }
      d += drawing ? dashLen : gapLen;
      drawing = !drawing;
    }
  }

  static void _drawDivorcedLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    _drawDoubleParallelLine(canvas, p1, p2, color, 3.0);
    final n = _normal(p1, p2);
    final paint = Paint()..color = color..strokeWidth = 2.0..strokeCap = StrokeCap.round;
    for (final t in [0.4, 0.6]) {
      final mid = Offset(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
      canvas.drawLine(mid + n * 10, mid - n * 10, paint);
    }
  }

  static void _drawZigzag(
      Canvas canvas, Offset p1, Offset p2, Color color, double amplitude, double freq) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final n = _normal(p1, p2);
    final steps = math.max(4, (len / freq).round());
    final path = Path()..moveTo(p1.dx, p1.dy);
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final bx = p1.dx + dx * t;
      final by = p1.dy + dy * t;
      final side = (i % 2 == 0) ? 1.0 : -1.0;
      path.lineTo(bx + n.dx * amplitude * side, by + n.dy * amplitude * side);
    }
    path.lineTo(p2.dx, p2.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  static void _drawCutoffLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final n = _normal(p1, p2);
    _drawDashedLine(canvas, p1, Offset(mid.dx - 8, mid.dy - 8), color, 1.5, 8, 6);
    _drawDashedLine(canvas, Offset(mid.dx + 8, mid.dy + 8), p2, color, 1.5, 8, 6);
    canvas.drawLine(
      mid - n * 12,
      mid + n * 12,
      Paint()..color = color..strokeWidth = 3..strokeCap = StrokeCap.round,
    );
  }

  static void _drawFusedConflicted(Canvas canvas, Offset p1, Offset p2, Color color) {
    _drawTripleParallelLine(canvas, p1, p2, color, 4.0);
    _drawZigzag(canvas, p1, p2, const Color(0xFFFF6B6B), 5, 7);
  }

  static Offset _normal(Offset p1, Offset p2) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return Offset.zero;
    return Offset(-dy / len, dx / len);
  }
}
