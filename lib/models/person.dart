import 'package:flutter/material.dart';

enum Gender { male, female, unknown }

enum SpecialType { none, pregnancy, miscarriage, abortion, stillbirth, twinMono, twinDi }

class PersonMarkers {
  final bool substance;
  final bool mental;
  final bool physical;
  final bool abusePerpetrator;
  final bool abuseVictim;
  final bool adopted;
  final bool foster;
  final bool indexPerson;

  const PersonMarkers({
    this.substance = false,
    this.mental = false,
    this.physical = false,
    this.abusePerpetrator = false,
    this.abuseVictim = false,
    this.adopted = false,
    this.foster = false,
    this.indexPerson = false,
  });

  PersonMarkers copyWith({
    bool? substance,
    bool? mental,
    bool? physical,
    bool? abusePerpetrator,
    bool? abuseVictim,
    bool? adopted,
    bool? foster,
    bool? indexPerson,
  }) {
    return PersonMarkers(
      substance: substance ?? this.substance,
      mental: mental ?? this.mental,
      physical: physical ?? this.physical,
      abusePerpetrator: abusePerpetrator ?? this.abusePerpetrator,
      abuseVictim: abuseVictim ?? this.abuseVictim,
      adopted: adopted ?? this.adopted,
      foster: foster ?? this.foster,
      indexPerson: indexPerson ?? this.indexPerson,
    );
  }

  Map<String, dynamic> toJson() => {
        'substance': substance,
        'mental': mental,
        'physical': physical,
        'abusePerpetrator': abusePerpetrator,
        'abuseVictim': abuseVictim,
        'adopted': adopted,
        'foster': foster,
        'indexPerson': indexPerson,
      };

  factory PersonMarkers.fromJson(Map<String, dynamic> json) => PersonMarkers(
        substance: json['substance'] ?? false,
        mental: json['mental'] ?? false,
        physical: json['physical'] ?? false,
        abusePerpetrator: json['abusePerpetrator'] ?? false,
        abuseVictim: json['abuseVictim'] ?? false,
        adopted: json['adopted'] ?? false,
        foster: json['foster'] ?? false,
        indexPerson: json['indexPerson'] ?? false,
      );

  bool get hasAny =>
      substance ||
      mental ||
      physical ||
      abusePerpetrator ||
      abuseVictim ||
      adopted ||
      foster ||
      indexPerson;
}

class Person {
  final String id;
  final String name;
  final Gender gender;
  final int? birthYear;
  final int? deathYear;
  final int generation;
  final SpecialType specialType;
  final PersonMarkers markers;
  final String notes;
  final Offset position;

  const Person({
    required this.id,
    this.name = '',
    this.gender = Gender.male,
    this.birthYear,
    this.deathYear,
    this.generation = 0,
    this.specialType = SpecialType.none,
    this.markers = const PersonMarkers(),
    this.notes = '',
    required this.position,
  });

  bool get isDeceased => deathYear != null;

  String get yearLabel {
    if (birthYear == null && deathYear == null) return '';
    if (deathYear != null) return '${birthYear ?? '?'}-$deathYear';
    return 'b.$birthYear';
  }

  Person copyWith({
    String? id,
    String? name,
    Gender? gender,
    int? birthYear,
    int? deathYear,
    int? generation,
    SpecialType? specialType,
    PersonMarkers? markers,
    String? notes,
    Offset? position,
    bool clearDeath = false,
    bool clearBirth = false,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      birthYear: clearBirth ? null : (birthYear ?? this.birthYear),
      deathYear: clearDeath ? null : (deathYear ?? this.deathYear),
      generation: generation ?? this.generation,
      specialType: specialType ?? this.specialType,
      markers: markers ?? this.markers,
      notes: notes ?? this.notes,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gender': gender.name,
        'birthYear': birthYear,
        'deathYear': deathYear,
        'generation': generation,
        'specialType': specialType.name,
        'markers': markers.toJson(),
        'notes': notes,
        'x': position.dx,
        'y': position.dy,
      };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        id: json['id'],
        name: json['name'] ?? '',
        gender: Gender.values.firstWhere(
          (g) => g.name == json['gender'],
          orElse: () => Gender.male,
        ),
        birthYear: json['birthYear'],
        deathYear: json['deathYear'],
        generation: json['generation'] ?? 0,
        specialType: SpecialType.values.firstWhere(
          (s) => s.name == json['specialType'],
          orElse: () => SpecialType.none,
        ),
        markers: PersonMarkers.fromJson(json['markers'] ?? {}),
        notes: json['notes'] ?? '',
        position: Offset(
          (json['x'] as num).toDouble(),
          (json['y'] as num).toDouble(),
        ),
      );
}
