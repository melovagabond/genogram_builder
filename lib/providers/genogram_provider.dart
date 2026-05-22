import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/demo_genogram.dart';
import '../models/genogram_state.dart';
import '../models/person.dart';
import '../models/relationship.dart';

enum AppMode { select, connect, marquee }

class GenogramProvider extends ChangeNotifier {
  GenogramProvider({GenogramState? initialState})
      : _state = initialState ?? buildDemoGenogramState();

  GenogramState _state;
  AppMode _mode = AppMode.select;
  String? _selectedPersonId;
  String? _selectedRelationshipId;
  String? _connectSourceId;
  final Set<String> _selectedPersonIds = <String>{};
  Offset _viewOffset = Offset.zero;
  double _viewScale = 1.0;

  // Focus mode: when set, only the focus person and their N-hop relatives are
  // drawn at full opacity. Everyone else fades out so a section of a large
  // tree can be inspected without visual noise from unrelated branches.
  String? _focusPersonId;
  int _focusDepth = 2;

  // Inspect mode: when set, only emotional/clinical (non-structural,
  // non-neutral) relationships touching this person are shown at full
  // opacity. Used together with a side panel summarising those ties.
  //
  // Inspect auto-engages whenever a single person is selected in
  // [AppMode.select] (no marquee, no connect). The user can dismiss the
  // panel for the current selection without deselecting via [hideInspect],
  // which sets [_inspectSuppressed] until the selection changes.
  String? _inspectPersonId;
  bool _inspectSuppressed = false;

  // Global visibility toggle: when true, emotional/clinical ties (Positive,
  // Negative, Violence, Abuse, Control) are not rendered at all — leaving a
  // clean structural-only view of the family.
  bool _hideEmotionalTies = false;

  // Undo stack (state snapshots taken just before each mutation).
  final List<GenogramState> _undoStack = <GenogramState>[];
  static const int _undoLimit = 100;
  // Coalesce repeated mutations (e.g. dragging a node) into one undo entry.
  String? _undoCoalesceKey;
  DateTime _lastUndoPush = DateTime.fromMillisecondsSinceEpoch(0);

  void _pushUndo({String? coalesceKey}) {
    final now = DateTime.now();
    if (coalesceKey != null &&
        coalesceKey == _undoCoalesceKey &&
        now.difference(_lastUndoPush) < const Duration(milliseconds: 500)) {
      _lastUndoPush = now;
      return;
    }
    _undoStack.add(_state);
    if (_undoStack.length > _undoLimit) {
      _undoStack.removeAt(0);
    }
    _undoCoalesceKey = coalesceKey;
    _lastUndoPush = now;
  }

  bool get canUndo => _undoStack.isNotEmpty;

  void undo() {
    if (_undoStack.isEmpty) return;
    _state = _undoStack.removeLast();
    _undoCoalesceKey = null;
    _selectedPersonId = null;
    _selectedRelationshipId = null;
    _selectedPersonIds.clear();
    _connectSourceId = null;
    notifyListeners();
  }

  // ----------------------------------------------------------------
  // Getters
  // ----------------------------------------------------------------
  GenogramState get state => _state;
  AppMode get mode => _mode;
  String? get selectedPersonId => _selectedPersonId;
  String? get selectedRelationshipId => _selectedRelationshipId;
  String? get connectSourceId => _connectSourceId;
  Set<String> get selectedPersonIds => _selectedPersonIds;
  Offset get viewOffset => _viewOffset;
  double get viewScale => _viewScale;

  Map<String, Person> get persons => _state.persons;
  Map<String, Relationship> get relationships => _state.relationships;

  String? get focusPersonId => _focusPersonId;
  int get focusDepth => _focusDepth;
  bool get isFocused => _focusPersonId != null;

