import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/genogram_provider.dart';
import '../painters/node_painter.dart';
import '../painters/relation_painter.dart';
import '../models/person.dart';
import '../models/relationship.dart';
import '../constants/app_theme.dart';
import 'relationship_picker.dart';

class GenogramCanvas extends StatefulWidget {
  const GenogramCanvas({super.key});

  @override
  State<GenogramCanvas> createState() => _GenogramCanvasState();
}

class _GenogramCanvasState extends State<GenogramCanvas> {
  // Pan state
  Offset _panStart = Offset.zero;
  Offset _panViewStart = Offset.zero;

  // Drag node state
  String? _draggingNodeId;
  Offset _dragNodeStart = Offset.zero;
  Offset _dragTouchStart = Offset.zero;

  // Pinch state
  double _pinchStartScale = 1.0;
  Offset _pinchStartOffset = Offset.zero;
  double _pinchStartDist = 0;

  // Marquee state (in world coordinates)
  Offset? _marqueeStart;
  Offset? _marqueeEnd;
  Set<String> _marqueeBaseSelection = const <String>{};
  bool _marqueeAdditive = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GenogramProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onTapUp: (d) => _onTapUp(d.localPosition, provider, context),
          onDoubleTapDown: (d) => _onDoubleTap(d.localPosition, provider, context),
          onScaleStart: (d) => _onScaleStart(d, provider),
          onScaleUpdate: (d) => _onScaleUpdate(d, provider),
          onScaleEnd: (_) => _onScaleEnd(provider),
          onLongPressStart: (d) => _onLongPress(d.localPosition, provider, context),
          child: MouseRegion(
            cursor: provider.mode == AppMode.connect
                ? SystemMouseCursors.precise
                : provider.mode == AppMode.marquee
                    ? SystemMouseCursors.cell
                    : SystemMouseCursors.grab,
            child: CustomPaint(
              size: size,
              painter: _GenogramPainter(
                provider: provider,
                marqueeRect: _currentMarqueeRect(),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------------
  // Gesture handlers
  // ----------------------------------------------------------------
  void _onTapUp(Offset local, GenogramProvider provider, BuildContext context) {
    final worldPos = _toWorld(local, provider);

    // Check node hit first
    final nodeId = _hitTestNode(worldPos, provider);
    if (nodeId != null) {
      if (provider.mode == AppMode.connect) {
        provider.handleConnectTap(nodeId, onReadyToPick: (src, tgt) {
          _showRelationshipPicker(context, src, tgt, provider);
        });
      } else if (provider.mode == AppMode.marquee) {
        provider.togglePersonInMultiSelection(nodeId);
      } else {
        provider.selectPerson(nodeId);
      }
      return;
    }

    // Check relationship hit
    final relId = _hitTestRelation(worldPos, provider);
    if (relId != null) {
      provider.selectRelationship(relId);
      return;
    }

    // Tap on empty space
    if (provider.mode == AppMode.marquee) {
      provider.clearMultiSelection();
    } else {
      provider.clearSelection();
    }
  }

  void _onDoubleTap(Offset local, GenogramProvider provider, BuildContext context) {
    final worldPos = _toWorld(local, provider);
    final nodeId = _hitTestNode(worldPos, provider);
    if (nodeId != null) {
      provider.selectPerson(nodeId);
      _showNodeEditPanel(context, nodeId, provider);
      return;
    }
    final relId = _hitTestRelation(worldPos, provider);
    if (relId != null) {
      provider.selectRelationship(relId);
      _showRelEditPanel(context, relId, provider);
    }
  }

  void _onLongPress(Offset local, GenogramProvider provider, BuildContext context) {
    final worldPos = _toWorld(local, provider);
    final nodeId = _hitTestNode(worldPos, provider);
    if (nodeId != null) {
      provider.selectPerson(nodeId);
      _showNodeContextMenu(context, local, nodeId, provider);
    }
  }

  Offset? _scaleStartFocal;
  bool _isNodeDrag = false;

  void _onScaleStart(ScaleStartDetails d, GenogramProvider provider) {
    _scaleStartFocal = d.localFocalPoint;
    final worldPos = _toWorld(d.localFocalPoint, provider);
    final nodeId = _hitTestNode(worldPos, provider);

    // In marquee mode, dragging on empty space starts a selection rectangle.
    // Dragging on a node still moves the node.
    if (provider.mode == AppMode.marquee &&
        nodeId == null &&
        d.pointerCount == 1) {
      _isNodeDrag = false;
      _draggingNodeId = null;
      _marqueeStart = worldPos;
      _marqueeEnd = worldPos;
      _marqueeBaseSelection = provider.selectedPersonIds.toSet();
      _marqueeAdditive = _marqueeBaseSelection.isNotEmpty;
      setState(() {});
      return;
    }

    if (nodeId != null && d.pointerCount == 1) {
      _isNodeDrag = true;
      _draggingNodeId = nodeId;
      _dragNodeStart = provider.persons[nodeId]!.position;
      _dragTouchStart = d.localFocalPoint;
    } else {
      _isNodeDrag = false;
      _draggingNodeId = null;
      _panStart = d.localFocalPoint;
      _panViewStart = provider.viewOffset;
      _pinchStartScale = provider.viewScale;
      _pinchStartOffset = provider.viewOffset;
      if (d.pointerCount == 2) {
        _pinchStartDist = 1.0;
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d, GenogramProvider provider) {
    if (_marqueeStart != null && d.pointerCount == 1) {
      _marqueeEnd = _toWorld(d.localFocalPoint, provider);
      setState(() {});
      return;
    }

    if (_isNodeDrag && _draggingNodeId != null && d.pointerCount == 1) {
      final delta = (d.localFocalPoint - _dragTouchStart) / provider.viewScale;
      final newPos = _dragNodeStart + delta;
      final person = provider.persons[_draggingNodeId!]!;
      provider.updatePerson(person.copyWith(position: newPos));
      return;
    }

    if (d.pointerCount >= 2) {
      // Pinch zoom
      final newScale = (_pinchStartScale * d.scale).clamp(0.1, 4.0);
      final focal = d.localFocalPoint;
      final newOffsetX = focal.dx - (focal.dx - _pinchStartOffset.dx) * (newScale / _pinchStartScale);
      final newOffsetY = focal.dy - (focal.dy - _pinchStartOffset.dy) * (newScale / _pinchStartScale);
      provider.updateView(
        offset: Offset(newOffsetX, newOffsetY),
        scale: newScale,
      );
    } else {
      // Pan
      final delta = d.localFocalPoint - _panStart;
      provider.updateView(offset: _panViewStart + delta);
    }
  }

  void _onScaleEnd(GenogramProvider provider) {
    // Commit marquee selection.
    if (_marqueeStart != null && _marqueeEnd != null) {
      final rect = Rect.fromPoints(_marqueeStart!, _marqueeEnd!);
      final hit = <String>{};
      for (final p in provider.persons.values) {
        final nodeRect = Rect.fromLTWH(
          p.position.dx, p.position.dy, kNodeSize, kNodeSize,
        );
        if (rect.overlaps(nodeRect)) hit.add(p.id);
      }
      final next = _marqueeAdditive
          ? (_marqueeBaseSelection.toSet()..addAll(hit))
          : hit;
      provider.setMultiSelection(next);
    }
    _marqueeStart = null;
    _marqueeEnd = null;
    _draggingNodeId = null;
    _isNodeDrag = false;
    setState(() {});
  }

  Rect? _currentMarqueeRect() {
    if (_marqueeStart == null || _marqueeEnd == null) return null;
    return Rect.fromPoints(_marqueeStart!, _marqueeEnd!);
  }

  // ----------------------------------------------------------------
  // Hit testing
  // ----------------------------------------------------------------
  String? _hitTestNode(Offset worldPos, GenogramProvider provider) {
    // Reverse order so topmost (last drawn) wins
    for (final person in provider.persons.values.toList().reversed) {
      if (NodePainter.hitTest(person, worldPos)) return person.id;
    }
    return null;
  }

  String? _hitTestRelation(Offset worldPos, GenogramProvider provider) {
    for (final rel in provider.relationships.values) {
      final src = provider.persons[rel.sourceId];
      final tgt = provider.persons[rel.targetId];
      if (src == null || tgt == null) continue;
      if (RelationPainter.hitTest(rel, src, tgt, worldPos)) return rel.id;
    }
    return null;
  }

  // ----------------------------------------------------------------
  // Coordinate transform
  // ----------------------------------------------------------------
  Offset _toWorld(Offset local, GenogramProvider provider) {
    return (local - provider.viewOffset) / provider.viewScale;
  }

  // ----------------------------------------------------------------
  // Dialogs / sheets
  // ----------------------------------------------------------------
  void _showRelationshipPicker(
      BuildContext context, String src, String tgt, GenogramProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: kBorder),
      ),
      builder: (_) => RelationshipPickerSheet(
        sourceId: src,
        targetId: tgt,
        provider: provider,
      ),
    );
  }

  void _showNodeEditPanel(
      BuildContext context, String nodeId, GenogramProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: kBorder),
      ),
      builder: (_) => NodeEditSheet(nodeId: nodeId, provider: provider),
    );
  }

  void _showRelEditPanel(
      BuildContext context, String relId, GenogramProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: kBorder),
      ),
      builder: (_) => RelEditSheet(relId: relId, provider: provider),
    );
  }

  void _showNodeContextMenu(
      BuildContext context, Offset pos, String nodeId, GenogramProvider provider) {
    final person = provider.persons[nodeId];
    if (person == null) return;
    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: kBorder),
      ),
      items: [
        PopupMenuItem<void>(
          child: const Text('Edit', style: TextStyle(color: kText, fontSize: 13)),
          onTap: () => Future.microtask(
              () => _showNodeEditPanel(context, nodeId, provider)),
        ),
        PopupMenuItem<void>(
          child: const Text('Connect from here',
              style: TextStyle(color: kText, fontSize: 13)),
          onTap: () {
            provider.setMode(AppMode.connect);
            provider.handleConnectTap(nodeId, onReadyToPick: (s, t) {
              _showRelationshipPicker(context, s, t, provider);
            });
          },
        ),
        const PopupMenuDivider() as PopupMenuEntry<void>,
        PopupMenuItem<void>(
          child: const Text('Delete',
              style: TextStyle(color: kAccentRed, fontSize: 13)),
          onTap: () => provider.deletePerson(nodeId),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------
// The actual CustomPainter
// ----------------------------------------------------------------
class _GenogramPainter extends CustomPainter {
  final GenogramProvider provider;
  final Rect? marqueeRect;

  _GenogramPainter({required this.provider, this.marqueeRect})
      : super(repaint: provider);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(provider.viewOffset.dx, provider.viewOffset.dy);
    canvas.scale(provider.viewScale);

    // Build couple-relationship lookup: unordered pair of person ids -> rel.
    // Used so children of a couple can originate from the midpoint of the
    // existing link between their parents.
    const coupleTypes = <RelationshipType>{
      RelationshipType.married,
      RelationshipType.partnership,
      RelationshipType.engaged,
      RelationshipType.separated,
      RelationshipType.divorced,
    };
    String pairKey(String a, String b) =>
        (a.compareTo(b) < 0) ? '$a|$b' : '$b|$a';
    final couples = <String, Relationship>{};
    for (final rel in provider.relationships.values) {
      if (coupleTypes.contains(rel.type)) {
        couples[pairKey(rel.sourceId, rel.targetId)] = rel;
      }
    }

    // Group parent-child relationships by the (sorted) set of parents.
    // Key examples: "p1" for a single parent, "p1|p2" for a couple.
    final parentChildByParents = <String, List<Relationship>>{};
    final childParents = <String, List<String>>{};
    final siblingRels = <Relationship>[];
    final otherRels = <Relationship>[];
    for (final rel in provider.relationships.values) {
      if (rel.type == RelationshipType.parentChild) {
        childParents
            .putIfAbsent(rel.targetId, () => [])
            .add(rel.sourceId);
      } else if (rel.type == RelationshipType.sibling) {
        siblingRels.add(rel);
      } else {
        otherRels.add(rel);
      }
    }
    // Build a parent -> couple-partner lookup so a child with just one
    // explicit parent link can still be routed through the parents' shared
    // couple link.
    final partnerOf = <String, String>{};
    for (final rel in provider.relationships.values) {
      if (!coupleTypes.contains(rel.type)) continue;
      // First couple wins if a person has multiple (e.g. remarriage).
      partnerOf.putIfAbsent(rel.sourceId, () => rel.targetId);
      partnerOf.putIfAbsent(rel.targetId, () => rel.sourceId);
    }

    // Assign each parent-child rel to its parent-group.
    for (final rel in provider.relationships.values) {
      if (rel.type != RelationshipType.parentChild) continue;
      final parents = childParents[rel.targetId] ?? const <String>[];
      String key;
      if (parents.length >= 2 &&
          couples.containsKey(pairKey(parents[0], parents[1]))) {
        // Both parents linked explicitly and they form a couple.
        final sorted = [parents[0], parents[1]]..sort();
        key = sorted.join('|');
      } else if (parents.length == 1 &&
          partnerOf.containsKey(rel.sourceId)) {
        // Single explicit parent, but that parent has a couple partner —
        // treat the child as belonging to the couple.
        final partner = partnerOf[rel.sourceId]!;
        final sorted = [rel.sourceId, partner]..sort();
        key = sorted.join('|');
      } else {
        key = rel.sourceId;
      }
      parentChildByParents.putIfAbsent(key, () => []).add(rel);
    }

    // Draw parent-child groups (behind nodes).
    parentChildByParents.forEach((key, rels) {
      final parentIds = key.split('|');
      final parents = <Person>[];
      for (final pid in parentIds) {
        final p = provider.persons[pid];
        if (p != null) parents.add(p);
      }
      if (parents.isEmpty) return;

      // Children are unique across the rels in this group.
      final seen = <String>{};
      final children = <Person>[];
      final childRels = <Relationship>[];
      for (final r in rels) {
        if (!seen.add(r.targetId)) continue;
        final c = provider.persons[r.targetId];
        if (c != null) {
          children.add(c);
          childRels.add(r);
        }
      }
      if (children.isEmpty) return;

      final anySelected = childRels.any(
        (r) => provider.selectedRelationshipId == r.id,
      );

      // Single parent, single child: keep the simple straight line.
      if (parents.length == 1 && children.length == 1) {
        RelationPainter.paintRelationship(
          canvas, childRels.first, parents.first, children.first,
          selected: anySelected,
        );
        return;
      }

      _paintFamilyGroup(canvas, parents, children, anySelected);
    });

    // Draw sibling relationships. Connected components of >=3 siblings share
    // one sibling bar instead of producing N*(N-1)/2 criss-crossing lines.
    if (siblingRels.isNotEmpty) {
      final parent = <String, String>{};
      String find(String x) {
        var r = x;
        while (parent[r] != null && parent[r] != r) {
          r = parent[r]!;
        }
        var cur = x;
        while (parent[cur] != null && parent[cur] != cur) {
          final next = parent[cur]!;
          parent[cur] = r;
          cur = next;
        }
        return r;
      }
      void union(String a, String b) {
        parent.putIfAbsent(a, () => a);
        parent.putIfAbsent(b, () => b);
        final ra = find(a), rb = find(b);
        if (ra != rb) parent[ra] = rb;
      }
      for (final r in siblingRels) {
        union(r.sourceId, r.targetId);
      }
      // Bucket nodes by component root and bucket rels by component root.
      final compNodes = <String, Set<String>>{};
      final compRels = <String, List<Relationship>>{};
      for (final r in siblingRels) {
        final root = find(r.sourceId);
        compNodes.putIfAbsent(root, () => <String>{})
          ..add(r.sourceId)
          ..add(r.targetId);
        compRels.putIfAbsent(root, () => []).add(r);
      }
      compNodes.forEach((root, ids) {
        final people = <Person>[];
        for (final id in ids) {
          final p = provider.persons[id];
          if (p != null) people.add(p);
        }
        if (people.length < 2) return;
        final rels = compRels[root]!;
        final selected = rels.any(
          (r) => provider.selectedRelationshipId == r.id,
        );
        if (people.length == 2) {
          // Just a pair — draw the regular single line.
          RelationPainter.paintRelationship(
            canvas, rels.first, people[0], people[1],
            selected: selected,
          );
        } else {
          _paintSiblingBar(canvas, people, selected);
        }
      });
    }

    // Draw remaining relationships.
    for (final rel in otherRels) {
      final src = provider.persons[rel.sourceId];
      final tgt = provider.persons[rel.targetId];
      if (src == null || tgt == null) continue;
      RelationPainter.paintRelationship(
        canvas, rel, src, tgt,
        selected: provider.selectedRelationshipId == rel.id,
      );
    }

    // Draw nodes
    for (final person in provider.persons.values) {
      final center = person.position + const Offset(kNodeSize / 2, kNodeSize / 2);
      final isMulti = provider.selectedPersonIds.contains(person.id);
      NodePainter.paintPerson(
        canvas,
        person,
        center,
        selected: provider.selectedPersonId == person.id || isMulti,
        isConnectSource: provider.connectSourceId == person.id,
      );
    }

    // Marquee rectangle overlay (in world coords).
    if (marqueeRect != null) {
      final r = marqueeRect!;
      final fill = Paint()
        ..color = kAccentGreen.withOpacity(0.10)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = kAccentGreen.withOpacity(0.7)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GenogramPainter old) => true;

  // Draw a family group: one or two parents connected to one or more
  // children via a sibling bar. With two parents, the drop originates from
  // the midpoint of the line between them (their existing couple link).
  void _paintFamilyGroup(
    Canvas canvas,
    List<Person> parents,
    List<Person> children,
    bool selected,
  ) {
    final color = kRelationshipColors[RelationshipType.parentChild] ?? kText2;

    // Origin point on the parent side.
    Offset origin;
    if (parents.length >= 2) {
      final c1 = parents[0].position + const Offset(kNodeSize / 2, kNodeSize / 2);
      final c2 = parents[1].position + const Offset(kNodeSize / 2, kNodeSize / 2);
      origin = Offset((c1.dx + c2.dx) / 2, (c1.dy + c2.dy) / 2);
    } else {
      final p = parents.first;
      origin = Offset(
        p.position.dx + kNodeSize / 2,
        p.position.dy + kNodeSize,
      );
    }

    final childTops = children
        .map((c) => Offset(c.position.dx + kNodeSize / 2, c.position.dy))
        .toList();

    final topMostChildY = childTops
        .map((p) => p.dy)
        .reduce((a, b) => a < b ? a : b);
    // Sibling bar sits midway between the origin and the topmost child.
    final barY = (origin.dy + topMostChildY) / 2;

    final xs = <double>[origin.dx, ...childTops.map((p) => p.dx)];
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void drawAll(Paint p) {
      // Origin down (or up) to bar.
      canvas.drawLine(origin, Offset(origin.dx, barY), p);
      // Horizontal sibling bar (only needed if more than one child or origin
      // isn't directly above the single child).
      if (children.length > 1 || (origin.dx - childTops.first.dx).abs() > 0.5) {
        canvas.drawLine(Offset(minX, barY), Offset(maxX, barY), p);
      }
      // Drop from bar to each child.
      for (final top in childTops) {
        canvas.drawLine(Offset(top.dx, barY), top, p);
      }
    }

    if (selected) {
      final hi = Paint()
        ..color = kAccentGreen.withOpacity(0.25)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke;
      drawAll(hi);
    }
    drawAll(paint);
  }

  // Draw a sibling component (3+ people) sharing one horizontal sibling bar.
  // The bar sits above the topmost sibling, with verticals dropping down to
  // the top-center of each node.
  void _paintSiblingBar(
    Canvas canvas,
    List<Person> siblings,
    bool selected,
  ) {
    final color = kRelationshipColors[RelationshipType.sibling] ?? kText2;
    final tops = siblings
        .map((p) => Offset(p.position.dx + kNodeSize / 2, p.position.dy))
        .toList();
    final topMostY = tops.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    // Bar 18px above the topmost sibling.
    final barY = topMostY - 18;
    final minX = tops.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final maxX = tops.map((p) => p.dx).reduce((a, b) => a > b ? a : b);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void drawAll(Paint p) {
      canvas.drawLine(Offset(minX, barY), Offset(maxX, barY), p);
      for (final t in tops) {
        canvas.drawLine(Offset(t.dx, barY), t, p);
      }
    }

    if (selected) {
      final hi = Paint()
        ..color = kAccentGreen.withOpacity(0.25)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke;
      drawAll(hi);
    }
    drawAll(paint);
  }
}

// ----------------------------------------------------------------
// Node edit bottom sheet
// ----------------------------------------------------------------
class NodeEditSheet extends StatefulWidget {
  final String nodeId;
  final GenogramProvider provider;

  const NodeEditSheet({
    super.key,
    required this.nodeId,
    required this.provider,
  });

  @override
  State<NodeEditSheet> createState() => _NodeEditSheetState();
}

class _NodeEditSheetState extends State<NodeEditSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _birthCtrl;
  late TextEditingController _deathCtrl;
  late TextEditingController _genCtrl;
  late TextEditingController _notesCtrl;
  late Gender _gender;
  late SpecialType _specialType;
  late bool _substance, _mental, _physical, _abusePerpetrator,
      _abuseVictim, _adopted, _foster, _indexPerson;
  bool _clearDeath = false;
  bool _clearBirth = false;

  @override
  void initState() {
    super.initState();
    final p = widget.provider.persons[widget.nodeId]!;
    _nameCtrl = TextEditingController(text: p.name);
    _birthCtrl = TextEditingController(text: p.birthYear?.toString() ?? '');
    _deathCtrl = TextEditingController(text: p.deathYear?.toString() ?? '');
    _genCtrl = TextEditingController(text: p.generation.toString());
    _notesCtrl = TextEditingController(text: p.notes);
    _gender = p.gender;
    _specialType = p.specialType;
    _substance = p.markers.substance;
    _mental = p.markers.mental;
    _physical = p.markers.physical;
    _abusePerpetrator = p.markers.abusePerpetrator;
    _abuseVictim = p.markers.abuseVictim;
    _adopted = p.markers.adopted;
    _foster = p.markers.foster;
    _indexPerson = p.markers.indexPerson;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthCtrl.dispose();
    _deathCtrl.dispose();
    _genCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final person = widget.provider.persons[widget.nodeId]!;
    final updated = person.copyWith(
      name: _nameCtrl.text.trim(),
      birthYear: _birthCtrl.text.isNotEmpty ? int.tryParse(_birthCtrl.text) : null,
      deathYear: _deathCtrl.text.isNotEmpty ? int.tryParse(_deathCtrl.text) : null,
      clearDeath: _deathCtrl.text.isEmpty,
      clearBirth: _birthCtrl.text.isEmpty,
      generation: int.tryParse(_genCtrl.text) ?? 0,
      gender: _gender,
      specialType: _specialType,
      notes: _notesCtrl.text,
      markers: PersonMarkers(
        substance: _substance,
        mental: _mental,
        physical: _physical,
        abusePerpetrator: _abusePerpetrator,
        abuseVictim: _abuseVictim,
        adopted: _adopted,
        foster: _foster,
        indexPerson: _indexPerson,
      ),
    );
    widget.provider.updatePerson(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _sectionHeader('EDIT PERSON'),
          const SizedBox(height: 12),
          _field('Name', _nameCtrl),
          Row(children: [
            Expanded(child: _field('Birth Year', _birthCtrl, keyboard: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _field('Death Year', _deathCtrl, keyboard: TextInputType.number)),
          ]),
          _field('Generation', _genCtrl,
              keyboard: TextInputType.number,
              hint: '0=focal, -1=parent, 1=child'),
          const SizedBox(height: 8),
          _label('Gender'),
          _segmented<Gender>(
            values: Gender.values,
            selected: _gender,
            label: (g) => g.name[0].toUpperCase() + g.name.substring(1),
            onSelect: (g) => setState(() => _gender = g),
          ),
          const SizedBox(height: 8),
          _label('Special Type'),
          _segmented<SpecialType>(
            values: SpecialType.values,
            selected: _specialType,
            label: (s) => _specialLabel(s),
            onSelect: (s) => setState(() => _specialType = s),
            wrap: true,
          ),
          const SizedBox(height: 8),
          _label('Markers'),
          Wrap(spacing: 8, runSpacing: 4, children: [
            _chip('Substance', _substance, (v) => setState(() => _substance = v)),
            _chip('Mental Illness', _mental, (v) => setState(() => _mental = v)),
            _chip('Physical Illness', _physical, (v) => setState(() => _physical = v)),
            _chip('Abuse (perp)', _abusePerpetrator, (v) => setState(() => _abusePerpetrator = v)),
            _chip('Abuse (victim)', _abuseVictim, (v) => setState(() => _abuseVictim = v)),
            _chip('Adopted', _adopted, (v) => setState(() => _adopted = v)),
            _chip('Foster', _foster, (v) => setState(() => _foster = v)),
            _chip('Index Person', _indexPerson, (v) => setState(() => _indexPerson = v)),
          ]),
          const SizedBox(height: 8),
          _field('Notes', _notesCtrl, maxLines: 3),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                widget.provider.deletePerson(widget.nodeId);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kSurface2,
                foregroundColor: kAccentRed,
                side: const BorderSide(color: kAccentRed),
              ),
              child: const Text('Delete'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(
        text,
        style: const TextStyle(
          color: kAccent,
          fontSize: 11,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(color: kText2, fontSize: 11, letterSpacing: 1)),
      );

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard, String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(color: kText, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }

  Widget _segmented<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required void Function(T) onSelect,
    bool wrap = false,
  }) {
    final chips = values.map((v) {
      final isSelected = v == selected;
      return GestureDetector(
        onTap: () => onSelect(v),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(right: 6, bottom: 6),
          decoration: BoxDecoration(
            color: isSelected ? kAccent : kSurface2,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSelected ? kAccent : kBorder),
          ),
          child: Text(
            label(v),
            style: TextStyle(
              color: isSelected ? Colors.black : kText2,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }).toList();

    if (wrap) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(children: chips),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: chips),
    );
  }

  Widget _chip(String label, bool value, void Function(bool) onChanged) {
    return FilterChip(
      label: Text(label, style: TextStyle(
        fontSize: 11,
        color: value ? Colors.black : kText2,
      )),
      selected: value,
      onSelected: onChanged,
      backgroundColor: kSurface2,
      selectedColor: kAccentGreen,
      checkmarkColor: Colors.black,
      side: BorderSide(color: value ? kAccentGreen : kBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  String _specialLabel(SpecialType t) => switch (t) {
        SpecialType.none => 'None',
        SpecialType.pregnancy => 'Pregnancy',
        SpecialType.miscarriage => 'Miscarriage',
        SpecialType.abortion => 'Abortion',
        SpecialType.stillbirth => 'Stillbirth',
        SpecialType.twinMono => 'ID Twin',
        SpecialType.twinDi => 'Frat Twin',
      };
}

// ----------------------------------------------------------------
// Relationship edit sheet
// ----------------------------------------------------------------
class RelEditSheet extends StatefulWidget {
  final String relId;
  final GenogramProvider provider;

  const RelEditSheet({super.key, required this.relId, required this.provider});

  @override
  State<RelEditSheet> createState() => _RelEditSheetState();
}

class _RelEditSheetState extends State<RelEditSheet> {
  late RelationshipType _type;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final r = widget.provider.relationships[widget.relId]!;
    _type = r.type;
    _notesCtrl = TextEditingController(text: r.notes);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16,
          MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const Text('EDIT RELATIONSHIP',
            style: TextStyle(color: kAccent, fontSize: 11, fontFamily: 'monospace', letterSpacing: 2)),
        const SizedBox(height: 12),
        DropdownButtonFormField<RelationshipType>(
          value: _type,
          dropdownColor: kSurface2,
          style: const TextStyle(color: kText, fontSize: 13),
          decoration: const InputDecoration(labelText: 'Type'),
          items: RelationshipType.values.map((t) {
            final def = kRelationshipDefs[t]!;
            return DropdownMenuItem(
              value: t,
              child: Text('${def.label} (${def.category})'),
            );
          }).toList(),
          onChanged: (v) => setState(() => _type = v!),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          style: const TextStyle(color: kText, fontSize: 13),
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final rel = widget.provider.relationships[widget.relId]!;
                widget.provider.updateRelationship(
                  rel.copyWith(type: _type, notes: _notesCtrl.text),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: Colors.black,
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              widget.provider.deleteRelationship(widget.relId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kSurface2,
              foregroundColor: kAccentRed,
              side: const BorderSide(color: kAccentRed),
            ),
            child: const Text('Delete'),
          ),
        ]),
      ]),
    );
  }
}