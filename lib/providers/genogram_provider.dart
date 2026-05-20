import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/genogram_state.dart';
import '../models/person.dart';
import '../models/relationship.dart';

enum AppMode { select, connect }

class GenogramProvider extends ChangeNotifier {
  GenogramState _state = GenogramState.empty();
  AppMode _mode = AppMode.select;
  String? _selectedPersonId;
  String? _selectedRelationshipId;
  String? _connectSourceId;
  Offset _viewOffset = Offset.zero;
  double _viewScale = 1.0;

  // ----------------------------------------------------------------
  // Getters
  // ----------------------------------------------------------------
  GenogramState get state => _state;
  AppMode get mode => _mode;
  String? get selectedPersonId => _selectedPersonId;
  String? get selectedRelationshipId => _selectedRelationshipId;
  String? get connectSourceId => _connectSourceId;
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
  String addPerson(Gender gender) {
    if (!_state.canAddPerson) return '';
    final id = _nextPersonId();
    final person = Person(
      id: id,
      gender: gender,
      position: Offset(
        (persons.length % 5) * 120.0,
        (persons.length ~/ 5) * 140.0,
      ),
    );
    final updated = Map<String, Person>.from(_state.persons)..[id] = person;
    _state = _state.copyWith(persons: updated);
    notifyListeners();
    return id;
  }

  void updatePerson(Person person) {
    final updated = Map<String, Person>.from(_state.persons)..[person.id] = person;
    _state = _state.copyWith(persons: updated);
    notifyListeners();
  }

  void movePerson(String id, Offset delta) {
    final person = _state.persons[id];
    if (person == null) return;
    final updated = Map<String, Person>.from(_state.persons)
      ..[id] = person.copyWith(position: person.position + delta);
    _state = _state.copyWith(persons: updated);
    notifyListeners();
  }

  void deletePerson(String id) {
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
    final updated = Map<String, Relationship>.from(_state.relationships)..[rel.id] = rel;
    _state = _state.copyWith(relationships: updated);
    notifyListeners();
  }

  void deleteRelationship(String id) {
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
    notifyListeners();
  }

  // ----------------------------------------------------------------
  // Connect mode
  // ----------------------------------------------------------------
  void setMode(AppMode mode) {
    _mode = mode;
    _connectSourceId = null;
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
    final data = jsonDecode(json) as Map<String, dynamic>;
    _state = GenogramState.fromJson(data);
    _selectedPersonId = null;
    _selectedRelationshipId = null;
    _connectSourceId = null;
    _mode = AppMode.select;
    notifyListeners();
  }

  void clearAll() {
    _state = GenogramState.empty();
    _selectedPersonId = null;
    _selectedRelationshipId = null;
    _connectSourceId = null;
    _mode = AppMode.select;
    notifyListeners();
  }
}
