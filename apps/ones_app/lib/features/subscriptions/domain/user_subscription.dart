import '../../auth/domain/auth_user.dart';

class UserSubscription {
  final String userId;
  final String planId;
  final String status;
  final String? mercadoPagoPreapprovalId;
  final String? startedAt;
  final String? expiresAt;
  final String? nextPaymentDate;
  final AuthUser? user;

  const UserSubscription({
    required this.userId,
    required this.planId,
    required this.status,
    this.mercadoPagoPreapprovalId,
    this.startedAt,
    this.expiresAt,
    this.nextPaymentDate,
    this.user,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>?;
    return UserSubscription(
      userId: json['userId'] as String,
      planId: json['planId'] as String,
      status: json['status'] as String,
      mercadoPagoPreapprovalId: json['mercadoPagoPreapprovalId'] as String?,
      startedAt: json['startedAt'] as String?,
      expiresAt: json['expiresAt'] as String?,
      nextPaymentDate: json['nextPaymentDate'] as String?,
      user: userJson != null ? AuthUser.fromJson(userJson) : null,
    );
  }

  bool get isActive => status.toLowerCase() == 'active' || status.toLowerCase() == 'free';

  bool get isFree => planId.toLowerCase() == 'free';
}
