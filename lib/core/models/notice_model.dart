class Notice {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? linkUrl;
  final String? linkLabel;
  final bool isActive;
  final int priority;
  final String? minAppVersion;
  final String? maxAppVersion;
  final DateTime startsAt;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const Notice({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.linkUrl,
    this.linkLabel,
    required this.isActive,
    required this.priority,
    this.minAppVersion,
    this.maxAppVersion,
    required this.startsAt,
    this.expiresAt,
    required this.createdAt,
  });

  bool get isInfo => type == 'info';
  bool get isUrgent => type == 'urgent';
  bool get isUpdate => type == 'update';

  bool isApplicableToVersion(String appVersion) {
    if (minAppVersion != null &&
        _compareVersions(appVersion, minAppVersion!) < 0) {
      return false;
    }
    if (maxAppVersion != null &&
        _compareVersions(appVersion, maxAppVersion!) > 0) {
      return false;
    }
    return true;
  }

  bool isForcedForVersion(String appVersion) {
    if (minAppVersion != null &&
        _compareVersions(appVersion, minAppVersion!) < 0) {
      return true;
    }
    return false;
  }

  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 < p2) return -1;
      if (p1 > p2) return 1;
    }
    return 0;
  }

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        linkUrl: json['link_url'] as String?,
        linkLabel: json['link_label'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        priority: (json['priority'] as num?)?.toInt() ?? 0,
        minAppVersion: json['min_app_version'] as String?,
        maxAppVersion: json['max_app_version'] as String?,
        startsAt: DateTime.parse(json['starts_at'] as String),
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
