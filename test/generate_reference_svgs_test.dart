// Renders the demo genogram as deterministic SVG documentation. Runs under
// flutter_test so it has access to Flutter types used by the data models,
// but it does NOT use the render engine — it just walks the model data and
// emits SVG strings. That makes it fast and reliable (no animation/ticker
// hangs).
//
// Run:
//   flutter test test/generate_reference_svgs_test.dart
//
// Output: docs/reference/demo_genogram.svg + demo_genogram_focus_susan.svg
//
// The renderer is intentionally simplified compared to the in-app painter:
// gender-coded shapes, structural lines, and emotional lines coloured by
// category. It is meant as documentation, not as a pixel-faithful
// screenshot.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:genogram_builder/data/demo_genogram.dart';
import 'package:genogram_builder/models/person.dart';
import 'package:genogram_builder/models/relationship.dart';

const double _nodeSize = 52.0;
const double _nodeRadius = _nodeSize / 2;
const double _padding = 60.0;

// Colors lifted from lib/constants/app_theme.dart so the SVG roughly matches
// what the user sees in the app.
const _bg = '#0D0F14';
const _maleFill = '#4F9EFF';
const _femaleFill = '#FF6B9D';
const _unknownFill = '#A0AEC0';
const _indexStroke = '#FFC83D';
const _deceasedStroke = '#E8ECF0';
const _labelColor = '#E8ECF0';
const _yearColor = '#8892A4';

String _relColor(RelationshipType t) {
  final cat = kRelationshipDefs[t]?.category ?? '';
  switch (cat) {
    case 'Structural':
      return t == RelationshipType.parentChild ? '#8892A4' : '#E8ECF0';
    case 'Neutral':
      return '#8892A4';
    case 'Positive':
      return '#22AA44';
    case 'Negative':
    case 'Violence':
      return '#FF4444';
    case 'Abuse':
      return '#B56BFF';
    case 'Control':
      return '#FFAA4F';
    default:
      return '#8892A4';
  }
}

String? _relDash(RelationshipType t) {
  switch (t) {
    case RelationshipType.divorced:
    case RelationshipType.separated:
      return '8 6';
    case RelationshipType.distant:
    case RelationshipType.indifferent:
    case RelationshipType.cutoff:
      return '4 6';
    default:
      return null;
  }
}

double _relWidth(RelationshipType t) {
  if (t == RelationshipType.parentChild) return 1.6;
  final cat = kRelationshipDefs[t]?.category ?? '';
  if (cat == 'Structural') return 2.4;
  return 2.0;
}

String _genderFill(Gender g) {
  switch (g) {
    case Gender.male:
      return _maleFill;
    case Gender.female:
      return _femaleFill;
    case Gender.unknown:
      return _unknownFill;
  }
}

Offset _nodeCenter(Person p) =>
    Offset(p.position.dx + _nodeRadius, p.position.dy + _nodeRadius);

// ---------------------------------------------------------------------------
// SVG primitives
// ---------------------------------------------------------------------------

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _nodeSvg(Person p) {
  final c = _nodeCenter(p);
  final fill = _genderFill(p.gender);
  final isIndex = p.markers.indexPerson;
  final stroke = isIndex ? _indexStroke : '#1E2330';
  final strokeWidth = isIndex ? 4.0 : 2.0;
  final buf = StringBuffer();

  if (p.gender == Gender.female) {
    buf.write(
      '<circle cx="${c.dx.toStringAsFixed(1)}" cy="${c.dy.toStringAsFixed(1)}" '
      'r="${_nodeRadius.toStringAsFixed(1)}" fill="$fill" stroke="$stroke" '
      'stroke-width="$strokeWidth"/>',
    );
  } else if (p.gender == Gender.unknown) {
    // Diamond: rotated square centred on the node.
    final cx = c.dx;
    final cy = c.dy;
    final r = _nodeRadius;
    final points = '${cx.toStringAsFixed(1)},${(cy - r).toStringAsFixed(1)} '
        '${(cx + r).toStringAsFixed(1)},${cy.toStringAsFixed(1)} '
        '${cx.toStringAsFixed(1)},${(cy + r).toStringAsFixed(1)} '
        '${(cx - r).toStringAsFixed(1)},${cy.toStringAsFixed(1)}';
    buf.write(
      '<polygon points="$points" fill="$fill" stroke="$stroke" '
      'stroke-width="$strokeWidth"/>',
    );
  } else {
    final x = p.position.dx;
    final y = p.position.dy;
    buf.write(
      '<rect x="${x.toStringAsFixed(1)}" y="${y.toStringAsFixed(1)}" '
      'width="$_nodeSize" height="$_nodeSize" fill="$fill" stroke="$stroke" '
      'stroke-width="$strokeWidth" rx="4"/>',
    );
  }

  // Deceased: diagonal line through the node.
  if (p.isDeceased) {
    final x1 = p.position.dx - 4;
    final y1 = p.position.dy - 4;
    final x2 = p.position.dx + _nodeSize + 4;
    final y2 = p.position.dy + _nodeSize + 4;
    buf.write(
      '<line x1="$x1" y1="$y1" x2="$x2" y2="$y2" stroke="$_deceasedStroke" '
      'stroke-width="2.5"/>',
    );
  }

  // Label below the node.
  final label = _escape(p.name);
  final labelY = p.position.dy + _nodeSize + 16;
  buf.write(
    '<text x="${c.dx.toStringAsFixed(1)}" y="${labelY.toStringAsFixed(1)}" '
    'fill="$_labelColor" font-family="Helvetica, Arial, sans-serif" '
    'font-size="12" text-anchor="middle">$label</text>',
  );
  if (p.yearLabel.isNotEmpty) {
    buf.write(
      '<text x="${c.dx.toStringAsFixed(1)}" y="${(labelY + 14).toStringAsFixed(1)}" '
      'fill="$_yearColor" font-family="Helvetica, Arial, sans-serif" '
      'font-size="10" text-anchor="middle">${_escape(p.yearLabel)}</text>',
    );
  }
  return buf.toString();
}

