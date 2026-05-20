enum RelationshipType {
  // Structural
  married,
  partnership,
  separated,
  divorced,
  engaged,
  parentChild,
  sibling,
  // Emotional
  close,
  veryClose,
  enmeshed,
  distant,
  conflicted,
  estranged,
  fusedConflicted,
  abusive,
}

class RelationshipDefinition {
  final String label;
  final String category;

  const RelationshipDefinition({
    required this.label,
    required this.category,
  });
}

const Map<RelationshipType, RelationshipDefinition> kRelationshipDefs = {
  RelationshipType.married:        RelationshipDefinition(label: 'Married',            category: 'Structural'),
  RelationshipType.partnership:    RelationshipDefinition(label: 'Partnership/Cohabit', category: 'Structural'),
  RelationshipType.separated:      RelationshipDefinition(label: 'Separated',           category: 'Structural'),
  RelationshipType.divorced:       RelationshipDefinition(label: 'Divorced',            category: 'Structural'),
  RelationshipType.engaged:        RelationshipDefinition(label: 'Engaged',             category: 'Structural'),
  RelationshipType.parentChild:    RelationshipDefinition(label: 'Parent-Child',        category: 'Structural'),
  RelationshipType.sibling:        RelationshipDefinition(label: 'Sibling',             category: 'Structural'),
  RelationshipType.close:          RelationshipDefinition(label: 'Close',               category: 'Emotional'),
  RelationshipType.veryClose:      RelationshipDefinition(label: 'Very Close / Fused',  category: 'Emotional'),
  RelationshipType.enmeshed:       RelationshipDefinition(label: 'Enmeshed',            category: 'Emotional'),
  RelationshipType.distant:        RelationshipDefinition(label: 'Distant',             category: 'Emotional'),
  RelationshipType.conflicted:     RelationshipDefinition(label: 'Conflicted',          category: 'Emotional'),
  RelationshipType.estranged:      RelationshipDefinition(label: 'Estranged / Cutoff',  category: 'Emotional'),
  RelationshipType.fusedConflicted:RelationshipDefinition(label: 'Fused-Conflicted',    category: 'Emotional'),
  RelationshipType.abusive:        RelationshipDefinition(label: 'Abusive',             category: 'Emotional'),
};

class Relationship {
  final String id;
  final String sourceId;
  final String targetId;
  final RelationshipType type;
  final String notes;

  const Relationship({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.type,
    this.notes = '',
  });

  Relationship copyWith({
    String? id,
    String? sourceId,
    String? targetId,
    RelationshipType? type,
    String? notes,
  }) {
    return Relationship(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      targetId: targetId ?? this.targetId,
      type: type ?? this.type,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceId': sourceId,
        'targetId': targetId,
        'type': type.name,
        'notes': notes,
      };

  factory Relationship.fromJson(Map<String, dynamic> json) => Relationship(
        id: json['id'],
        sourceId: json['sourceId'],
        targetId: json['targetId'],
        type: RelationshipType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => RelationshipType.parentChild,
        ),
        notes: json['notes'] ?? '',
      );
}
