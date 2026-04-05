import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';

class AdminFramesApiRepository {
  final OnesApiFactory _factory;
  String? _idToken;

  AdminFramesApiRepository(this._factory);

  void setIdToken(String? token) {
    _idToken = token;
  }

  Dio _dio() => _factory.create(idToken: _idToken).dio;

  Future<ListFramesResponse> list({
    String status = 'active',
    int limit = 50,
    String? nextToken,
  }) async {
    final res = await _dio().get(
      '/v1/admin/frames',
      queryParameters: {
        'status': status,
        'limit': limit,
        if (nextToken != null && nextToken.isNotEmpty) 'nextToken': nextToken,
      },
    );

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid list frames response');
    }

    final itemsRaw = data['items'];
    final List<FrameDto> items;
    if (itemsRaw is List) {
      items = itemsRaw
          .whereType<Map>()
          .map((m) => FrameDto.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false);
    } else {
      items = const [];
    }

    return ListFramesResponse(
      items: items,
      nextToken: data['nextToken'] as String?,
    );
  }

  Future<FrameDto> upsert({
    String? frameId,
    required String name,
    required String status,
    int? sortOrder,
  }) async {
    final res = await _dio().post(
      '/v1/admin/frames',
      data: {
        'frameId': frameId,
        'name': name,
        'status': status,
        'sortOrder': sortOrder,
      },
    );

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid upsert frame response');
    }
    return FrameDto.fromJson(data);
  }

  Future<void> delete({required String frameId}) async {
    await _dio().delete(
      '/v1/admin/frames/$frameId',
    );
  }

  Future<PresignPutResponse> presignPutAsset({
    required String frameId,
    required String contentType,
  }) async {
    final res = await _dio().post(
      '/v1/admin/frames/$frameId/asset/presign',
      data: {
        'contentType': contentType,
      },
    );

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid presign response');
    }

    final putUrl = data['putUrl'];
    final assetKey = data['assetKey'];
    if (putUrl is! String || putUrl.isEmpty) {
      throw StateError('Missing putUrl');
    }
    if (assetKey is! String || assetKey.isEmpty) {
      throw StateError('Missing assetKey');
    }

    return PresignPutResponse(
      putUrl: putUrl,
      assetKey: assetKey,
      expiresAt: data['expiresAt'] as String?,
    );
  }

  Future<String> getAssetUrl({required String frameId}) async {
    final res = await _dio().get(
      '/v1/admin/frames/$frameId/asset-url',
    );

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid asset-url response');
    }

    final url = data['url'];
    if (url is! String || url.isEmpty) {
      throw StateError('Missing url');
    }
    return url;
  }

  Future<void> uploadBytesToPresignedUrl({
    required String putUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );

    await dio.put(
      putUrl,
      data: Stream.fromIterable(<List<int>>[bytes]),
      options: Options(
        headers: {
          HttpHeaders.contentTypeHeader: contentType,
          HttpHeaders.contentLengthHeader: bytes.length,
        },
      ),
    );
  }
}

class ListFramesResponse {
  final List<FrameDto> items;
  final String? nextToken;

  const ListFramesResponse({
    required this.items,
    required this.nextToken,
  });
}

class PresignPutResponse {
  final String putUrl;
  final String assetKey;
  final String? expiresAt;

  const PresignPutResponse({
    required this.putUrl,
    required this.assetKey,
    required this.expiresAt,
  });
}

class FrameDto {
  final String frameId;
  final String name;
  final String status;
  final int? sortOrder;
  final String? assetKey;

  const FrameDto({
    required this.frameId,
    required this.name,
    required this.status,
    required this.sortOrder,
    required this.assetKey,
  });

  factory FrameDto.fromJson(Map<String, dynamic> json) {
    final frameId = json['frameId'];
    final name = json['name'];
    final status = json['status'];

    if (frameId is! String || frameId.isEmpty) {
      throw StateError('Missing frameId');
    }
    if (name is! String) {
      throw StateError('Missing name');
    }
    if (status is! String) {
      throw StateError('Missing status');
    }

    return FrameDto(
      frameId: frameId,
      name: name,
      status: status,
      sortOrder: json['sortOrder'] as int?,
      assetKey: json['assetKey'] as String?,
    );
  }
}
