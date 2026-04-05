import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';

class AdminEventTemplatesApiRepository {
  final OnesApiFactory _factory;
  String? _idToken;

  AdminEventTemplatesApiRepository(this._factory);

  void setIdToken(String? token) {
    _idToken = token;
  }

  Dio _dio() => _factory.create(idToken: _idToken).dio;

  Future<List<EventTemplateDto>> list({String? status}) async {
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }

    final res = await _dio().get(
      '/v1/admin/event-templates',
      queryParameters: query.isNotEmpty ? query : null,
    );

    final data = res.data as List;
    return data
        .map((e) => EventTemplateDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EventTemplateDto> create({
    required String name,
    required String status,
    required int? sortOrder,
    required List<String> frameIds,
  }) async {
    final res = await _dio().post(
      '/v1/admin/event-templates',
      data: {
        'name': name,
        'status': status,
        'sortOrder': sortOrder,
        'frameIds': frameIds,
      },
    );

    return EventTemplateDto.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EventTemplateDto> update({
    required String eventTemplateId,
    required String name,
    required String status,
    required int? sortOrder,
    required List<String> frameIds,
  }) async {
    final res = await _dio().put(
      '/v1/admin/event-templates/$eventTemplateId',
      data: {
        'name': name,
        'status': status,
        'sortOrder': sortOrder,
        'frameIds': frameIds,
      },
    );

    return EventTemplateDto.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete({required String eventTemplateId}) async {
    await _dio().delete('/v1/admin/event-templates/$eventTemplateId');
  }
}

class EventTemplateDto {
  final String eventTemplateId;
  final String name;
  final String status;
  final int? sortOrder;
  final List<String> frameIds;
  final String? createdAt;
  final String? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const EventTemplateDto({
    required this.eventTemplateId,
    required this.name,
    required this.status,
    required this.sortOrder,
    required this.frameIds,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory EventTemplateDto.fromJson(Map<String, dynamic> json) {
    final eventTemplateId = json['eventTemplateId'];
    final name = json['name'];
    final status = json['status'];
    final frameIds =
        (json['frameIds'] as List?)?.map((e) => e.toString()).toList() ?? [];

    if (eventTemplateId is! String || eventTemplateId.isEmpty) {
      throw StateError('Missing eventTemplateId');
    }
    if (name is! String || name.isEmpty) {
      throw StateError('Missing name');
    }
    if (status is! String) {
      throw StateError('Missing status');
    }

    return EventTemplateDto(
      eventTemplateId: eventTemplateId,
      name: name,
      status: status,
      sortOrder: json['sortOrder'] as int?,
      frameIds: frameIds,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      createdBy: json['createdBy'] as String?,
      updatedBy: json['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventTemplateId': eventTemplateId,
      'name': name,
      'status': status,
      'sortOrder': sortOrder,
      'frameIds': frameIds,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  EventTemplateDto copyWith({
    String? eventTemplateId,
    String? name,
    String? status,
    int? sortOrder,
    List<String>? frameIds,
    String? createdAt,
    String? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return EventTemplateDto(
      eventTemplateId: eventTemplateId ?? this.eventTemplateId,
      name: name ?? this.name,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      frameIds: frameIds ?? this.frameIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EventTemplateDto &&
        other.eventTemplateId == eventTemplateId &&
        other.name == name &&
        other.status == status &&
        other.sortOrder == sortOrder &&
        other.frameIds == frameIds &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.createdBy == createdBy &&
        other.updatedBy == updatedBy;
  }

  @override
  int get hashCode {
    return eventTemplateId.hashCode ^
        name.hashCode ^
        status.hashCode ^
        sortOrder.hashCode ^
        frameIds.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        createdBy.hashCode ^
        updatedBy.hashCode;
  }

  @override
  String toString() {
    return 'EventTemplateDto(eventTemplateId: $eventTemplateId, name: $name, status: $status, sortOrder: $sortOrder, frameIds: $frameIds, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, updatedBy: $updatedBy)';
  }
}
