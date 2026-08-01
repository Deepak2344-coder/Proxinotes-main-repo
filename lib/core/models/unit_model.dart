class UnitModel {
  final String id;
  final String subjectId;
  final String name;
  final int orderIndex;
  final DateTime createdAt;

  UnitModel({
    required this.id,
    required this.subjectId,
    required this.name,
    this.orderIndex = 0,
    required this.createdAt,
  });

  factory UnitModel.fromMap(Map<String, dynamic> map) => UnitModel(
        id: map['id'] as String,
        subjectId: map['subject_id'] as String,
        name: map['name'] as String,
        orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject_id': subjectId,
        'name': name,
        'order_index': orderIndex,
        'created_at': createdAt.toIso8601String(),
      };
}
