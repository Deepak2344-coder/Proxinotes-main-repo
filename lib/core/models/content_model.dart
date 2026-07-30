class ContentModel {
  final String id;
  final String subject;
  final int chapter;
  final int pageCount;
  final String? cloudinaryFolder;
  final bool isPreview;
  final DateTime createdAt;

  ContentModel({
    required this.id,
    required this.subject,
    required this.chapter,
    required this.pageCount,
    this.cloudinaryFolder,
    required this.isPreview,
    required this.createdAt,
  });

  bool get isPaid => !isPreview;

  factory ContentModel.fromMap(Map<String, dynamic> map) => ContentModel(
        id: map['id'] as String,
        subject: map['subject'] as String,
        chapter: (map['chapter'] as num).toInt(),
        pageCount: (map['page_count'] as num).toInt(),
        cloudinaryFolder: map['cloudinary_folder'] as String?,
        isPreview: map['is_preview'] as bool? ?? false,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject': subject,
        'chapter': chapter,
        'page_count': pageCount,
        'cloudinary_folder': cloudinaryFolder,
        'is_preview': isPreview,
        'created_at': createdAt.toIso8601String(),
      };
}
