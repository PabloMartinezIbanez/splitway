import 'gate_definition.dart';

class SectorDefinition {
  const SectorDefinition({
    required this.id,
    required this.order,
    required this.label,
    required this.gate,
  });

  final String id;
  final int order;
  final String label;
  final GateDefinition gate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'label': label,
        'gate': gate.toJson(),
      };

  factory SectorDefinition.fromJson(Map<String, dynamic> json) =>
      SectorDefinition(
        id: json['id'] as String,
        order: json['order'] as int,
        label: json['label'] as String,
        gate: GateDefinition.fromJson(json['gate'] as Map<String, dynamic>),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SectorDefinition &&
          other.id == id &&
          other.order == order &&
          other.label == label &&
          other.gate == gate;

  @override
  int get hashCode => Object.hash(id, order, label, gate);
}
