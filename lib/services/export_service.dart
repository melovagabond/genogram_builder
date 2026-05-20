import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import '../providers/genogram_provider.dart';
import '../models/person.dart';
import '../models/relationship.dart';
import '../constants/app_theme.dart';

class ExportService {
  static Future<void> exportToPdf(
    BuildContext context,
    GenogramProvider provider,
  ) async {
    final persons = provider.persons.values.toList();
    if (persons.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nothing to export -- add some people first'),
            backgroundColor: kSurface2,
          ),
        );
      }
      return;
    }

    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in persons) {
      if (p.position.dx < minX) minX = p.position.dx;
      if (p.position.dy < minY) minY = p.position.dy;
      if (p.position.dx > maxX) maxX = p.position.dx;
      if (p.position.dy > maxY) maxY = p.position.dy;
    }

    const padding = 40.0;
    const ns = kNodeSize;
    final contentW = maxX - minX + ns + padding * 2;
    final contentH = maxY - minY + ns + padding * 2;
    final pageFormat =
        contentW > contentH ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    final availW = pageFormat.availableWidth - padding * 2;
    final availH = pageFormat.availableHeight - padding * 2 - 80;
    final sx = availW / contentW;
    final sy = availH / contentH;
    final scale = (sx < sy ? sx : sy).clamp(0.05, 1.5);

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Genogram',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.Text(
              'Generated ${DateTime.now().toLocal().toString().split('.').first}'
              '  |  ${persons.length} persons'
              '  |  ${provider.relationships.length} relationships',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
            pw.SizedBox(height: 8),
            pw.Expanded(
              child: pw.Stack(
                children: [
                  // Shapes and lines via CustomPaint (no text)
                  pw.CustomPaint(
                    painter: (pdfCanvas, pdfSize) {
                      _paintShapes(
                          pdfCanvas, pdfSize, provider, minX, minY, scale, padding);
                    },
                  ),
                  // Labels as pw widgets (correct font handling)
                  ..._buildLabels(provider, minX, minY, scale, padding),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            _buildLegend(),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'genogram_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // ----------------------------------------------------------------
  // Paint only shapes and lines -- no text in the low-level painter
  // ----------------------------------------------------------------
  static void _paintShapes(
    PdfGraphics canvas,
    PdfPoint size,
    GenogramProvider provider,
    double minX,
    double minY,
    double scale,
    double padding,
  ) {
    canvas.saveContext();
    // PDF Y-axis is bottom-up; Flutter is top-down. Flip Y.
    final m = Matrix4.identity()
      ..translate(padding - minX * scale, size.y - padding + minY * scale)
      ..scale(scale, -scale, 1.0);
    canvas.setTransform(m);

    for (final rel in provider.relationships.values) {
      final src = provider.persons[rel.sourceId];
      final tgt = provider.persons[rel.targetId];
      if (src == null || tgt == null) continue;
      _drawRel(canvas, rel, src, tgt);
    }
    for (final person in provider.persons.values) {
      _drawPersonShape(canvas, person);
    }

    canvas.restoreContext();
  }

  // ----------------------------------------------------------------
  // Labels as pw.Positioned widgets -- correct font path
  // ----------------------------------------------------------------
  static List<pw.Widget> _buildLabels(
    GenogramProvider provider,
    double minX,
    double minY,
    double scale,
    double padding,
  ) {
    final widgets = <pw.Widget>[];
    const ns = kNodeSize;
    const half = ns / 2;

    for (final person in provider.persons.values) {
      if (person.name.isEmpty && person.yearLabel.isEmpty) continue;

      // Convert world position to PDF page position (Y not flipped for pw widgets)
      final px = (person.position.dx - minX) * scale + padding;
      final py = (person.position.dy - minY) * scale + padding;

      if (person.name.isNotEmpty) {
        widgets.add(
          pw.Positioned(
            left: px,
            top: py + ns * scale + 2,
            child: pw.Text(
              person.name,
              style: pw.TextStyle(
                fontSize: 7 * scale.clamp(0.5, 1.0),
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
          ),
        );
      }
      if (person.yearLabel.isNotEmpty) {
        widgets.add(
          pw.Positioned(
            left: px,
            top: py + ns * scale + 11,
            child: pw.Text(
              person.yearLabel,
              style: pw.TextStyle(
                fontSize: 6 * scale.clamp(0.5, 1.0),
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // ----------------------------------------------------------------
  // Person shape only (no text)
  // ----------------------------------------------------------------
  static void _drawPersonShape(PdfGraphics c, Person person) {
    const s = kNodeSize;
    const h = s / 2;
    final cx = person.position.dx + h;
    final cy = person.position.dy + h;

    final strokeColor = switch (person.gender) {
      Gender.male    => PdfColors.blue400,
      Gender.female  => PdfColors.pink400,
      Gender.unknown => PdfColors.blueGrey400,
    };

    c.setStrokeColor(strokeColor);
    c.setFillColor(PdfColor(strokeColor.red, strokeColor.green, strokeColor.blue, 0.08));
    c.setLineWidth(person.markers.indexPerson ? 2.0 : 1.0);

    switch (person.gender) {
      case Gender.male:
        c.drawRect(cx - h + 2, cy - h + 2, s - 4, s - 4);
        c.fillAndStrokePath();
      case Gender.female:
        c.drawEllipse(cx, cy, h - 2, h - 2);
        c.fillAndStrokePath();
      case Gender.unknown:
        c.moveTo(cx, cy - h + 2);
        c.lineTo(cx + h - 2, cy);
        c.lineTo(cx, cy + h - 2);
        c.lineTo(cx - h + 2, cy);
        c.closePath();
        c.fillAndStrokePath();
    }

    if (person.isDeceased) {
      c.setStrokeColor(strokeColor);
      c.setLineWidth(1.5);
      c.moveTo(cx - h + 6, cy - h + 6);
      c.lineTo(cx + h - 6, cy + h - 6);
      c.strokePath();
      c.moveTo(cx + h - 6, cy - h + 6);
      c.lineTo(cx - h + 6, cy + h - 6);
      c.strokePath();
    }
  }

  // ----------------------------------------------------------------
  // Relationships
  // ----------------------------------------------------------------
  static void _drawRel(
      PdfGraphics c, Relationship rel, Person src, Person tgt) {
    const h = kNodeSize / 2;
    final x1 = src.position.dx + h;
    final y1 = src.position.dy + h;
    final x2 = tgt.position.dx + h;
    final y2 = tgt.position.dy + h;

    final color = switch (rel.type) {
      RelationshipType.harmony ||
      RelationshipType.friendship ||
      RelationshipType.love ||
      RelationshipType.inLove ||
      RelationshipType.fused          => PdfColors.green400,
      RelationshipType.hostile ||
      RelationshipType.closeHostile ||
      RelationshipType.fusedHostile   => PdfColors.red400,
      RelationshipType.violence ||
      RelationshipType.closeViolence ||
      RelationshipType.fusedViolence  => PdfColors.red700,
      RelationshipType.abuse ||
      RelationshipType.physicalAbuse  => PdfColors.red900,
      RelationshipType.emotionalAbuse => PdfColors.purple400,
      RelationshipType.sexualAbuse ||
      RelationshipType.neglect        => PdfColors.blue400,
      RelationshipType.manipulative ||
      RelationshipType.controlling    => PdfColors.orange500,
      RelationshipType.discord        => PdfColors.orange300,
      RelationshipType.distant        => PdfColors.blueGrey300,
      _                               => PdfColors.blueGrey600,
    };

    c.setStrokeColor(color);
    c.setLineWidth(1.0);

    switch (rel.type) {
      case RelationshipType.married:
        _parallel(c, x1, y1, x2, y2, 2.5, color);
      case RelationshipType.fused || RelationshipType.friendship:
        _triple(c, x1, y1, x2, y2, color);
      case RelationshipType.separated:
        _dashed(c, x1, y1, x2, y2, color, 6, 3);
      case RelationshipType.engaged:
        _dashed(c, x1, y1, x2, y2, color, 2, 2);
      case RelationshipType.divorced:
        _parallel(c, x1, y1, x2, y2, 2.5, color);
        final mx = (x1 + x2) / 2;
        final my = (y1 + y2) / 2;
        c.setLineWidth(1.5);
        c.moveTo(mx - 5, my - 7); c.lineTo(mx - 2, my + 7); c.strokePath();
        c.moveTo(mx + 2, my - 7); c.lineTo(mx + 5, my + 7); c.strokePath();
      case RelationshipType.hostile || RelationshipType.abuse || RelationshipType.violence:
        _zigzag(c, x1, y1, x2, y2, color);
      case RelationshipType.cutoff:
        _cutoff(c, x1, y1, x2, y2, color);
      case RelationshipType.fusedHostile:
        _triple(c, x1, y1, x2, y2, color);
        _zigzag(c, x1, y1, x2, y2, PdfColors.red400);
      case RelationshipType.distant:
        c.setLineWidth(0.6);
        c.moveTo(x1, y1); c.lineTo(x2, y2); c.strokePath();
      case RelationshipType.partnership ||
           RelationshipType.parentChild ||
           RelationshipType.sibling ||
           RelationshipType.plain ||
           RelationshipType.indifferent:
        c.moveTo(x1, y1); c.lineTo(x2, y2); c.strokePath();
      default:
        c.moveTo(x1, y1); c.lineTo(x2, y2); c.strokePath();
    }
  }

  // ----------------------------------------------------------------
  // Drawing primitives
  // ----------------------------------------------------------------
  static Offset _norm(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1, dy = y2 - y1;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001) return Offset.zero;
    return Offset(-dy / len, dx / len);
  }

  static void _parallel(PdfGraphics c, double x1, double y1,
      double x2, double y2, double off, PdfColor color) {
    final n = _norm(x1, y1, x2, y2);
    c.setStrokeColor(color);
    c.moveTo(x1 + n.dx * off, y1 + n.dy * off);
    c.lineTo(x2 + n.dx * off, y2 + n.dy * off);
    c.strokePath();
    c.moveTo(x1 - n.dx * off, y1 - n.dy * off);
    c.lineTo(x2 - n.dx * off, y2 - n.dy * off);
    c.strokePath();
  }

  static void _triple(PdfGraphics c, double x1, double y1,
      double x2, double y2, PdfColor color) {
    _parallel(c, x1, y1, x2, y2, 3.5, color);
    c.setStrokeColor(color);
    c.moveTo(x1, y1); c.lineTo(x2, y2); c.strokePath();
  }

  static void _dashed(PdfGraphics c, double x1, double y1,
      double x2, double y2, PdfColor color, double dash, double gap) {
    final dx = x2 - x1, dy = y2 - y1;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;
    final nx = dx / len, ny = dy / len;
    double d = 0;
    bool on = true;
    c.setStrokeColor(color);
    while (d < len) {
      final sl = on ? dash : gap;
      final e = (d + sl).clamp(0.0, len);
      if (on) {
        c.moveTo(x1 + nx * d, y1 + ny * d);
        c.lineTo(x1 + nx * e, y1 + ny * e);
        c.strokePath();
      }
      d += sl;
      on = !on;
    }
  }

  static void _zigzag(PdfGraphics c, double x1, double y1,
      double x2, double y2, PdfColor color) {
    final dx = x2 - x1, dy = y2 - y1;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;
    final n = _norm(x1, y1, x2, y2);
    const steps = 8;
    c.setStrokeColor(color);
    c.setLineWidth(1.2);
    c.moveTo(x1, y1);
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final side = (i % 2 == 0) ? 1.0 : -1.0;
      c.lineTo(x1 + dx * t + n.dx * 5 * side, y1 + dy * t + n.dy * 5 * side);
    }
    c.lineTo(x2, y2);
    c.strokePath();
  }

  static void _cutoff(PdfGraphics c, double x1, double y1,
      double x2, double y2, PdfColor color) {
    final mx = (x1 + x2) / 2, my = (y1 + y2) / 2;
    final n = _norm(x1, y1, x2, y2);
    _dashed(c, x1, y1, mx - 6, my - 6, color, 6, 4);
    _dashed(c, mx + 6, my + 6, x2, y2, color, 6, 4);
    c.setStrokeColor(color);
    c.setLineWidth(2.0);
    c.moveTo(mx - n.dx * 10, my - n.dy * 10);
    c.lineTo(mx + n.dx * 10, my + n.dy * 10);
    c.strokePath();
  }

  // ----------------------------------------------------------------
  // Legend
  // ----------------------------------------------------------------
  static pw.Widget _buildLegend() {
    const ts = pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey600);
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Wrap(spacing: 16, runSpacing: 4, children: [
        pw.Text('Square=Male  Circle=Female  Diamond=Unknown', style: ts),
        pw.Text('X overlay=Deceased  Dashed border=Adopted', style: ts),
        pw.Text('Double line=Married/Close  Triple=Fused  Zigzag=Conflicted', style: ts),
        pw.Text('Dashed+break=Estranged  Orange sq=Substance  Purple dot=Mental', style: ts),
      ]),
    );
  }
}
