import 'gate_definition.dart';
import 'geo_point.dart';
import 'sector_definition.dart';

enum RouteDifficulty { easy, medium, hard }

extension RouteDifficultyX on RouteDifficulty {
  String get id => name;

  static RouteDifficulty fromId(String value) {
    return RouteDifficulty.values.firstWhere(
      (d) => d.name == value,
      orElse: () => RouteDifficulty.medium,
    );
  }
}

class RouteTemplate {
  const RouteTemplate({
    required this.id,
    required this.name,
    required this.path,
    required this.startFinishGate,
    required this.sectors,
    required this.difficulty,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
  final List<GeoPoint> path;
  final GateDefinition startFinishGate;
  final List<SectorDefinition> sectors;
  final RouteDifficulty difficulty;
  final DateTime createdAt;

  RouteTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<GeoPoint>? path,
    GateDefinition? startFinishGate,
    List<SectorDefinition>? sectors,
    RouteDifficulty? difficulty,
    DateTime? createdAt,
  }) {
    return RouteTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      path: path ?? this.path,
      startFinishGate: startFinishGate ?? this.startFinishGate,
      sectors: sectors ?? this.sectors,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'path': path.map((p) => p.toJson()).toList(),
        'startFinishGate': startFinishGate.toJson(),
        'sectors': sectors.map((s) => s.toJson()).toList(),
        'difficulty': difficulty.id,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory RouteTemplate.fromJson(Map<String, dynamic> json) => RouteTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        path: (json['path'] as List<dynamic>)
            .map((e) => GeoPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        startFinishGate: GateDefinition.fromJson(
            json['startFinishGate'] as Map<String, dynamic>),
        sectors: (json['sectors'] as List<dynamic>)
            .map((e) => SectorDefinition.fromJson(e as Map<String, dynamic>))
            .toList(),
        difficulty:
            RouteDifficultyX.fromId(json['difficulty'] as String? ?? 'medium'),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
