class SubjectModel {
  final String id;
  final String courseId;
  final String name;
  final int orderIndex;
  final DateTime createdAt;

  SubjectModel({
    required this.id,
    required this.courseId,
    required this.name,
    this.orderIndex = 0,
    required this.createdAt,
  });

  factory SubjectModel.fromMap(Map<String, dynamic> map) => SubjectModel(
        id: map['id'] as String,
        courseId: map['course_id'] as String,
        name: map['name'] as String,
        orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'course_id': courseId,
        'name': name,
        'order_index': orderIndex,
        'created_at': createdAt.toIso8601String(),
      };
}