  /// Persons within [_focusDepth] hops of [_focusPersonId] via any
  /// relationship. Empty when focus mode is off (meaning: render everyone).
  Set<String> get focusedPersonIds {
    final root = _focusPersonId;
    if (root == null) return const <String>{};
    final adjacency = <String, Set<String>>{};
    for (final rel in _state.relationships.values) {
      adjacency.putIfAbsent(rel.sourceId, () => <String>{}).add(rel.targetId);
      adjacency.putIfAbsent(rel.targetId, () => <String>{}).add(rel.sourceId);
    }
    final visited = <String>{root};
    var frontier = <String>{root};
    for (var i = 0; i < _focusDepth; i++) {
      final next = <String>{};
      for (final id in frontier) {
        for (final n in (adjacency[id] ?? const <String>{})) {
          if (visited.add(n)) next.add(n);
        }
      }
      if (next.isEmpty) break;
      frontier = next;
    }
    return visited;
  }

  void setFocusPerson(String? id) {
    _focusPersonId = id;
    notifyListeners();
  }

  void setFocusDepth(int depth) {
    _focusDepth = depth.clamp(0, 10);
    notifyListeners();
  }

  void clearFocus() {
    _focusPersonId = null;
    notifyListeners();
  }

  // ----------------------------------------------------------------
  // Inspect mode
  // ----------------------------------------------------------------
  static const Set<String> kEmotionalCategories = {
    'Positive', 'Negative', 'Violence', 'Abuse', 'Control',
  };

  String? get inspectPersonId {
    // Explicit override (e.g. Inspect toolbar button) wins.
    if (_inspectPersonId != null) return _inspectPersonId;
    // Auto-engage on single-person selection in select mode.
    if (_inspectSuppressed) return null;
    if (_mode != AppMode.select) return null;
    if (_selectedPersonIds.isNotEmpty) return null;
    return _selectedPersonId;
  }
  bool get isInspecting => inspectPersonId != null;

  /// Emotional/clinical relationships (Positive, Negative, Violence, Abuse,
  /// Control — skipping Structural and Neutral) that touch the inspected
  /// person. Empty when inspect mode is off.
  List<Relationship> get inspectEmotionalRels {
    final id = inspectPersonId;
    if (id == null) return const [];
    return _state.relationships.values.where((r) {
      if (r.sourceId != id && r.targetId != id) return false;
      final cat = kRelationshipDefs[r.type]?.category ?? '';
      return kEmotionalCategories.contains(cat);
    }).toList();
  }

  /// Ids of all "other" persons connected to the inspected person by an
  /// emotional relationship. The inspected id itself is included.
  Set<String> get inspectHighlightIds {
    final id = inspectPersonId;
    if (id == null) return const {};
    final s = <String>{id};
    for (final r in inspectEmotionalRels) {
      s.add(r.sourceId == id ? r.targetId : r.sourceId);
    }
    return s;
  }

  bool isEmotionalRelOnInspected(Relationship r) {
    final id = inspectPersonId;
    if (id == null) return false;
    if (r.sourceId != id && r.targetId != id) return false;
    final cat = kRelationshipDefs[r.type]?.category ?? '';
    return kEmotionalCategories.contains(cat);
  }

  /// Force inspect to a specific person (overrides selection-based auto).
  void setInspectPerson(String? id) {
    _inspectPersonId = id;
    _inspectSuppressed = false;
    notifyListeners();
  }

  /// Hide the inspect panel for the current selection without deselecting.
  /// The panel will reappear when a different person is selected.
  void hideInspect() {
    _inspectPersonId = null;
    _inspectSuppressed = true;
    notifyListeners();
  }

  void clearInspect() {
    _inspectPersonId = null;
    _inspectSuppressed = false;
    notifyListeners();
  }

  // ----------------------------------------------------------------
  // Emotional tie visibility (global)
  // ----------------------------------------------------------------
  bool get hideEmotionalTies => _hideEmotionalTies;

  void toggleHideEmotionalTies() {
    _hideEmotionalTies = !_hideEmotionalTies;
    notifyListeners();
  }

