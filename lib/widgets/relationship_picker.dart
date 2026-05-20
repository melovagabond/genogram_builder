import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/relationship.dart';
import '../providers/genogram_provider.dart';
import '../constants/app_theme.dart';

class RelationshipPickerSheet extends StatelessWidget {
  final String sourceId;
  final String targetId;
  final GenogramProvider provider;

  const RelationshipPickerSheet({
    super.key,
    required this.sourceId,
    required this.targetId,
    required this.provider,
  });

  static const _categoryOrder = [
    'Structural', 'Neutral', 'Positive', 'Negative',
    'Violence', 'Abuse', 'Control', 'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final srcName = provider.persons[sourceId]?.name;
    final tgtName = provider.persons[targetId]?.name;
    final from = (srcName?.isNotEmpty == true) ? srcName! : 'Person';
    final to   = (tgtName?.isNotEmpty == true) ? tgtName! : 'Person';

    // Group by category
    final Map<String, List<RelationshipType>> grouped = {};
    for (final t in RelationshipType.values) {
      final cat = kRelationshipDefs[t]!.category;
      grouped.putIfAbsent(cat, () => []).add(t);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // Handle + header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)),
              ),
              const Text('SELECT RELATIONSHIP TYPE',
                  style: TextStyle(color: kAccent, fontSize: 11, fontFamily: 'monospace', letterSpacing: 2)),
              const SizedBox(height: 4),
              Text('$from  ->  $to',
                  style: const TextStyle(color: kText2, fontSize: 12)),
            ]),
          ),
          const Divider(color: kBorder, height: 1),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              children: [
                for (final cat in _categoryOrder)
                  if (grouped.containsKey(cat)) ...[
                    _catHeader(cat),
                    ...grouped[cat]!.map((t) => _relOption(context, t)),
                    const SizedBox(height: 4),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _catHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Text(text.toUpperCase(),
            style: const TextStyle(color: kText3, fontSize: 9, fontFamily: 'monospace', letterSpacing: 1.5)),
      );

  Widget _relOption(BuildContext context, RelationshipType type) {
    final def = kRelationshipDefs[type]!;
    final color = kRelationshipColors[type] ?? kText2;
    return InkWell(
      onTap: () {
        provider.addRelationship(sourceId, targetId, type);
        if (provider.mode == AppMode.connect) provider.cancelConnect();
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(
          color: kSurface2,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          SizedBox(
            width: 64,
            height: 22,
            child: CustomPaint(painter: _RelPreviewPainter(type: type, color: color)),
          ),
          const SizedBox(width: 12),
          Text(def.label, style: const TextStyle(color: kText, fontSize: 12)),
        ]),
      ),
    );
  }
}

// ----------------------------------------------------------------
// Preview painter -- mirrors RelationPainter logic at small scale
// ----------------------------------------------------------------
class _RelPreviewPainter extends CustomPainter {
  final RelationshipType type;
  final Color color;
  _RelPreviewPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Offset(2, size.height / 2);
    final p2 = Offset(size.width - 2, size.height / 2);

