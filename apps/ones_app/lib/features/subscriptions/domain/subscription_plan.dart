class PlanFeature {
  final Object? value;
  final String? type;
  final String? label;

  const PlanFeature({this.value, this.type, this.label});

  factory PlanFeature.fromJson(Map<String, dynamic> json) {
    return PlanFeature(
      value: json['value'],
      type: json['type'] as String?,
      label: json['label'] as String?,
    );
  }
}

class SubscriptionPlan {
  final String planId;
  final String name;
  final String? shortDescription;
  final String tier;
  final int priceCents;
  final String? currency;
  final String? billingInterval;
  final Map<String, PlanFeature> features;

  const SubscriptionPlan({
    required this.planId,
    required this.name,
    this.shortDescription,
    required this.tier,
    required this.priceCents,
    this.currency,
    this.billingInterval,
    this.features = const {},
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final featuresJson = json['features'] as Map<String, dynamic>?;
    final features = <String, PlanFeature>{};
    if (featuresJson != null) {
      for (final entry in featuresJson.entries) {
        final value = entry.value;
        features[entry.key] = value is Map<String, dynamic>
            ? PlanFeature.fromJson(value)
            : const PlanFeature();
      }
    }
    return SubscriptionPlan(
      planId: json['planId'] as String,
      name: json['name'] as String,
      shortDescription: json['shortDescription'] as String?,
      tier: json['tier'] as String,
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String?,
      billingInterval: json['billingInterval'] as String?,
      features: features,
    );
  }

  Object? featureValue(String key) => features[key]?.value;

  int featureNumber(String key, int defaultValue) {
    final value = featureValue(key);
    if (value is num) return value.toInt();
    return defaultValue;
  }

  bool featureEnabled(String key) {
    final value = featureValue(key);
    return value is bool && value;
  }

  String formattedPrice() {
    if (priceCents == 0) return 'Gratis';
    final effectiveCurrency = (currency ?? 'COP').toUpperCase();
    final divisor = effectiveCurrency == 'COP' ? 1 : 100;
    final value = priceCents / divisor;
    return '\$ ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\\B(?=(\\d{3})+(?!\\d))'), (m) => '.')} ${currency ?? 'COP'}/${billingInterval == 'year' ? 'año' : 'mes'}';
  }
}
