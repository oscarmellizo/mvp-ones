import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';
import '../../domain/event_photo.dart';

class ListPhotosPage {
  final List<EventPhoto> items;
  final String? nextToken;

  const ListPhotosPage({required this.items, required this.nextToken});
}

class EventPhotosApi {
  final Dio Function(String? idToken) _dioFactory;
  String? _idToken;

  EventPhotosApi(OnesApiFactory apiFactory)
      : _dioFactory = ((idToken) => apiFactory.create(idToken: idToken).dio);

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<PresignPutResponse> presignPut({
    required String eventId,
    required String photoId,
    required String contentType,
  }) async {
    final res = await _dioFactory(_idToken).post(
      '/v1/events/$eventId/photos/presign',
      data: {
        'photoId': photoId,
        'contentType': contentType,
      },
      options: Options(
        extra: {
          'secure': [
            {
              'type': 'http',
              'scheme': 'bearer',
              'name': 'bearerAuth',
            }
          ],
        },
      ),
    );

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid presign response');
    }

    final putUrl = data['putUrl'];
    final s3KeyOriginal = data['s3KeyOriginal'];
    if (putUrl is! String || putUrl.isEmpty) {
      throw StateError('Missing putUrl');
    }
    if (s3KeyOriginal is! String || s3KeyOriginal.isEmpty) {
      throw StateError('Missing s3KeyOriginal');
    }

    return PresignPutResponse(
      photoId: (data['photoId'] as String?) ?? photoId,
      putUrl: putUrl,
      s3KeyOriginal: s3KeyOriginal,
      expiresAt: data['expiresAt'] as String?,
    );
  }

  Future<void> uploadToPresignedUrl({
    required String putUrl,
    required File file,
    required String contentType,
  }) async {
    final bytes = await file.readAsBytes();

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

  Future<void> complete({
    required String eventId,
    required String photoId,
    required String s3KeyOriginal,
    required String createdAt,
  }) async {
    await _dioFactory(_idToken).post(
      '/v1/events/$eventId/photos/complete',
      data: {
        'photoId': photoId,
        's3KeyOriginal': s3KeyOriginal,
        'createdAt': createdAt,
      },
      options: Options(
        extra: {
          'secure': [
            {
              'type': 'http',
              'scheme': 'bearer',
              'name': 'bearerAuth',
            }
          ],
        },
      ),
    );
  }

  Future<ListPhotosPage> list({
    required String eventId,
    int limit = 10,
    String? nextToken,
    String? scope,
  }) async {
    final res = await _dioFactory(_idToken).get(
      '/v1/events/$eventId/photos',
      queryParameters: {
        'limit': limit,
        if (nextToken != null && nextToken.isNotEmpty) 'nextToken': nextToken,
        if (scope != null && scope.isNotEmpty) 'scope': scope,
      },
      options: Options(
        extra: {
          'secure': [
            {
              'type': 'http',
              'scheme': 'bearer',
              'name': 'bearerAuth',
            }
          ],
        },
      ),
    );

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid list photos response');
    }

    final itemsRaw = data['items'];
    final items = <EventPhoto>[];
    if (itemsRaw is List) {
      for (final row in itemsRaw) {
        if (row is Map<String, dynamic>) {
          items.add(_mapPhoto(row));
        }
      }
    }

    final nt = data['nextToken'];
    return ListPhotosPage(
      items: items,
      nextToken: nt is String && nt.isNotEmpty ? nt : null,
    );
  }

  static EventPhoto _mapPhoto(Map<String, dynamic> row) {
    DateTime? parseDate(dynamic v) {
      if (v is! String || v.isEmpty) return null;
      try {
        return DateTime.parse(v).toUtc();
      } catch (_) {
        return null;
      }
    }

    final photoId = (row['photoId'] as String?) ?? '';
    if (photoId.isEmpty) {
      throw StateError('Missing photoId');
    }

    return EventPhoto(
      photoId: photoId,
      guestId: (row['guestId'] as String?) ?? '',
      createdAt: parseDate(row['createdAt']),
      uploadedAt: parseDate(row['uploadedAt']),
      status: (row['status'] as String?) ?? '',
      originalUrl: row['originalUrl'] as String?,
      mediumUrl: row['mediumUrl'] as String?,
      smallUrl: row['smallUrl'] as String?,
    );
  }
}

class PresignPutResponse {
  final String photoId;
  final String putUrl;
  final String s3KeyOriginal;
  final String? expiresAt;

  const PresignPutResponse({
    required this.photoId,
    required this.putUrl,
    required this.s3KeyOriginal,
    required this.expiresAt,
  });
}