    switch (type) {
      case RelationshipType.married || RelationshipType.harmony:
        _dbl(canvas, p1, p2);
      case RelationshipType.friendship || RelationshipType.fused ||
           RelationshipType.love || RelationshipType.inLove:
        _triple(canvas, p1, p2);
        if (type == RelationshipType.love || type == RelationshipType.inLove) {
          _circleMark(canvas, p1, p2, 2, filled: type == RelationshipType.inLove);
        }
      case RelationshipType.separated || RelationshipType.distrust:
        _dash(canvas, p1, p2, 6, 3);
      case RelationshipType.engaged:
        _dash(canvas, p1, p2, 2, 2);
      case RelationshipType.divorced:
        _dbl(canvas, p1, p2);
        final mid = Offset(size.width / 2, size.height / 2);
        canvas.drawLine(Offset(mid.dx - 4, mid.dy - 6), Offset(mid.dx - 2, mid.dy + 6),
            Paint()..color = color..strokeWidth = 1.5);
        canvas.drawLine(Offset(mid.dx + 2, mid.dy - 6), Offset(mid.dx + 4, mid.dy + 6),
            Paint()..color = color..strokeWidth = 1.5);
      case RelationshipType.plain:
        _dot(canvas, p1, p2);
      case RelationshipType.indifferent:
        _dash(canvas, p1, p2, 3, 5);
      case RelationshipType.distant:
        _dash(canvas, p1, p2, 8, 8);
      case RelationshipType.cutoff:
        _cutoffPreview(canvas, p1, p2);
      case RelationshipType.discord:
        _zig(canvas, p1, p2, 4, 8);
      case RelationshipType.hostile || RelationshipType.abuse:
        _zig(canvas, p1, p2, 5, 7);
      case RelationshipType.distantHostile:
        _zig(canvas, p1, p2, 5, 12);
      case RelationshipType.closeHostile:
        _dblZig(canvas, p1, p2, 4, 7, 3.5);
      case RelationshipType.fusedHostile:
        _triZig(canvas, p1, p2, 4, 7, 3.5);
      case RelationshipType.violence:
        _zig(canvas, p1, p2, 6, 6);
      case RelationshipType.distantViolence:
        _zig(canvas, p1, p2, 6, 12);
      case RelationshipType.closeViolence:
        _dblZig(canvas, p1, p2, 5, 6, 4.0);
      case RelationshipType.fusedViolence:
        _triZig(canvas, p1, p2, 5, 6, 4.0);
      case RelationshipType.physicalAbuse:
        _zig(canvas, p1, p2, 7, 5);
      case RelationshipType.emotionalAbuse:
        _zig(canvas, p1, p2, 5, 6);
      case RelationshipType.sexualAbuse:
        _dash(canvas, p1, p2, 4, 4);
        _zig(canvas, Offset(p1.dx, p1.dy - 3), Offset(p2.dx, p2.dy - 3), 3, 7);
      case RelationshipType.neglect:
        _dash(canvas, p1, p2, 5, 4);
        _arrowTip(canvas, p1, p2);
      case RelationshipType.manipulative:
        _line(canvas, p1, p2);
        final mid = Offset(size.width / 2, size.height / 2);
        canvas.drawLine(Offset(mid.dx - 6, mid.dy - 6), Offset(mid.dx + 6, mid.dy + 6),
            Paint()..color = color..strokeWidth = 1.2);
        canvas.drawLine(Offset(mid.dx + 6, mid.dy - 6), Offset(mid.dx - 6, mid.dy + 6),
            Paint()..color = color..strokeWidth = 1.2);
      case RelationshipType.controlling:
        _line(canvas, p1, p2);
        final mid2 = Offset(size.width / 2, size.height / 2);
        final xPaint = Paint()..color = color..strokeWidth = 1.5;
        canvas.drawLine(Offset(mid2.dx - 7, mid2.dy - 7), Offset(mid2.dx + 7, mid2.dy + 7), xPaint);
        canvas.drawLine(Offset(mid2.dx + 7, mid2.dy - 7), Offset(mid2.dx - 7, mid2.dy + 7), xPaint);
      case RelationshipType.jealous:
        _line(canvas, p1, p2);
        _circleMark(canvas, p1, p2, 3, filled: false);
      case RelationshipType.focusedOn:
        _line(canvas, p1, p2);
        _arrowTip(canvas, p1, p2);
      case RelationshipType.fanAdmirer:
        _line(canvas, p1, p2);
        _circleMark(canvas, p1, p2, 4, filled: false);
      case RelationshipType.limerence:
        _line(canvas, p1, p2);
        _circleMark(canvas, p1, p2, 4, filled: true);
      case RelationshipType.neverMet:
        _dash(canvas, p1, p2, 5, 5);
        final mid3 = Offset(size.width / 2, size.height / 2);
        canvas.drawRect(Rect.fromCenter(center: mid3, width: 8, height: 8),
            Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2);
      default:
        _dot(canvas, p1, p2);
    }
  }

  Paint _p([double w = 1.2]) => Paint()..color = color..strokeWidth = w..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;

  void _line(Canvas c, Offset p1, Offset p2) => c.drawLine(p1, p2, _p(1.2));
  void _dbl(Canvas c, Offset p1, Offset p2) {
    c.drawLine(Offset(p1.dx, p1.dy - 2), Offset(p2.dx, p2.dy - 2), _p(1.1));
    c.drawLine(Offset(p1.dx, p1.dy + 2), Offset(p2.dx, p2.dy + 2), _p(1.1));
  }
  void _triple(Canvas c, Offset p1, Offset p2) {
    c.drawLine(p1, p2, _p(1.0));
    c.drawLine(Offset(p1.dx, p1.dy - 3), Offset(p2.dx, p2.dy - 3), _p(1.0));
    c.drawLine(Offset(p1.dx, p1.dy + 3), Offset(p2.dx, p2.dy + 3), _p(1.0));
  }
  void _dot(Canvas c, Offset p1, Offset p2) => _dash(c, p1, p2, 1.5, 4);
  void _dash(Canvas c, Offset p1, Offset p2, double d, double g) {
    final len = (p2 - p1).distance;
    final nx = (p2.dx - p1.dx) / len, ny = (p2.dy - p1.dy) / len;
    double dist = 0; bool on = true;
    while (dist < len) {
      final sl = on ? d : g;
      final e = (dist + sl).clamp(0.0, len);
      if (on) c.drawLine(Offset(p1.dx + nx * dist, p1.dy + ny * dist), Offset(p1.dx + nx * e, p1.dy + ny * e), _p());
      dist += sl; on = !on;
    }
  }
  void _zig(Canvas c, Offset p1, Offset p2, double amp, double freq) {
    final dx = p2.dx - p1.dx, dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final steps = math.max(4, (len / freq).round());
    final path = Path()..moveTo(p1.dx, p1.dy);
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final s = (i % 2 == 0) ? 1.0 : -1.0;
      path.lineTo(p1.dx + dx * t, p1.dy + dy * t - amp * s);
    }
    path.lineTo(p2.dx, p2.dy);
    c.drawPath(path, _p(1.5)..strokeJoin = StrokeJoin.round);
  }
  void _dblZig(Canvas c, Offset p1, Offset p2, double amp, double freq, double off) {
    _zig(c, Offset(p1.dx, p1.dy - off), Offset(p2.dx, p2.dy - off), amp, freq);
    _zig(c, Offset(p1.dx, p1.dy + off), Offset(p2.dx, p2.dy + off), amp, freq);
  }
  void _triZig(Canvas c, Offset p1, Offset p2, double amp, double freq, double off) {
    _zig(c, p1, p2, amp, freq);
    _zig(c, Offset(p1.dx, p1.dy - off), Offset(p2.dx, p2.dy - off), amp, freq);
    _zig(c, Offset(p1.dx, p1.dy + off), Offset(p2.dx, p2.dy + off), amp, freq);
  }
  void _cutoffPreview(Canvas c, Offset p1, Offset p2) {
    final mid = Offset((p1.dx + p2.dx) / 2, p1.dy);
    _dash(c, p1, Offset(mid.dx - 4, mid.dy), 4, 3);
    _dash(c, Offset(mid.dx + 4, mid.dy), p2, 4, 3);
    c.drawLine(Offset(mid.dx, mid.dy - 7), Offset(mid.dx, mid.dy + 7), _p(2.0));
  }
  void _arrowTip(Canvas c, Offset p1, Offset p2) {
    c.drawLine(p2, Offset(p2.dx - 6, p2.dy - 5), _p(1.2));
    c.drawLine(p2, Offset(p2.dx - 6, p2.dy + 5), _p(1.2));
  }
  void _circleMark(Canvas c, Offset p1, Offset p2, int count, {required bool filled}) {
    final dx = p2.dx - p1.dx;
    for (int i = 1; i <= count; i++) {
      final t = i / (count + 1);
      final center = Offset(p1.dx + dx * t, p1.dy);
      if (filled) {
        c.drawCircle(center, 3, Paint()..color = color..style = PaintingStyle.fill);
      } else {
        c.drawCircle(center, 3, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.0);
      }
    }
  }

  @override
  bool shouldRepaint(_RelPreviewPainter old) => false;
}