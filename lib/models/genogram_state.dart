import 'person.dart';
import 'relationship.dart';

class GenogramState {
  final Map<String, Person> persons;
  final Map<String, Relationship> relationships;
  final int nextId;
  final int version;

  static const int maxNodes = 200;

  const GenogramState({
    this.persons = const {},
    this.relationships = const {},
    this.nextId = 1,
    this.version = 1,
  });

  GenogramState copyWith({
    Map<String, Person>? persons,
    Map<String, Relationship>? relationships,
    int? nextId,
    int? version,
  }) {
    return GenogramState(
      persons: persons ?? this.persons,
      relationships: relationships ?? this.relationships,
      nextId: nextId ?? this.nextId,
      version: version ?? this.version,
    );
  }

  bool get canAddPerson => persons.length < maxNodes;

  Map<String, dynamic> toJson() => {
        'version': version,
        'nextId': nextId,
        'persons': persons.map((k, v) => MapEntry(k, v.toJson())),
        'relationships': relationships.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory GenogramState.fromJson(Map<String, dynamic> json) {
    final personsRaw = json['persons'] as Map<String, dynamic>? ?? {};
    final relsRaw = json['relationships'] as Map<String, dynamic>? ?? {};

    return GenogramState(
      version: json['version'] ?? 1,
      nextId: json['nextId'] ?? 1,
      persons: personsRaw.map(
        (k, v) => MapEntry(k, Person.fromJson(v as Map<String, dynamic>)),
      ),
      relationships: relsRaw.map(
        (k, v) => MapEntry(k, Relationship.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }

  static GenogramState empty() => const GenogramState();
}
