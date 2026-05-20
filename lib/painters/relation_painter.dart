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
      canvas.drawLine(p1, p2,
          Paint()..color = kAccentGreen.withOpacity(0.25)..strokeWidth = 8..style = PaintingStyle.stroke);
    }

    switch (rel.type) {
      // ---- Structural ----
      case RelationshipType.married:
        _doubleParallel(canvas, p1, p2, color, 3.0);
      case RelationshipType.partnership:
        _single(canvas, p1, p2, color, 1.5);
      case RelationshipType.separated:
        _dashed(canvas, p1, p2, color, 1.5, 8, 4);
      case RelationshipType.divorced:
        _divorced(canvas, p1, p2, color);
      case RelationshipType.engaged:
        _dashed(canvas, p1, p2, color, 1.5, 3, 3);
      case RelationshipType.parentChild:
        _single(canvas, p1, p2, color, 1.5);
      case RelationshipType.sibling:
        _single(canvas, p1, p2, color, 1.5);

      // ---- Neutral ----
      // Plain/Normal: dotted
      case RelationshipType.plain:
        _dotted(canvas, p1, p2, color, 1.2);
      // Indifferent: short dashes with gaps
      case RelationshipType.indifferent:
        _dashed(canvas, p1, p2, color, 1.0, 4, 6);
      // Distant/Poor: long sparse dashes
      case RelationshipType.distant:
        _dashed(canvas, p1, p2, color, 0.8, 8, 8);
      // Cutoff/Estranged: dashed with break bar
      case RelationshipType.cutoff:
        _cutoff(canvas, p1, p2, color);

      // ---- Positive ----
      // Harmony: green double line
      case RelationshipType.harmony:
        _doubleParallel(canvas, p1, p2, color, 2.5);
      // Friendship/Close: green triple
      case RelationshipType.friendship:
        _tripleParallel(canvas, p1, p2, color, 3.5);
      // Love: green triple with circle markers (O-O pattern from image)
      case RelationshipType.love:
        _tripleParallel(canvas, p1, p2, color, 3.5);
        _circleMarkers(canvas, p1, p2, color, 3);
      // In Love: green triple with filled circle markers
      case RelationshipType.inLove:
        _tripleParallel(canvas, p1, p2, color, 3.5);
        _circleMarkers(canvas, p1, p2, color, 3, filled: true);
      // Fused: blue triple close parallel
      case RelationshipType.fused:
        _tripleParallel(canvas, p1, p2, color, 4.0);

      // ---- Negative basic ----
      // Distrust: red dashed
      case RelationshipType.distrust:
        _dashed(canvas, p1, p2, color, 1.5, 6, 3);
      // Discord: orange zigzag (moderate)
      case RelationshipType.discord:
        _zigzag(canvas, p1, p2, color, 6, 8, 1.5);
      // Hostile: red zigzag single
      case RelationshipType.hostile:
        _zigzag(canvas, p1, p2, color, 7, 7, 2.0);

      // ---- Hostile variants ----
      // Distant-Hostile: sparse zigzag
      case RelationshipType.distantHostile:
        _zigzag(canvas, p1, p2, color, 7, 12, 1.5);
      // Close-Hostile: double zigzag
      case RelationshipType.closeHostile:
        _doubleZigzag(canvas, p1, p2, color, 7, 7, 5.0);
      // Fused-Hostile: triple zigzag
      case RelationshipType.fusedHostile:
        _tripleZigzag(canvas, p1, p2, color, 7, 7, 5.0);

      // ---- Violence ----
      // Violence: heavy zigzag
      case RelationshipType.violence:
        _zigzag(canvas, p1, p2, color, 9, 6, 2.5);
      // Distant-Violence: sparse heavy zigzag
      case RelationshipType.distantViolence:
        _zigzag(canvas, p1, p2, color, 9, 12, 2.0);
      // Close-Violence: double heavy zigzag
      case RelationshipType.closeViolence:
        _doubleZigzag(canvas, p1, p2, color, 9, 6, 6.0);
      // Fused-Violence: triple heavy zigzag
      case RelationshipType.fusedViolence:
        _tripleZigzag(canvas, p1, p2, color, 9, 6, 6.0);

      // ---- Abuse variants ----
      case RelationshipType.abuse:
        _zigzag(canvas, p1, p2, color, 8, 6, 2.5);
      // Physical Abuse: thick jagged
      case RelationshipType.physicalAbuse:
        _zigzag(canvas, p1, p2, color, 10, 5, 3.5);
      // Emotional Abuse: purple zigzag
      case RelationshipType.emotionalAbuse:
        _zigzag(canvas, p1, p2, color, 8, 6, 2.5);
      // Sexual Abuse: blue dashed zigzag
      case RelationshipType.sexualAbuse:
        _dashedZigzag(canvas, p1, p2, color);
      // Neglect: blue dashed with arrow
      case RelationshipType.neglect:
        _dashedArrow(canvas, p1, p2, color);

      // ---- Control ----
      // Manipulative: orange crossed arrows (X with arrows)
      case RelationshipType.manipulative:
        _crossedArrows(canvas, p1, p2, color, filled: false);
      // Controlling: red crossed arrows (X with filled arrows)
      case RelationshipType.controlling:
        _crossedArrows(canvas, p1, p2, color, filled: true);
      // Jealous: line with small circle markers
      case RelationshipType.jealous:
        _single(canvas, p1, p2, color, 1.0);
        _circleMarkers(canvas, p1, p2, color, 4, filled: false, small: true);
      // Focused On: plain arrow
      case RelationshipType.focusedOn:
        _arrowLine(canvas, p1, p2, color);
      // Fan/Admirer: line with open circle markers
      case RelationshipType.fanAdmirer:
        _single(canvas, p1, p2, color, 1.0);
        _circleMarkers(canvas, p1, p2, color, 5, filled: false);
      // Limerence: line with filled circle markers (hearts)
      case RelationshipType.limerence:
        _single(canvas, p1, p2, color, 1.2);
        _circleMarkers(canvas, p1, p2, color, 5, filled: true);

      // ---- Other ----
      // Never Met: line with box marker in middle
      case RelationshipType.neverMet:
        _neverMet(canvas, p1, p2, color);
      // Other: dotted with question
      case RelationshipType.other:
        _dotted(canvas, p1, p2, color, 1.0);
    }
  }

  // ----------------------------------------------------------------
  // Hit testing
  // ----------------------------------------------------------------
  static bool hitTest(Relationship rel, Person source, Person target, Offset tap) {
    final p1 = source.position + const Offset(_nodeHalf, _nodeHalf);
    final p2 = target.position + const Offset(_nodeHalf, _nodeHalf);
    return _distToSegment(tap, p1, p2) < 12.0;
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / len2;
    final tc = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + ab.dx * tc, a.dy + ab.dy * tc)).distance;
  }

  // ================================================================
  // PRIMITIVES
  // ================================================================

  static Paint _paint(Color color, double width, {bool dashed = false}) =>
      Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;

  static void _single(Canvas c, Offset p1, Offset p2, Color color, double w) =>
      c.drawLine(p1, p2, _paint(color, w));

  static Offset _norm(Offset p1, Offset p2) {
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001) return Offset.zero;
    return Offset(-dy / len, dx / len);
  }

  static void _doubleParallel(Canvas c, Offset p1, Offset p2, Color color, double off) {
    final n = _norm(p1, p2);
    final paint = _paint(color, 1.5);
    c.drawLine(p1 + n * off, p2 + n * off, paint);
    c.drawLine(p1 - n * off, p2 - n * off, paint);
  }

  static void _tripleParallel(Canvas c, Offset p1, Offset p2, Color color, double off) {
    final n = _norm(p1, p2);
    final paint = _paint(color, 1.5);
    c.drawLine(p1, p2, paint);
    c.drawLine(p1 + n * off, p2 + n * off, paint);
    c.drawLine(p1 - n * off, p2 - n * off, paint);
  }

  static void _dashed(Canvas c, Offset p1, Offset p2, Color color, double w, double dash, double gap) {
    final paint = _paint(color, w);
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;
    final nx = dx / len, ny = dy / len;
    double d = 0; bool on = true;
    while (d < len) {
      final sl = on ? dash : gap;
      final e = (d + sl).clamp(0.0, len);
      if (on) c.drawLine(Offset(p1.dx + nx * d, p1.dy + ny * d), Offset(p1.dx + nx * e, p1.dy + ny * e), paint);
      d += sl; on = !on;
    }
  }

  static void _dotted(Canvas c, Offset p1, Offset p2, Color color, double w) =>
      _dashed(c, p1, p2, color, w, 1.5, 4);

  static void _divorced(Canvas c, Offset p1, Offset p2, Color color) {
    _doubleParallel(c, p1, p2, color, 3.0);
    final n = _norm(p1, p2);
    final paint = _paint(color, 2.0);
    for (final t in [0.4, 0.6]) {
      final mid = Offset(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
      c.drawLine(mid + n * 10, mid - n * 10, paint);
    }
  }

  static void _cutoff(Canvas c, Offset p1, Offset p2, Color color) {
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final n = _norm(p1, p2);
    _dashed(c, p1, Offset(mid.dx - 8, mid.dy - 8), color, 1.5, 8, 6);
    _dashed(c, Offset(mid.dx + 8, mid.dy + 8), p2, color, 1.5, 8, 6);
    c.drawLine(mid - n * 12, mid + n * 12, _paint(color, 3.0)..strokeCap = StrokeCap.round);
  }

  // Zigzag variants
  static void _zigzag(Canvas c, Offset p1, Offset p2, Color color,
      double amplitude, double freq, double w) {
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;
    final n = _norm(p1, p2);
    final steps = math.max(4, (len / freq).round());
    final path = Path()..moveTo(p1.dx, p1.dy);
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final side = (i % 2 == 0) ? 1.0 : -1.0;
      path.lineTo(p1.dx + dx * t + n.dx * amplitude * side, p1.dy + dy * t + n.dy * amplitude * side);
    }
    path.lineTo(p2.dx, p2.dy);
    c.drawPath(path, Paint()..color = color..strokeWidth = w..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round);
  }

  static void _doubleZigzag(Canvas c, Offset p1, Offset p2, Color color,
      double amplitude, double freq, double off) {
    final n = _norm(p1, p2);
    _zigzag(c, p1 + n * off, p2 + n * off, color, amplitude, freq, 1.8);
    _zigzag(c, p1 - n * off, p2 - n * off, color, amplitude, freq, 1.8);
  }

  static void _tripleZigzag(Canvas c, Offset p1, Offset p2, Color color,
      double amplitude, double freq, double off) {
    final n = _norm(p1, p2);
    _zigzag(c, p1, p2, color, amplitude, freq, 1.8);
    _zigzag(c, p1 + n * off, p2 + n * off, color, amplitude, freq, 1.8);
    _zigzag(c, p1 - n * off, p2 - n * off, color, amplitude, freq, 1.8);
  }

  static void _dashedZigzag(Canvas c, Offset p1, Offset p2, Color color) {
    // Dashed line below + zigzag above
    final n = _norm(p1, p2);
    _dashed(c, p1 - n * 4, p2 - n * 4, color, 1.2, 6, 4);
    _zigzag(c, p1 + n * 4, p2 + n * 4, color, 5, 7, 1.5);
  }

  static void _dashedArrow(Canvas c, Offset p1, Offset p2, Color color) {
    _dashed(c, p1, p2, color, 1.2, 6, 4);
    _arrowHead(c, p1, p2, color, 1.5);
  }

  static void _arrowLine(Canvas c, Offset p1, Offset p2, Color color) {
    _single(c, p1, p2, color, 1.5);
    _arrowHead(c, p1, p2, color, 1.5);
  }

  static void _arrowHead(Canvas c, Offset p1, Offset p2, Color color, double w) {
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;
    final ux = dx / len, uy = dy / len;
    const aLen = 10.0, aAngle = 0.4;
    final ax1 = p2.dx - aLen * (ux * math.cos(aAngle) - uy * math.sin(aAngle));
    final ay1 = p2.dy - aLen * (uy * math.cos(aAngle) + ux * math.sin(aAngle));
    final ax2 = p2.dx - aLen * (ux * math.cos(-aAngle) - uy * math.sin(-aAngle));
    final ay2 = p2.dy - aLen * (uy * math.cos(-aAngle) + ux * math.sin(-aAngle));
    final paint = _paint(color, w);
    c.drawLine(p2, Offset(ax1, ay1), paint);
    c.drawLine(p2, Offset(ax2, ay2), paint);
  }

  static void _crossedArrows(Canvas c, Offset p1, Offset p2, Color color, {required bool filled}) {
    _single(c, p1, p2, color, 1.2);
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final n = _norm(p1, p2);
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;
    final ux = dx / len, uy = dy / len;
    const r = 10.0;
    // Two diagonal lines through midpoint forming X
    final a1 = mid + Offset((ux + n.dx) * r, (uy + n.dy) * r);
    final a2 = mid - Offset((ux + n.dx) * r, (uy + n.dy) * r);
    final b1 = mid + Offset((ux - n.dx) * r, (uy - n.dy) * r);
    final b2 = mid - Offset((ux - n.dx) * r, (uy - n.dy) * r);
    final paint = _paint(color, 1.5);
    c.drawLine(a1, a2, paint);
    c.drawLine(b1, b2, paint);
    // Arrow heads on each end of cross
    if (filled) {
      _arrowHead(c, a2, a1, color, 1.5);
      _arrowHead(c, a1, a2, color, 1.5);
      _arrowHead(c, b2, b1, color, 1.5);
      _arrowHead(c, b1, b2, color, 1.5);
    }
  }

  static void _circleMarkers(Canvas c, Offset p1, Offset p2, Color color, int count,
      {bool filled = false, bool small = false}) {
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final r = small ? 3.0 : 4.5;
    for (int i = 1; i <= count; i++) {
      final t = i / (count + 1);
      final center = Offset(p1.dx + dx * t, p1.dy + dy * t);
      if (filled) {
        c.drawCircle(center, r, Paint()..color = color..style = PaintingStyle.fill);
      } else {
        c.drawCircle(center, r, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2);
      }
    }
  }

  static void _neverMet(Canvas c, Offset p1, Offset p2, Color color) {
    _dashed(c, p1, p2, color, 1.0, 6, 6);
    // Box in the middle
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final rect = Rect.fromCenter(center: mid, width: 10, height: 10);
    c.drawRect(rect, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }
}