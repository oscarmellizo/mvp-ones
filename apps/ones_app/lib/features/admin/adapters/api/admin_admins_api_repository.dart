import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';

class AdminAdminsApiRepository {
  final Dio Function(String? idToken) _dioFactory;

  String? _idToken;

  AdminAdminsApiRepository(OnesApiFactory apiFactory)
      : _dioFactory = ((idToken) => apiFactory.create(idToken: idToken).dio);

  AdminAdminsApiRepository.forTesting(Dio Function(String? idToken) dioFactory)
      : _dioFactory = dioFactory;

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<ListAdminUsersResult> list({int limit = 50, String? nextToken}) async {
    final res = await _dioFactory(_idToken).get(
      '/v1/admin/admins',
      queryParameters: {
        'limit': limit,
        if (nextToken != null && nextToken.isNotEmpty) 'nextToken': nextToken,
      },
    );

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      return const ListAdminUsersResult(items: [], nextToken: null);
    }

    final rawItems = data['items'];
    final items = <AdminUserView>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          items.add(AdminUserView.fromJson(it));
        }
      }
    }

    final token = data['nextToken'];
    return ListAdminUsersResult(
      items: items,
      nextToken: token is String && token.isNotEmpty ? token : null,
    );
  }

  Future<AdminUserView> upsert({required String email, required String status}) async {
    final res = await _dioFactory(_idToken).post(
      '/v1/admin/admins',
      data: {
        'email': email,
        'status': status,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic>) {
      return AdminUserView.fromJson(data);
    }
    throw StateError('Missing admin user in response');
  }

  Future<AdminUserView> updateStatus({required String email, required String status}) async {
    final res = await _dioFactory(_idToken).post(
      '/v1/admin/admins/status',
      data: {
        'email': email,
        'status': status,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic>) {
      return AdminUserView.fromJson(data);
    }
    throw StateError('Missing admin user in response');
  }
}

class ListAdminUsersResult {
  final List<AdminUserView> items;
  final String? nextToken;

  const ListAdminUsersResult({required this.items, required this.nextToken});
}

class AdminUserView {
  final String email;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const AdminUserView({
    required this.email,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory AdminUserView.fromJson(Map<String, dynamic> json) {
    DateTime? tryParse(String? v) {
      if (v == null || v.trim().isEmpty) return null;
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }

    return AdminUserView(
      email: (json['email'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? 'inactive').trim(),
      createdAt: tryParse(json['createdAt'] as String?),
      updatedAt: tryParse(json['updatedAt'] as String?),
      createdBy: json['createdBy'] as String?,
      updatedBy: json['updatedBy'] as String?,
    );
  }
}
