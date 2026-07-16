import 'subscription_plan.dart';
import 'user_subscription.dart';

abstract interface class SubscriptionsRepository {
  Future<List<SubscriptionPlan>> getSubscriptionPlans();

  Future<UserSubscription?> getMySubscription();

  Future<Map<String, dynamic>?> createMercadoPagoSubscription(String planId);
}
