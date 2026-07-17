import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';
import '../../domain/subscription_plan.dart';
import '../../domain/subscriptions_repository.dart';
import '../../domain/user_subscription.dart';

class SubscriptionsApiRepository implements SubscriptionsRepository {
  final Dio Function(String? idToken) _dioFactory;

  String? _idToken;

  SubscriptionsApiRepository(OnesApiFactory apiFactory)
      : _dioFactory = ((idToken) => apiFactory.create(idToken: idToken).dio);

  SubscriptionsApiRepository.forTesting(Dio Function(String? idToken) dioFactory)
      : _dioFactory = dioFactory;

  void setIdToken(String? token) {
    _idToken = token;
  }

  @override
  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    final res = await _dioFactory(_idToken).get(
      '/v1/subscription-plans',
      options: _authOptions,
    );
    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionPlan.fromJson)
          .toList();
    }
    return [];
  }

  @override
  Future<UserSubscription?> getMySubscription() async {
    final res = await _dioFactory(_idToken).get(
      '/v1/users/me/subscription',
      options: _authOptions,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return UserSubscription.fromJson(data);
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> createMercadoPagoSubscription(String planId, {String? cardTokenId}) async {
    final res = await _dioFactory(_idToken).post(
      '/v1/users/me/subscription/mercadopago',
      data: {
        'planId': planId,
        if (cardTokenId != null && cardTokenId.trim().isNotEmpty) 'cardTokenId': cardTokenId.trim(),
      },
      options: _authOptions,
    );
    final data = res.data;
    return data is Map<String, dynamic> ? data : null;
  }

  Options get _authOptions => Options(
        extra: {
          'secure': [
            {
              'type': 'http',
              'scheme': 'bearer',
              'name': 'bearerAuth',
            }
          ],
        },
      );
}
