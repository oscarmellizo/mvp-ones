import 'subscription_plan.dart';
import 'user_subscription.dart';
import 'payment_profile.dart';

abstract interface class SubscriptionsRepository {
  Future<List<SubscriptionPlan>> getSubscriptionPlans();

  Future<UserSubscription?> getMySubscription();

  Future<Map<String, dynamic>?> createMercadoPagoSubscription(String planId, {String? cardTokenId});

  Future<PaymentProfile?> getMyPaymentProfile();

  Future<PaymentProfile> upsertMyPaymentProfile(PaymentProfile profile);
}
