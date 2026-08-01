class CourseModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String specs;
  final String terms;
  final bool isActive;
  final DateTime createdAt;

  CourseModel({
    required this.id,
    required this.name,
    this.description = '',
    this.price = 0,
    this.specs = '',
    this.terms = '',
    this.isActive = true,
    required this.createdAt,
  });

  factory CourseModel.fromMap(Map<String, dynamic> map) => CourseModel(
        id: map['id'] as String,
        name: map['name'] as String,
        description: (map['description'] as String?) ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0,
        specs: (map['specs'] as String?) ?? '',
        terms: (map['terms'] as String?) ?? '',
        isActive: (map['is_active'] as bool?) ?? true,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'specs': specs,
        'terms': terms,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };
}
