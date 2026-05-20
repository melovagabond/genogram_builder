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

  @override
  Widget build(BuildContext context) {
    final structural = RelationshipType.values
        .where((t) => kRelationshipDefs[t]!.category == 'Structural')
        .toList();
    final emotional = RelationshipType.values
        .where((t) => kRelationshipDefs[t]!.category == 'Emotional')
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: kBorder, borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'SELECT RELATIONSHIP TYPE',
            style: TextStyle(
              color: kAccent, fontSize: 11,
              fontFamily: 'monospace', letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${provider.persons[sourceId]?.name.isEmpty ?? true ? "Person" : provider.persons[sourceId]!.name}'
            '  ->  '
            '${provider.persons[targetId]?.name.isEmpty ?? true ? "Person" : provider.persons[targetId]!.name}',
            style: const TextStyle(color: kText2, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _categoryHeader('STRUCTURAL'),
          ...structural.map((t) => _relOption(context, t)),
          const SizedBox(height: 8),
          _categoryHeader('EMOTIONAL'),
          ...emotional.map((t) => _relOption(context, t)),
        ],
      ),
    );
  }

  Widget _categoryHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: kText3, fontSize: 10,
            fontFamily: 'monospace', letterSpacing: 1,
          ),
        ),
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: kSurface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          SizedBox(
            width: 60,
            height: 24,
            child: CustomPaint(
              painter: _RelPreviewPainter(type: type, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(def.label, style: const TextStyle(color: kText, fontSize: 13)),
            Text(def.category,
                style: const TextStyle(
                  color: kText3, fontSize: 10, fontFamily: 'monospace',
                )),
          ]),
        ]),
      ),
    );
  }
}

class _RelPreviewPainter extends CustomPainter {
  final RelationshipType type;
  final Color color;

  _RelPreviewPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Offset(4, size.height / 2);
    final p2 = Offset(size.width - 4, size.height / 2);

    switch (type) {
      case RelationshipType.married:
      case RelationshipType.close:
        _drawDouble(canvas, p1, p2);
      case RelationshipType.veryClose:
      case RelationshipType.enmeshed:
        _drawTriple(canvas, p1, p2);
      case RelationshipType.separated:
        _drawDashed(canvas, p1, p2, 6, 3);
      case RelationshipType.engaged:
        _drawDashed(canvas, p1, p2, 2, 2);
      case RelationshipType.divorced:
        _drawDivorcedPreview(canvas, p1, p2);
      case RelationshipType.distant:
        canvas.drawLine(p1, p2, Paint()..color = color..strokeWidth = 0.8);
      case RelationshipType.conflicted:
      case RelationshipType.abusive:
        _drawZigPreview(canvas, p1, p2);
      case RelationshipType.estranged:
        _drawCutoffPreview(canvas, p1, p2);
      case RelationshipType.fusedConflicted:
        _drawTriple(canvas, p1, p2);
        _drawZigPreview(canvas, p1, p2);
      default:
        canvas.drawLine(p1, p2, Paint()..color = color..strokeWidth = 1.5);
    }
  }

  void _drawDouble(Canvas canvas, Offset p1, Offset p2) {
    final paint = Paint()..color = color..strokeWidth = 1.2;
    canvas.drawLine(Offset(p1.dx, p1.dy - 2), Offset(p2.dx, p2.dy - 2), paint);
    canvas.drawLine(Offset(p1.dx, p1.dy + 2), Offset(p2.dx, p2.dy + 2), paint);
  }

  void _drawTriple(Canvas canvas, Offset p1, Offset p2) {
    final paint = Paint()..color = color..strokeWidth = 1.0;
    canvas.drawLine(p1, p2, paint);
    canvas.drawLine(Offset(p1.dx, p1.dy - 3), Offset(p2.dx, p2.dy - 3), paint);
    canvas.drawLine(Offset(p1.dx, p1.dy + 3), Offset(p2.dx, p2.dy + 3), paint);
  }

  void _drawDashed(Canvas canvas, Offset p1, Offset p2, double dash, double gap) {
    final paint = Paint()..color = color..strokeWidth = 1.2;
    final len = (p2 - p1).distance;
    final nx = (p2.dx - p1.dx) / len;
    final ny = (p2.dy - p1.dy) / len;
    double d = 0;
    bool on = true;
    while (d < len) {
      final e = (d + (on ? dash : gap)).clamp(0.0, len);
      if (on) canvas.drawLine(
        Offset(p1.dx + nx * d, p1.dy + ny * d),
        Offset(p1.dx + nx * e, p1.dy + ny * e),
        paint,
      );
      d += on ? dash : gap;
      on = !on;
    }
  }

  void _drawDivorcedPreview(Canvas canvas, Offset p1, Offset p2) {
    _drawDouble(canvas, p1, p2);
    final mid = Offset((p1.dx + p2.dx) / 2, p1.dy);
    canvas.drawLine(Offset(mid.dx - 5, mid.dy - 5),
        Offset(mid.dx - 2, mid.dy + 5),
        Paint()..color = color..strokeWidth = 1.5);
    canvas.drawLine(Offset(mid.dx + 2, mid.dy - 5),
        Offset(mid.dx + 5, mid.dy + 5),
        Paint()..color = color..strokeWidth = 1.5);
  }

  void _drawZigPreview(Canvas canvas, Offset p1, Offset p2) {
    final path = Path()..moveTo(p1.dx, p1.dy);
    final steps = 6;
    final dx = (p2.dx - p1.dx) / steps;
    for (int i = 1; i <= steps; i++) {
      final x = p1.dx + dx * i;
      final y = p1.dy + (i % 2 == 0 ? -5.0 : 5.0);
      path.lineTo(x, y);
    }
    path.lineTo(p2.dx, p2.dy);
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke);
  }

  void _drawCutoffPreview(Canvas canvas, Offset p1, Offset p2) {
    final mid = Offset((p1.dx + p2.dx) / 2, p1.dy);
    _drawDashed(canvas, p1, Offset(mid.dx - 5, mid.dy), 5, 3);
    _drawDashed(canvas, Offset(mid.dx + 5, mid.dy), p2, 5, 3);
    canvas.drawLine(Offset(mid.dx, mid.dy - 6), Offset(mid.dx, mid.dy + 6),
        Paint()..color = color..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(_RelPreviewPainter old) => false;
}