String _edgeSvg(
  Relationship r,
  Map<String, Person> persons,
) {
  final src = persons[r.sourceId];
  final tgt = persons[r.targetId];
  if (src == null || tgt == null) return '';
  final a = _nodeCenter(src);
  final b = _nodeCenter(tgt);
  final color = _relColor(r.type);
  final dash = _relDash(r.type);
  final width = _relWidth(r.type);

  // Parent-child: orthogonal elbow that drops from the parent down to the
  // child's vertical centre, then across. Matches the app's structural style
  // closely enough for documentation.
  if (r.type == RelationshipType.parentChild) {
    final midY = (a.dy + b.dy) / 2;
    final path = 'M ${a.dx} ${a.dy + _nodeRadius} '
        'V $midY '
        'H ${b.dx} '
        'V ${b.dy - _nodeRadius}';
    return '<path d="$path" fill="none" stroke="$color" '
        'stroke-width="$width"/>';
  }

  final dashAttr = dash != null ? ' stroke-dasharray="$dash"' : '';
  return '<line x1="${a.dx.toStringAsFixed(1)}" y1="${a.dy.toStringAsFixed(1)}" '
      'x2="${b.dx.toStringAsFixed(1)}" y2="${b.dy.toStringAsFixed(1)}" '
      'stroke="$color" stroke-width="$width"$dashAttr/>';
}

// ---------------------------------------------------------------------------
// Renderer
// ---------------------------------------------------------------------------

String renderSvg({
  required Map<String, Person> persons,
  required Map<String, Relationship> relationships,
  required String title,
}) {
  if (persons.isEmpty) {
    return '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">'
        '<text x="20" y="50" fill="white">Empty genogram</text></svg>';
  }

  double minX = double.infinity, minY = double.infinity;
  double maxX = -double.infinity, maxY = -double.infinity;
  for (final p in persons.values) {
    minX = math.min(minX, p.position.dx);
    minY = math.min(minY, p.position.dy);
    maxX = math.max(maxX, p.position.dx + _nodeSize);
    maxY = math.max(maxY, p.position.dy + _nodeSize);
  }

  final viewX = minX - _padding;
  final viewY = minY - _padding;
  final viewW = (maxX - minX) + _padding * 2;
  final viewH = (maxY - minY) + _padding * 2 + 30; // extra for bottom labels

  final buf = StringBuffer();
  buf.writeln(
    '<svg xmlns="http://www.w3.org/2000/svg" '
    'viewBox="${viewX.toStringAsFixed(1)} ${viewY.toStringAsFixed(1)} '
    '${viewW.toStringAsFixed(1)} ${viewH.toStringAsFixed(1)}" '
    'width="${viewW.toStringAsFixed(0)}" '
    'height="${viewH.toStringAsFixed(0)}">',
  );
  buf.writeln('<title>${_escape(title)}</title>');
  buf.writeln(
    '<rect x="${viewX.toStringAsFixed(1)}" y="${viewY.toStringAsFixed(1)}" '
    'width="${viewW.toStringAsFixed(1)}" height="${viewH.toStringAsFixed(1)}" '
    'fill="$_bg"/>',
  );

  // Edges first so nodes draw on top.
  // Sort parent-child to the back, then structural couple lines, then
  // emotional ties on top — matches the app's painter ordering.
  final relsSorted = relationships.values.toList()
    ..sort((a, b) {
      int order(RelationshipType t) {
        if (t == RelationshipType.parentChild) return 0;
        final cat = kRelationshipDefs[t]?.category ?? '';
        if (cat == 'Structural') return 1;
        return 2;
      }

      return order(a.type).compareTo(order(b.type));
    });
  for (final r in relsSorted) {
    buf.writeln(_edgeSvg(r, persons));
  }
  for (final p in persons.values) {
    buf.writeln(_nodeSvg(p));
  }

  buf.writeln('</svg>');
  return buf.toString();
}