  void setHideEmotionalTies(bool v) {
    if (_hideEmotionalTies == v) return;
    _hideEmotionalTies = v;
    notifyListeners();
  }

  static bool isEmotionalRel(Relationship r) {
    final cat = kRelationshipDefs[r.type]?.category ?? '';
    return kEmotionalCategories.contains(cat);
  }

  Person? get selectedPerson =>
      _selectedPersonId != null ? _state.persons[_selectedPersonId] : null;

  Relationship? get selectedRelationship =>
      _selectedRelationshipId != null ? _state.relationships[_selectedRelationshipId] : null;

  // ----------------------------------------------------------------
  // ID generation
  // ----------------------------------------------------------------
  String _nextPersonId() {
    final id = 'p${_state.nextId}';
    _state = _state.copyWith(nextId: _state.nextId + 1);
    return id;
  }

  String _nextRelId() {
    final id = 'r${_state.nextId}';
    _state = _state.copyWith(nextId: _state.nextId + 1);
    return id;
  }

  // ----------------------------------------------------------------
  // Person CRUD
  // ----------------------------------------------------------------
  String addPerson(Gender gender, {Size? viewportSize}) {
    if (!_state.canAddPerson) return '';
    _pushUndo();
    final id = _nextPersonId();
    final position = _nextSpawnPosition(viewportSize);
    final person = Person(
      id: id,
      gender: gender,
      position: position,
    );
    final updated = Map<String, Person>.from(_state.persons)..[id] = person;
    _state = _state.copyWith(persons: updated);
    notifyListeners();
    return id;
  }

  /// Pick a world-space spawn position that lands inside the current viewport
  /// (if [viewportSize] is provided). Uses a small grid offset from the
  /// viewport's top-left so multiple adds don't stack exactly.
  Offset _nextSpawnPosition(Size? viewportSize) {
    const nodeSize = 52.0;
    const margin = 24.0;
    final i = persons.length;
    final col = i % 5;
    final row = i ~/ 5;
    final localOffset = Offset(col * 120.0, row * 140.0);

    if (viewportSize == null) {
      return localOffset;
    }
    // Convert viewport top-left (screen 0,0) to world coords, then place
    // the spawn grid inside the visible region.
    final worldTopLeft = (-_viewOffset) / _viewScale;
    final worldVisibleW = viewportSize.width / _viewScale;
    final worldVisibleH = viewportSize.height / _viewScale;
    final baseX = worldTopLeft.dx + margin;
    final baseY = worldTopLeft.dy + margin;
    // Keep within visible bounds; wrap if needed.
    final maxCols =
        ((worldVisibleW - margin * 2) / 120.0).floor().clamp(1, 999);
    final wrappedCol = col % maxCols;
    final wrappedRow = row + (col ~/ maxCols);
    var x = baseX + wrappedCol * 120.0;
    var y = baseY + wrappedRow * 140.0;
    // Clamp so the node stays on screen.
    final maxX = worldTopLeft.dx + worldVisibleW - nodeSize - margin;
    final maxY = worldTopLeft.dy + worldVisibleH - nodeSize - margin;
    if (x > maxX) x = maxX;
    if (y > maxY) y = maxY;
    return Offset(x, y);
  }

  void updatePerson(Person person) {
    _pushUndo(coalesceKey: 'updatePerson:${person.id}');
    final updated = Map<String, Person>.from(_state.persons)..[person.id] = person;
    _state = _state.copyWith(persons: updated);
    notifyListeners();
  }

  void movePerson(String id, Offset delta) {
    final person = _state.persons[id];
    if (person == null) return;
    _pushUndo(coalesceKey: 'movePerson:$id');
    final updated = Map<String, Person>.from(_state.persons)
      ..[id] = person.copyWith(position: person.position + delta);
    _state = _state.copyWith(persons: updated);
    notifyListeners();
  }

