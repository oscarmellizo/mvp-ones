class PaymentProfile {
  final String? userId;
  final String? mercadoPagoEmail;
  final String? country;
  final String? documentType;
  final String? documentNumber;
  final String? phoneNumber;
  final String? fullName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PaymentProfile({
    this.userId,
    this.mercadoPagoEmail,
    this.country,
    this.documentType,
    this.documentNumber,
    this.phoneNumber,
    this.fullName,
    this.createdAt,
    this.updatedAt,
  });

  PaymentProfile copyWith({
    String? mercadoPagoEmail,
    String? country,
    String? documentType,
    String? documentNumber,
    String? phoneNumber,
    String? fullName,
  }) {
    return PaymentProfile(
      userId: userId,
      mercadoPagoEmail: mercadoPagoEmail ?? this.mercadoPagoEmail,
      country: country ?? this.country,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullName: fullName ?? this.fullName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory PaymentProfile.fromJson(Map<String, dynamic> json) {
    return PaymentProfile(
      userId: json['userId'] as String?,
      mercadoPagoEmail: json['mercadoPagoEmail'] as String?,
      country: json['country'] as String?,
      documentType: json['documentType'] as String?,
      documentNumber: json['documentNumber'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      fullName: json['fullName'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (mercadoPagoEmail != null) 'mercadoPagoEmail': mercadoPagoEmail,
        if (country != null) 'country': country,
        if (documentType != null) 'documentType': documentType,
        if (documentNumber != null) 'documentNumber': documentNumber,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (fullName != null) 'fullName': fullName,
      };

  static DateTime? _parseDate(Object? s) {
    if (s is String && s.isNotEmpty) {
      return DateTime.tryParse(s)?.toLocal();
    }
    return null;
  }
}
