import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../domain/subscription_plan.dart';
import '../domain/subscriptions_repository.dart';
import '../domain/user_subscription.dart';

class SubscriptionsController extends ChangeNotifier {
  final SubscriptionsRepository _repository;

  SubscriptionsController(this._repository);

  bool _isLoading = false;
  String? _error;
  List<SubscriptionPlan> _plans = [];
  UserSubscription? _subscription;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SubscriptionPlan> get plans => _plans;
  UserSubscription? get subscription => _subscription;

  SubscriptionPlan? get currentPlan {
    final planId = _subscription?.planId;
    if (planId == null) return null;
    try {
      return _plans.firstWhere((p) => p.planId == planId);
    } catch (_) {
      return null;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> loadPlans() async {
    _setLoading(true);
    _error = null;
    try {
      _plans = await _repository.getSubscriptionPlans();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMySubscription() async {
    _setLoading(true);
    _error = null;
    try {
      _subscription = await _repository.getMySubscription();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAll() async {
    _setLoading(true);
    _error = null;
    try {
      final results = await Future.wait([
        _repository.getSubscriptionPlans(),
        _repository.getMySubscription(),
      ]);
      _plans = results[0] as List<SubscriptionPlan>;
      _subscription = results[1] as UserSubscription?;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> createMercadoPagoSubscription(String planId) async {
    _setLoading(true);
    _error = null;
    try {
      final result = await _repository.createMercadoPagoSubscription(planId);
      final initPoint = result?['initPoint'] as String?;
      return initPoint;
    } catch (e) {
      _error = _friendlyError(e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
      final msg = e.message;
      if (msg != null && msg.trim().isNotEmpty) {
        return msg.trim();
      }
    }
    return e.toString();
  }
}