  /// Set absolute positions for many persons in a single mutation. Used while
  /// dragging a multi-selection so all selected nodes translate together
  /// without piling up undo entries or notifyListeners storms.
  void setPersonPositions(Map<String, Offset> positions,
      {String? coalesceKey}) {
    if (positions.isEmpty) return;
    _pushUndo(coalesceKey: coalesceKey ?? 'setPersonPositions');
    final updated = Map<String, Person>.from(_state.persons);
    for (final entry in positions.entries) {
      final p = updated[entry.key];
      if (p == null) continue;
      updated[entry.key] = p.copyWith(position: entry.value);
    }
    _state = _state.copyWith(persons: updated);
    notifyListeners();
  }

  void deletePerson(String id) {
    _pushUndo();
    final updatedPersons = Map<String, Person>.from(_state.persons)..remove(id);
    // Cascade delete attached relationships
    final updatedRels = Map<String, Relationship>.from(_state.relationships)
      ..removeWhere((_, r) => r.sourceId == id || r.targetId == id);
    _state = _state.copyWith(persons: updatedPersons, relationships: updatedRels);
    if (_selectedPersonId == id) _selectedPersonId = null;
    notifyListeners();
  }

  // ----------------------------------------------------------------
  // Relationship CRUD
  // ----------------------------------------------------------------
  String addRelationship(String sourceId, String targetId, RelationshipType type) {
    _pushUndo();
    final id = _nextRelId();
    final rel = Relationship(
      id: id,
      sourceId: sourceId,
      targetId: targetId,
      type: type,
    );
    final updated = Map<String, Relationship>.from(_state.relationships)..[id] = rel;
    _state = _state.copyWith(relationships: updated);
    notifyListeners();
    return id;
  }

  void updateRelationship(Relationship rel) {
    _pushUndo();
    final updated = Map<String, Relationship>.from(_state.relationships)..[rel.id] = rel;
    _state = _state.copyWith(relationships: updated);
    notifyListeners();
  }

  void deleteRelationship(String id) {
    _pushUndo();
    final updated = Map<String, Relationship>.from(_state.relationships)..remove(id);
    _state = _state.copyWith(relationships: updated);
    if (_selectedRelationshipId == id) _selectedRelationshipId = null;
    notifyListeners();
  }

  // ----------------------------------------------------------------
  // Selection
  // ----------------------------------------------------------------
  void selectPerson(String? id) {
    if (_selectedPersonId != id) {
      _inspectSuppressed = false;
      _inspectPersonId = null;
    }
    _selectedPersonId = id;
    _selectedRelationshipId = null;
    notifyListeners();
  }

  void selectRelationship(String? id) {
    _selectedRelationshipId = id;
    _selectedPersonId = null;
    notifyListeners();
  }

  void clearSelection() {
    _selectedPersonId = null;
    _selectedRelationshipId = null;
    _selectedPersonIds.clear();
    notifyListeners();
  }

  // ----------------------------------------------------------------
  // Multi-selection
  // ----------------------------------------------------------------
  void togglePersonInMultiSelection(String id) {
    if (_selectedPersonIds.contains(id)) {
      _selectedPersonIds.remove(id);
    } else {
      _selectedPersonIds.add(id);
    }
    _selectedPersonId = null;
    _selectedRelationshipId = null;
    notifyListeners();
  }

  void setMultiSelection(Set<String> ids) {
    _selectedPersonIds
      ..clear()
      ..addAll(ids);
    _selectedPersonId = null;
    _selectedRelationshipId = null;
    notifyListeners();
  }

  void clearMultiSelection() {
    if (_selectedPersonIds.isEmpty) return;
    _selectedPersonIds.clear();
    notifyListeners();
  }

