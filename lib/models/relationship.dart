enum RelationshipType {
  // ---- Structural ----
  married,
  partnership,
  separated,
  divorced,
  engaged,
  parentChild,
  sibling,
  // ---- Neutral / Baseline ----
  plain,           // Plain / Normal -- dotted line
  indifferent,     // Indifferent / Apathetic -- dashed thin
  distant,         // Distant / Poor -- sparse dash
  cutoff,          // Cutoff / Estranged -- dashed with break bar
  // ---- Positive ----
  harmony,         // Harmony -- green double
  friendship,      // Friendship / Close -- green triple
  love,            // Love -- green thick with hearts (circles)
  inLove,          // In Love -- green thick with heart symbols
  // ---- Fused ----
  fused,           // Fused -- triple close parallel
  // ---- Negative basic ----
  distrust,        // Distrust -- red dashed
  hostile,         // Hostile -- red zigzag single
  // ---- Hostile variants ----
  distantHostile,  // Distant-Hostile -- sparse red zigzag
  closeHostile,    // Close-Hostile -- double red zigzag
  fusedHostile,    // Fused-Hostile -- triple red zigzag
  // ---- Discord ----
  discord,         // Discord / Conflict -- orange zigzag
  // ---- Violence variants ----
  violence,        // Violence -- red heavy zigzag
  distantViolence, // Distant-Violence
  closeViolence,   // Close-Violence
  fusedViolence,   // Fused-Violence
  // ---- Abuse variants ----
  abuse,           // Abuse -- dark red zigzag
  physicalAbuse,   // Physical Abuse -- thick dark red zigzag
  emotionalAbuse,  // Emotional Abuse -- purple zigzag
  sexualAbuse,     // Sexual Abuse -- blue dashed zigzag
  neglect,         // Neglect -- blue dashed arrow
  // ---- Control / Manipulation ----
  manipulative,    // Manipulative -- orange crossed arrows
  controlling,     // Controlling -- red crossed arrows
  jealous,         // Jealous -- thin line with circle markers
  focusedOn,       // Focused On -- arrow line
  fanAdmirer,      // Fan / Admirer -- open circle markers
  limerence,       // Limerence -- filled heart markers
  // ---- Other ----
  neverMet,        // Never Met -- box marker
  other,           // Other -- question mark line
}

class RelationshipDefinition {
  final String label;
  final String category;
  const RelationshipDefinition({required this.label, required this.category});
}

const Map<RelationshipType, RelationshipDefinition> kRelationshipDefs = {
  // Structural
  RelationshipType.married:        RelationshipDefinition(label: 'Married',            category: 'Structural'),
  RelationshipType.partnership:    RelationshipDefinition(label: 'Partnership/Cohabit', category: 'Structural'),
  RelationshipType.separated:      RelationshipDefinition(label: 'Separated',           category: 'Structural'),
  RelationshipType.divorced:       RelationshipDefinition(label: 'Divorced',            category: 'Structural'),
  RelationshipType.engaged:        RelationshipDefinition(label: 'Engaged',             category: 'Structural'),
  RelationshipType.parentChild:    RelationshipDefinition(label: 'Parent-Child',        category: 'Structural'),
  RelationshipType.sibling:        RelationshipDefinition(label: 'Sibling',             category: 'Structural'),
  // Neutral
  RelationshipType.plain:          RelationshipDefinition(label: 'Plain / Normal',      category: 'Neutral'),
  RelationshipType.indifferent:    RelationshipDefinition(label: 'Indifferent / Apathetic', category: 'Neutral'),
  RelationshipType.distant:        RelationshipDefinition(label: 'Distant / Poor',      category: 'Neutral'),
  RelationshipType.cutoff:         RelationshipDefinition(label: 'Cutoff / Estranged',  category: 'Neutral'),
  // Positive
  RelationshipType.harmony:        RelationshipDefinition(label: 'Harmony',             category: 'Positive'),
  RelationshipType.friendship:     RelationshipDefinition(label: 'Friendship / Close',  category: 'Positive'),
  RelationshipType.love:           RelationshipDefinition(label: 'Love',                category: 'Positive'),
  RelationshipType.inLove:         RelationshipDefinition(label: 'In Love',             category: 'Positive'),
  RelationshipType.fused:          RelationshipDefinition(label: 'Fused',               category: 'Positive'),
  // Negative
  RelationshipType.distrust:       RelationshipDefinition(label: 'Distrust',            category: 'Negative'),
  RelationshipType.hostile:        RelationshipDefinition(label: 'Hostile',             category: 'Negative'),
  RelationshipType.discord:        RelationshipDefinition(label: 'Discord / Conflict',  category: 'Negative'),
  RelationshipType.distantHostile: RelationshipDefinition(label: 'Distant-Hostile',     category: 'Negative'),
  RelationshipType.closeHostile:   RelationshipDefinition(label: 'Close-Hostile',       category: 'Negative'),
  RelationshipType.fusedHostile:   RelationshipDefinition(label: 'Fused-Hostile',       category: 'Negative'),
  // Violence
  RelationshipType.violence:       RelationshipDefinition(label: 'Violence',            category: 'Violence'),
  RelationshipType.distantViolence:RelationshipDefinition(label: 'Distant-Violence',    category: 'Violence'),
  RelationshipType.closeViolence:  RelationshipDefinition(label: 'Close-Violence',      category: 'Violence'),
  RelationshipType.fusedViolence:  RelationshipDefinition(label: 'Fused-Violence',      category: 'Violence'),
  // Abuse
  RelationshipType.abuse:          RelationshipDefinition(label: 'Abuse',               category: 'Abuse'),
  RelationshipType.physicalAbuse:  RelationshipDefinition(label: 'Physical Abuse',      category: 'Abuse'),
  RelationshipType.emotionalAbuse: RelationshipDefinition(label: 'Emotional Abuse',     category: 'Abuse'),
  RelationshipType.sexualAbuse:    RelationshipDefinition(label: 'Sexual Abuse',        category: 'Abuse'),
  RelationshipType.neglect:        RelationshipDefinition(label: 'Neglect (abuse)',     category: 'Abuse'),
  // Control
  RelationshipType.manipulative:   RelationshipDefinition(label: 'Manipulative',        category: 'Control'),
  RelationshipType.controlling:    RelationshipDefinition(label: 'Controlling',         category: 'Control'),
  RelationshipType.jealous:        RelationshipDefinition(label: 'Jealous',             category: 'Control'),
  RelationshipType.focusedOn:      RelationshipDefinition(label: 'Focused On',          category: 'Control'),
  RelationshipType.fanAdmirer:     RelationshipDefinition(label: 'Fan / Admirer',       category: 'Control'),
  RelationshipType.limerence:      RelationshipDefinition(label: 'Limerence',           category: 'Control'),
  // Other
  RelationshipType.neverMet:       RelationshipDefinition(label: 'Never Met',           category: 'Other'),
  RelationshipType.other:          RelationshipDefinition(label: 'Other',               category: 'Other'),
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