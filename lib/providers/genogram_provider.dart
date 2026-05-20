import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/genogram_state.dart';
import '../models/person.dart';
import '../models/relationship.dart';

enum AppMode { select, connect, marquee }

class GenogramProvider extends ChangeNotifier {
  GenogramState _state = GenogramState.empty();
  AppMode _mode = AppMode.select;
  String? _selectedPersonId;
  String? _selectedRelationshipId;
  String? _connectSourceId;
  final Set<String> _selectedPersonIds = <String>{};
  Offset _viewOffset = Offset.zero;
  double _viewScale = 1.0;

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
  void runAutoLayout() {
    final ps = _state.persons.values.toList();
    if (ps.isEmpty) return;
    _pushUndo();

    // Group by generation
    final Map<int, List<Person>> genMap = {};
    for (final p in ps) {
      genMap.putIfAbsent(p.generation, () => []).add(p);
    }

    final gens = genMap.keys.toList()..sort();
    final minGen = gens.first;
    final updatedPersons = Map<String, Person>.from(_state.persons);

    for (final g in gens) {
      final row = genMap[g]!;
      const nodeSize = 52.0;
      const hSpacing = 100.0;
      final totalW = row.length * (nodeSize + hSpacing) - hSpacing;
      final startX = -totalW / 2;
      final y = (g - minGen) * 150.0;
      for (int i = 0; i < row.length; i++) {
        final p = row[i];
        updatedPersons[p.id] = p.copyWith(
          position: Offset(startX + i * (nodeSize + hSpacing), y),
        );
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