  void deleteSelectedPersons() {
    if (_selectedPersonIds.isEmpty) return;
    _pushUndo();
    final ids = _selectedPersonIds.toSet();
    final updatedPersons = Map<String, Person>.from(_state.persons)
      ..removeWhere((id, _) => ids.contains(id));
    final updatedRels = Map<String, Relationship>.from(_state.relationships)
      ..removeWhere((_, r) => ids.contains(r.sourceId) || ids.contains(r.targetId));
    _state = _state.copyWith(persons: updatedPersons, relationships: updatedRels);
    _selectedPersonIds.clear();
    if (_selectedPersonId != null && ids.contains(_selectedPersonId)) {
      _selectedPersonId = null;
    }
    notifyListeners();
  }

  /// Apply [type] as a relationship between every pair of selected nodes.
  /// Skips pairs that already have any relationship between them.
  int connectSelectedAs(RelationshipType type) {
    if (_selectedPersonIds.length < 2) return 0;
    _pushUndo();
    final ids = _selectedPersonIds.toList();
    final updatedRels = Map<String, Relationship>.from(_state.relationships);
    int added = 0;
    bool pairExists(String a, String b) => updatedRels.values.any((r) =>
        (r.sourceId == a && r.targetId == b) ||
        (r.sourceId == b && r.targetId == a));
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        if (pairExists(ids[i], ids[j])) continue;
        final id = _nextRelId();
        updatedRels[id] = Relationship(
          id: id,
          sourceId: ids[i],
          targetId: ids[j],
          type: type,
        );
        added++;
      }
    }
    _state = _state.copyWith(relationships: updatedRels);
    notifyListeners();
    return added;
  }

  // ----------------------------------------------------------------
  // Connect mode
  // ----------------------------------------------------------------
  void setMode(AppMode mode) {
    _mode = mode;
    _connectSourceId = null;
    if (mode != AppMode.marquee) _selectedPersonIds.clear();
    notifyListeners();
  }

  void toggleConnectMode() {
    setMode(_mode == AppMode.connect ? AppMode.select : AppMode.connect);
  }

  /// Returns true if a relationship picker should be shown,
  /// with [pendingSource] and [pendingTarget] populated.
  bool handleConnectTap(String nodeId, {
    required Function(String src, String tgt) onReadyToPick,
  }) {
    if (_connectSourceId == null) {
      _connectSourceId = nodeId;
      notifyListeners();
      return false;
    }
    if (_connectSourceId == nodeId) {
      // Tapped same node -- deselect source
      _connectSourceId = null;
      notifyListeners();
      return false;
    }
    final src = _connectSourceId!;
    _connectSourceId = null;
    onReadyToPick(src, nodeId);
    return true;
  }

  void cancelConnect() {
    _connectSourceId = null;
    _mode = AppMode.select;
    notifyListeners();
  }

  // ----------------------------------------------------------------
  // View transform
  // ----------------------------------------------------------------
  void updateView({Offset? offset, double? scale}) {
    if (offset != null) _viewOffset = offset;
    if (scale != null) _viewScale = scale.clamp(0.1, 4.0);
    notifyListeners();
  }

  /// Zoom by [factor] keeping the world point under [focal] (in screen coords)
  /// stationary. If [focal] is null, zooms about the current viewport center
  /// using [canvasSize].
  void zoomBy(double factor, {Offset? focal, Size? canvasSize}) {
    final newScale = (_viewScale * factor).clamp(0.1, 4.0);
    if (newScale == _viewScale) return;
    final f = focal ??
        (canvasSize != null
            ? Offset(canvasSize.width / 2, canvasSize.height / 2)
            : Offset.zero);
    final ratio = newScale / _viewScale;
    _viewOffset = Offset(
      f.dx - (f.dx - _viewOffset.dx) * ratio,
      f.dy - (f.dy - _viewOffset.dy) * ratio,
    );
    _viewScale = newScale;
    notifyListeners();
  }

  void resetZoom() {
    _viewScale = 1.0;
    _viewOffset = Offset.zero;
    notifyListeners();
  }

  void fitView(Size canvasSize) {
    final ps = _state.persons.values;
    if (ps.isEmpty) return;
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in ps) {
      minX = minX < p.position.dx ? minX : p.position.dx;
      minY = minY < p.position.dy ? minY : p.position.dy;
      maxX = maxX > p.position.dx ? maxX : p.position.dx;
      maxY = maxY > p.position.dy ? maxY : p.position.dy;
    }
    const nodeSize = 52.0;
    final dw = maxX - minX + nodeSize + 80;
    final dh = maxY - minY + nodeSize + 80;
    final scaleX = canvasSize.width / dw;
    final scaleY = canvasSize.height / dh;
    _viewScale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.1, 2.0);
    _viewOffset = Offset(
      (canvasSize.width - dw * _viewScale) / 2 - minX * _viewScale + 40 * _viewScale,
      (canvasSize.height - dh * _viewScale) / 2 - minY * _viewScale + 40 * _viewScale,
    );
    notifyListeners();
  }

  // ----------------------------------------------------------------
  // Layout
  // ----------------------------------------------------------------
  /// Layered layout with two anti-crossing passes per generation:
  ///   1. Sort by parent barycenter so children land under their parents.
  ///   2. Pull each person's first un-placed same-generation partner in
  ///      directly after them, so couple lines stay short.
  ///
  /// Siblings of the same couple share the same barycenter, so they fall
  /// into a contiguous block — sibling bars and parent-child drops collapse
  /// to tidy local geometry instead of long diagonal sweeps.
  void runAutoLayout() {
    final ps = _state.persons.values.toList();
    if (ps.isEmpty) return;
    _pushUndo();

    const coupleTypes = <RelationshipType>{
      RelationshipType.married,
      RelationshipType.partnership,
      RelationshipType.engaged,
      RelationshipType.separated,
      RelationshipType.divorced,
    };

    // Adjacency: person -> couple partners, child -> parents.
    final partners = <String, List<String>>{};
    final parentsOf = <String, List<String>>{};
    for (final r in _state.relationships.values) {
      if (coupleTypes.contains(r.type)) {
        partners.putIfAbsent(r.sourceId, () => []).add(r.targetId);
        partners.putIfAbsent(r.targetId, () => []).add(r.sourceId);
      } else if (r.type == RelationshipType.parentChild) {
        parentsOf.putIfAbsent(r.targetId, () => []).add(r.sourceId);
      }
    }

    // Bucket by generation.
    final Map<int, List<Person>> genMap = {};
    for (final p in ps) {
      genMap.putIfAbsent(p.generation, () => []).add(p);
    }
    final gens = genMap.keys.toList()..sort();
    final minGen = gens.first;

    const nodeSize = 52.0;
    const hSpacing = 100.0;
    const vSpacing = 150.0;
    final step = nodeSize + hSpacing;

    // x positions resolved generation-by-generation (top-down) so each row
    // can use the previous row's x for barycenter math.
    final xOf = <String, double>{};
    final orderByGen = <int, List<String>>{};

    for (final g in gens) {
      final rowIds = genMap[g]!.map((p) => p.id).toList();

      // Sort key for a person:
      //   - if parents have unequal partner counts (multi-marriage), anchor
      //     under the parent with FEWER partners so each child clusters
      //     under their unique biological parent rather than under a shared
      //     central ancestor;
      //   - otherwise barycenter (midpoint) of placed parents;
      //   - else the person's current x (preserves user-positioned roots).
      double keyOf(String id) {
        final pars = parentsOf[id] ?? const <String>[];
        final placedPars = <String>[
          for (final pid in pars)
            if (xOf[pid] != null) pid,
        ];
        if (placedPars.isEmpty) {
          return _state.persons[id]?.position.dx ?? 0.0;
        }
        final counts = <String, int>{
          for (final pid in placedPars)
            pid: (partners[pid]?.length ?? 0),
        };
        var minCount = counts.values.first;
        var maxCount = minCount;
        for (final c in counts.values) {
          if (c < minCount) minCount = c;
          if (c > maxCount) maxCount = c;
        }
        if (minCount != maxCount) {
          // Unequal partner counts → multi-marriage. Anchor under the
          // parent with the fewest partners (the branch-exclusive parent).
          final anchorPid =
              placedPars.firstWhere((pid) => counts[pid] == minCount);
          return xOf[anchorPid]!;
        }
        // Equal partner counts → standard couple, use midpoint.
        var s = 0.0;
        for (final pid in placedPars) {
          s += xOf[pid]!;
        }
        return s / placedPars.length;
      }

      // Tie-breaker: when two persons share the same barycenter (e.g.
      // siblings of the same couple) order them by birth year ascending —
      // oldest first, left-to-right — so siblings read chronologically.
      // Persons without a birth year sort after those that have one, with
      // id as the final stable tie-breaker.
      int byBirthThenId(String a, String b) {
        final by = _state.persons[a]?.birthYear;
        final bz = _state.persons[b]?.birthYear;
        if (by != null && bz != null) {
          final c = by.compareTo(bz);
          if (c != 0) return c;
        } else if (by != null) {
          return -1;
        } else if (bz != null) {
          return 1;
        }
        return a.compareTo(b);
      }

      rowIds.sort((a, b) {
        final ka = keyOf(a), kb = keyOf(b);
        final c = ka.compareTo(kb);
        if (c != 0) return c;
        return byBirthThenId(a, b);
      });

      // Root rows have no placed parents, so every keyOf falls back to the
      // existing dx and produces incidental ordering. Sort those rows by
      // birth year (then id) outright so the eldest sit to the left.
      final anyParentPlaced = rowIds.any((id) =>
          (parentsOf[id] ?? const <String>[])
              .any((pid) => xOf[pid] != null));
      if (!anyParentPlaced) {
        rowIds.sort(byBirthThenId);
      }

      // Chain partners: for each person, immediately place ALL un-placed
      // same-generation partners adjacent (recursively, so a partner's own
      // other partners are nested in too). This keeps multi-marriages
      // grouped as branches around the shared central ancestor instead of
      // scattering extra spouses across the row.
      final placed = <String>{};
      final finalOrder = <String>[];

      void addWithPartners(String id) {
        if (placed.contains(id)) return;
        placed.add(id);
        finalOrder.add(id);
        final candidates = (partners[id] ?? const <String>[])
            .where((pid) =>
                !placed.contains(pid) &&
                _state.persons[pid]?.generation == g)
            .toList();
        if (candidates.isEmpty) return;
        // Prefer partners whose own barycenter is closest to this person's
        // so we don't yank a partner away from their own children.
        final anchor = keyOf(id);
        candidates.sort((a, b) =>
            (keyOf(a) - anchor).abs().compareTo((keyOf(b) - anchor).abs()));
        for (final pt in candidates) {
          addWithPartners(pt);
        }
      }

      for (final id in rowIds) {
        addWithPartners(id);
      }
      orderByGen[g] = finalOrder;

      final totalW = finalOrder.length * step - hSpacing;
      final startX = -totalW / 2;
      for (var i = 0; i < finalOrder.length; i++) {
        xOf[finalOrder[i]] = startX + i * step;
      }
    }

    final updatedPersons = Map<String, Person>.from(_state.persons);
    for (final g in gens) {
      final y = (g - minGen) * vSpacing;
      for (final id in orderByGen[g]!) {
        final p = _state.persons[id]!;
        updatedPersons[id] = p.copyWith(position: Offset(xOf[id]!, y));
      }
    }

    _state = _state.copyWith(persons: updatedPersons);
    notifyListeners();
  }

  // ----------------------------------------------------------------
  // Serialization
  // ----------------------------------------------------------------
  String exportJson() => jsonEncode(_state.toJson());

  void importJson(String json) {
    _pushUndo();
    final data = jsonDecode(json) as Map<String, dynamic>;
    _state = GenogramState.fromJson(data);
    _selectedPersonId = null;
    _selectedRelationshipId = null;
    _connectSourceId = null;
    _mode = AppMode.select;
    notifyListeners();
  }

  /// Merge an incoming [GenogramState] into the current one.
  ///
  /// [personIdMap] maps incoming person IDs -> existing person IDs for entries
  /// that the caller has decided are the same person. Unmapped incoming
  /// persons are inserted as new entries with freshly allocated IDs.
  ///
  /// Matched persons keep their existing data, but missing scalar fields
  /// (birthYear, deathYear, notes) on the existing record are filled in
  /// from the incoming record when available.
  ///
  /// Relationships are remapped through the combined ID map. Relationships
  /// that would duplicate an existing relationship (same source/target/type,
  /// either direction for symmetric structural ties) are skipped.
  void mergeImport(GenogramState incoming, Map<String, String> personIdMap) {
    _pushUndo();

    var nextId = _state.nextId;
    String allocId() {
      final id = '$nextId';
      nextId += 1;
      return id;
    }

    final mergedPersons = Map<String, Person>.from(_state.persons);
    final idMap = <String, String>{}; // incoming person id -> final id

    // Matched persons first: keep existing, optionally fill missing fields.
    for (final entry in personIdMap.entries) {
      final inc = incoming.persons[entry.key];
      final existing = mergedPersons[entry.value];
      if (inc == null || existing == null) continue;
      idMap[entry.key] = entry.value;
      mergedPersons[entry.value] = existing.copyWith(
        birthYear: existing.birthYear ?? inc.birthYear,
        deathYear: existing.deathYear ?? inc.deathYear,
        notes: existing.notes.isEmpty ? inc.notes : existing.notes,
      );
    }

    // Unmatched incoming persons -> insert as new.
    // Offset positions so they don't overlap existing nodes.
    var insertedCount = 0;
    for (final entry in incoming.persons.entries) {
      if (idMap.containsKey(entry.key)) continue;
      if (mergedPersons.length >= GenogramState.maxNodes) break;
      final newId = 'p${allocId()}';
      idMap[entry.key] = newId;
      final p = entry.value;
      mergedPersons[newId] = p.copyWith(
        id: newId,
        position: p.position + Offset(40.0 * (insertedCount % 8), 40.0 * (insertedCount ~/ 8)),
      );
      insertedCount += 1;
    }

    // Build a set of signatures for existing relationships to dedupe.
    String relSig(String s, String t, RelationshipType type) {
      // Treat structural pair ties as undirected.
      const undirected = {
        RelationshipType.married,
        RelationshipType.partnership,
        RelationshipType.separated,
        RelationshipType.divorced,
        RelationshipType.engaged,
        RelationshipType.sibling,
      };
      if (undirected.contains(type)) {
        final pair = [s, t]..sort();
        return '${pair[0]}|${pair[1]}|${type.name}';
      }
      return '$s|$t|${type.name}';
    }

    final mergedRels = Map<String, Relationship>.from(_state.relationships);
    final existingSigs = <String>{
      for (final r in mergedRels.values) relSig(r.sourceId, r.targetId, r.type),
    };

    for (final r in incoming.relationships.values) {
      final s = idMap[r.sourceId];
      final t = idMap[r.targetId];
      if (s == null || t == null) continue;
      final sig = relSig(s, t, r.type);
      if (existingSigs.contains(sig)) continue;
      final newId = 'r${allocId()}';
      mergedRels[newId] = r.copyWith(id: newId, sourceId: s, targetId: t);
      existingSigs.add(sig);
    }

    _state = _state.copyWith(
      persons: mergedPersons,
      relationships: mergedRels,
      nextId: nextId,
    );
    _selectedPersonId = null;
    _selectedRelationshipId = null;
    _connectSourceId = null;
    notifyListeners();
  }

  void clearAll() {
    _pushUndo();
    _state = GenogramState.empty();
    _selectedPersonId = null;
    _selectedRelationshipId = null;
    _connectSourceId = null;
    _mode = AppMode.select;
    notifyListeners();
  }
}
