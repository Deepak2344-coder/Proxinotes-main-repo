class SubscriptionModel {
  final String id;
  final String userId;
  final String? razorpaySubscriptionId;
  final String status;
  final DateTime? currentPeriodEnd;
  final DateTime? graceUntil;
  final DateTime createdAt;

  SubscriptionModel({
    required this.id,
    required this.userId,
    this.razorpaySubscriptionId,
    required this.status,
    this.currentPeriodEnd,
    this.graceUntil,
    required this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isHalted => status == 'halted';

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) =>
      SubscriptionModel(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        razorpaySubscriptionId:
            map['razorpay_subscription_id'] as String?,
        status: map['status'] as String? ?? 'pending',
        currentPeriodEnd: map['current_period_end'] != null
            ? DateTime.parse(map['current_period_end'] as String)
            : null,
        graceUntil: map['grace_until'] != null
            ? DateTime.parse(map['grace_until'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