void main() {
  test('generates demo genogram SVG reference images', () {
    final state = buildDemoGenogramState();
    final outDir = Directory('docs/reference');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    // Full demo.
    final fullSvg = renderSvg(
      persons: state.persons,
      relationships: state.relationships,
      title: 'Genogram Builder — demo data (Susan Hale, index)',
    );
    final fullFile = File('${outDir.path}/demo_genogram.svg');
    fullFile.writeAsStringSync(fullSvg);
    expect(fullFile.lengthSync(), greaterThan(1024));
    stdout.writeln('Wrote ${fullFile.path} '
        '(${state.persons.length} persons, ${state.relationships.length} rels)');

    // Focused view: Susan + 2-hop neighbours via any relationship.
    const focusId = 'p6';
    final adj = <String, Set<String>>{};
    for (final r in state.relationships.values) {
      adj.putIfAbsent(r.sourceId, () => <String>{}).add(r.targetId);
      adj.putIfAbsent(r.targetId, () => <String>{}).add(r.sourceId);
    }
    final visited = <String>{focusId};
    var frontier = <String>{focusId};
    for (var i = 0; i < 2; i++) {
      final next = <String>{};
      for (final id in frontier) {
        for (final n in (adj[id] ?? const <String>{})) {
          if (visited.add(n)) next.add(n);
        }
      }
      if (next.isEmpty) break;
      frontier = next;
    }
    final fPersons = <String, Person>{
      for (final id in visited)
        if (state.persons[id] != null) id: state.persons[id]!,
    };
    final fRels = <String, Relationship>{
      for (final r in state.relationships.values)
        if (visited.contains(r.sourceId) && visited.contains(r.targetId))
          r.id: r,
    };
    final focusSvg = renderSvg(
      persons: fPersons,
      relationships: fRels,
      title:
          'Genogram Builder — demo data focused on ${state.persons[focusId]?.name ?? focusId}',
    );
    final focusFile = File('${outDir.path}/demo_genogram_focus_susan.svg');
    focusFile.writeAsStringSync(focusSvg);
    expect(focusFile.lengthSync(), greaterThan(512));
    stdout.writeln('Wrote ${focusFile.path} '
        '(${fPersons.length} persons, ${fRels.length} rels)');
  });

  test('generates README walkthrough SVG snippets', () {
    final outDir = Directory('docs/reference');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    void write(String name, String svg) {
      final f = File('${outDir.path}/$name');
      f.writeAsStringSync(svg);
      expect(f.lengthSync(), greaterThan(128));
      stdout.writeln('Wrote ${f.path}');
    }

    // ---- 1. Node shapes: male / female / unknown / index person ----
    {
      const male = Person(
        id: 's1', name: 'Male', gender: Gender.male,
        position: Offset(0, 0),
      );
      const female = Person(
        id: 's2', name: 'Female', gender: Gender.female,
        position: Offset(120, 0),
      );
      const unknown = Person(
        id: 's3', name: 'Unknown', gender: Gender.unknown,
        position: Offset(240, 0),
      );
      const index = Person(
        id: 's4', name: 'Index Person', gender: Gender.female,
        markers: PersonMarkers(indexPerson: true),
        position: Offset(360, 0),
      );
      final persons = {for (final p in [male, female, unknown, index]) p.id: p};
      write(
        'walkthrough_node_shapes.svg',
        renderSvg(
          persons: persons,
          relationships: const {},
          title: 'Node shapes: male, female, unknown, index person',
        ),
      );
    }

    // ---- 2. Deceased overlay ----
    {
      const alive = Person(
        id: 's1', name: 'Alive', gender: Gender.male,
        birthYear: 1980,
        position: Offset(0, 0),
      );
      const deceased = Person(
        id: 's2', name: 'Deceased', gender: Gender.female,
        birthYear: 1942, deathYear: 2018,
        position: Offset(140, 0),
      );
      final persons = {for (final p in [alive, deceased]) p.id: p};
      write(
        'walkthrough_deceased.svg',
        renderSvg(
          persons: persons,
          relationships: const {},
          title: 'Deceased overlay',
        ),
      );
    }

    // ---- 3. Nuclear family (auto-routed descent + sibling bar) ----
    {
      const dad = Person(
        id: 'dad', name: 'John', gender: Gender.male,
        birthYear: 1975, generation: -1,
        position: Offset(0, 0),
      );
      const mom = Person(
        id: 'mom', name: 'Jane', gender: Gender.female,
        birthYear: 1977, generation: -1,
        position: Offset(140, 0),
      );
      const kid1 = Person(
        id: 'k1', name: 'Alex', gender: Gender.female,
        birthYear: 2005, generation: 0,
        markers: PersonMarkers(indexPerson: true),
        position: Offset(10, 160),
      );
      const kid2 = Person(
        id: 'k2', name: 'Sam', gender: Gender.male,
        birthYear: 2008, generation: 0,
        position: Offset(130, 160),
      );
      final persons = {for (final p in [dad, mom, kid1, kid2]) p.id: p};
      const rels = <Relationship>[
        Relationship(id: 'r1', sourceId: 'dad', targetId: 'mom',
            type: RelationshipType.married),
        Relationship(id: 'r2', sourceId: 'dad', targetId: 'k1',
            type: RelationshipType.parentChild),
        Relationship(id: 'r3', sourceId: 'mom', targetId: 'k1',
            type: RelationshipType.parentChild),
        Relationship(id: 'r4', sourceId: 'dad', targetId: 'k2',
            type: RelationshipType.parentChild),
        Relationship(id: 'r5', sourceId: 'mom', targetId: 'k2',
            type: RelationshipType.parentChild),
      ];
      write(
        'walkthrough_nuclear_family.svg',
        renderSvg(
          persons: persons,
          relationships: {for (final r in rels) r.id: r},
          title: 'Nuclear family: married couple + two children',
        ),
      );
    }

    // ---- 4. Relationship line gallery ----
    {
      // Lay out pairs in a grid, label between them via a synthetic
      // "label person" entry isn't easy — instead inject <text> after
      // renderSvg by post-processing the buffer.
      const types = <RelationshipType>[
        RelationshipType.married,
        RelationshipType.divorced,
        RelationshipType.separated,
        RelationshipType.partnership,
        RelationshipType.love,
        RelationshipType.friendship,
        RelationshipType.distant,
        RelationshipType.hostile,
        RelationshipType.cutoff,
        RelationshipType.indifferent,
      ];
      const cols = 2;
      const cellW = 320.0;
      const cellH = 130.0;
      final persons = <String, Person>{};
      final rels = <String, Relationship>{};
      final labels = <_Label>[];
      for (var i = 0; i < types.length; i++) {
        final t = types[i];
        final col = i % cols;
        final row = i ~/ cols;
        final x = col * cellW;
        final y = row * cellH;
        final aId = 'a$i';
        final bId = 'b$i';
        persons[aId] = Person(
          id: aId, name: '', gender: Gender.male,
          position: Offset(x, y),
        );
        persons[bId] = Person(
          id: bId, name: '', gender: Gender.female,
          position: Offset(x + 180, y),
        );
        rels['r$i'] = Relationship(
          id: 'r$i', sourceId: aId, targetId: bId, type: t,
        );
        labels.add(_Label(
          x: x + (180 + _nodeSize) / 2,
          y: y - 12,
          text: kRelationshipDefs[t]?.label ?? t.name,
        ));
      }
      var svg = renderSvg(
        persons: persons,
        relationships: rels,
        title: 'Relationship line gallery',
      );
      // Inject labels before </svg>.
      final labelSvg = labels
          .map((l) => '<text x="${l.x.toStringAsFixed(1)}" '
              'y="${l.y.toStringAsFixed(1)}" fill="$_labelColor" '
              'font-family="Helvetica, Arial, sans-serif" font-size="11" '
              'text-anchor="middle">${_escape(l.text)}</text>')
          .join('\n');
      svg = svg.replaceFirst('</svg>', '$labelSvg\n</svg>');
      write('walkthrough_relationship_gallery.svg', svg);
    }
  });
}

class _Label {
  final double x;
  final double y;
  final String text;
  const _Label({required this.x, required this.y, required this.text});
}
