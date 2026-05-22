import 'package:flutter/material.dart';
import '../models/genogram_state.dart';
import '../models/person.dart';
import '../models/relationship.dart';

/// Synthetic three-generation family used to seed the app on first launch and
/// to generate reference images. The index person is **Susan Hale**; all
/// other names are arbitrary / fictitious and do not correspond to anyone
/// real. Positions are pre-laid out so the tree renders nicely without any
/// auto-layout pass.
///
/// Layout (world coordinates, kNodeSize == 52):
///   y =   0  : grandparents     (generation -2)
///   y = 160  : parents + aunts  (generation -1)
///   y = 320  : index + siblings (generation  0)
///   y = 480  : children         (generation  1)
GenogramState buildDemoGenogramState() {
  // ---------- Generation -2: grandparents ----------
  const robert = Person(
    id: 'p1',
    name: 'Robert Hale',
    gender: Gender.male,
    birthYear: 1940,
    deathYear: 2010,
    generation: -2,
    position: Offset(180, 0),
  );
  const eleanor = Person(
    id: 'p2',
    name: 'Eleanor Hale',
    gender: Gender.female,
    birthYear: 1942,
    generation: -2,
    position: Offset(300, 0),
  );

  // ---------- Generation -1: parents & aunt ----------
  const michael = Person(
    id: 'p3',
    name: 'Michael Hale',
    gender: Gender.male,
    birthYear: 1965,
    generation: -1,
    markers: PersonMarkers(substance: true),
    position: Offset(120, 160),
  );
  const diane = Person(
    id: 'p4',
    name: 'Diane Hale',
    gender: Gender.female,
    birthYear: 1967,
    generation: -1,
    position: Offset(240, 160),
  );
  const patricia = Person(
    id: 'p5',
    name: 'Patricia Hale',
    gender: Gender.female,
    birthYear: 1970,
    generation: -1,
    markers: PersonMarkers(mental: true),
    position: Offset(420, 160),
  );

  // ---------- Generation 0: index + siblings + spouse ----------
  const susan = Person(
    id: 'p6',
    name: 'Susan Hale',
    gender: Gender.female,
    birthYear: 1992,
    generation: 0,
    markers: PersonMarkers(indexPerson: true),
    notes: 'Index person',
    position: Offset(60, 320),
  );
  const james = Person(
    id: 'p7',
    name: 'James Hale',
    gender: Gender.male,
    birthYear: 1995,
    generation: 0,
    position: Offset(240, 320),
  );
  const andrew = Person(
    id: 'p8',
    name: 'Andrew Wells',
    gender: Gender.male,
    birthYear: 1990,
    generation: 0,
    position: Offset(-60, 320),
  );

  // ---------- Generation 1: children ----------
  const lily = Person(
    id: 'p9',
    name: 'Lily Wells',
    gender: Gender.female,
    birthYear: 2018,
    generation: 1,
    position: Offset(-30, 480),
  );
  const noah = Person(
    id: 'p10',
    name: 'Noah Wells',
    gender: Gender.male,
    birthYear: 2020,
    generation: 1,
    position: Offset(90, 480),
  );

  final persons = <String, Person>{
    for (final p in const [
      robert, eleanor, michael, diane, patricia,
      susan, james, andrew, lily, noah,
    ])
      p.id: p,
  };

  // ---------- Relationships ----------
  const rels = <Relationship>[
    // Grandparents married, two children.
    Relationship(id: 'r1',  sourceId: 'p1', targetId: 'p2', type: RelationshipType.married),
    Relationship(id: 'r2',  sourceId: 'p1', targetId: 'p3', type: RelationshipType.parentChild),
    Relationship(id: 'r3',  sourceId: 'p2', targetId: 'p3', type: RelationshipType.parentChild),
    Relationship(id: 'r4',  sourceId: 'p1', targetId: 'p5', type: RelationshipType.parentChild),
    Relationship(id: 'r5',  sourceId: 'p2', targetId: 'p5', type: RelationshipType.parentChild),

    // Parents divorced, two children (Susan & James).
    Relationship(id: 'r6',  sourceId: 'p3', targetId: 'p4', type: RelationshipType.divorced),
    Relationship(id: 'r7',  sourceId: 'p3', targetId: 'p6', type: RelationshipType.parentChild),
    Relationship(id: 'r8',  sourceId: 'p4', targetId: 'p6', type: RelationshipType.parentChild),
    Relationship(id: 'r9',  sourceId: 'p3', targetId: 'p7', type: RelationshipType.parentChild),
    Relationship(id: 'r10', sourceId: 'p4', targetId: 'p7', type: RelationshipType.parentChild),

    // Susan married Andrew, two children.
    Relationship(id: 'r11', sourceId: 'p6', targetId: 'p8', type: RelationshipType.married),
    Relationship(id: 'r12', sourceId: 'p6', targetId: 'p9',  type: RelationshipType.parentChild),
    Relationship(id: 'r13', sourceId: 'p8', targetId: 'p9',  type: RelationshipType.parentChild),
    Relationship(id: 'r14', sourceId: 'p6', targetId: 'p10', type: RelationshipType.parentChild),
    Relationship(id: 'r15', sourceId: 'p8', targetId: 'p10', type: RelationshipType.parentChild),

    // A handful of emotional ties so the demo exercises non-structural lines.
    Relationship(id: 'r16', sourceId: 'p6', targetId: 'p2', type: RelationshipType.love,
        notes: 'Susan close to her grandmother'),
    Relationship(id: 'r17', sourceId: 'p6', targetId: 'p3', type: RelationshipType.distant,
        notes: 'Susan distant from her father'),
    Relationship(id: 'r18', sourceId: 'p7', targetId: 'p3', type: RelationshipType.hostile,
        notes: 'James hostile toward father'),
    Relationship(id: 'r19', sourceId: 'p6', targetId: 'p7', type: RelationshipType.friendship,
        notes: 'Susan & James are close siblings'),
  ];

  final relationships = <String, Relationship>{
    for (final r in rels) r.id: r,
  };

  return GenogramState(
    persons: persons,
    relationships: relationships,
    nextId: 20,
  );
}
