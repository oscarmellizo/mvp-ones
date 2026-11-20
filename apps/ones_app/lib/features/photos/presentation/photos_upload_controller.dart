import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../adapters/api/event_photos_api.dart';
import '../adapters/local/photo_storage.dart';
import '../adapters/local/photo_upload_db.dart';
import '../domain/photo_upload_item.dart';

class PhotosUploadController extends ChangeNotifier {
  final EventPhotosApi api;
  final PhotoUploadDb db;
  final PhotoStorage storage;
  final bool useLocalQueue;

  String? _idToken;
  String? _currentOwnerId;
  bool _running = false;
  Object? _lastError;

  int _tokenEpoch = 0;
  bool _triggerAgain = false;

  final Map<String, List<PhotoUploadItem>> _activeByEvent = {};

  final Map<String, double> _uploadProgressByPhotoId = {};

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool _notifyScheduled = false;

  PhotosUploadController({
    required this.api,
    required this.db,
    required this.storage,
    bool? useLocalQueue,
  }) : useLocalQueue = useLocalQueue ?? !kIsWeb {
    if (this.useLocalQueue) {
      _connectivitySub =
          Connectivity().onConnectivityChanged.listen((_) => trigger());
    }
  }

  void _safeNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  bool get running => _running;
  Object? get lastError => _lastError;

  List<PhotoUploadItem> activeByEvent(String eventId) {
    if (eventId.isEmpty) return const [];
    return _activeByEvent[eventId] ?? const [];
  }

  double? uploadProgressByPhotoId(String photoId) {
    if (photoId.isEmpty) return null;
    return _uploadProgressByPhotoId[photoId];
  }

  Future<void> markDoneByPhotoId({
    required String eventId,
    required String photoId,
  }) async {
    final ownerId = _currentOwnerId;
    if (!useLocalQueue ||
        ownerId == null ||
        eventId.isEmpty ||
        photoId.isEmpty) {
      return;
    }
    try {
      final file = await storage.getFile(eventId: eventId, photoId: photoId);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // ignore
    }
    await db.deleteByPhotoId(photoId, ownerId: ownerId);
    _uploadProgressByPhotoId.remove(photoId);
    await _refreshActiveForEvent(eventId);
    _safeNotify();
  }

  Future<void> retryFailedByPhotoId({
    required String eventId,
    required String photoId,
  }) async {
    final ownerId = _currentOwnerId;
    if (!useLocalQueue ||
        ownerId == null ||
        eventId.isEmpty ||
        photoId.isEmpty) {
      return;
    }
    await db.retryFailedByPhotoId(photoId, ownerId: ownerId);
    await _refreshActiveForEvent(eventId);
    _safeNotify();
    unawaited(trigger());
  }

  Future<void> rehydrateActive() async {
    final ownerId = _currentOwnerId;
    if (!useLocalQueue || ownerId == null) return;
    await db.purgeStale(olderThan: const Duration(minutes: 10));
    await db.bindLegacyItems(ownerId: ownerId);
    final items = await db.listActive(ownerId: ownerId);
    if (ownerId != _currentOwnerId) return;
    final next = <String, List<PhotoUploadItem>>{};
    for (final it in items) {
      if (it.eventId.isEmpty) continue;
      (next[it.eventId] ??= <PhotoUploadItem>[]).add(it);
    }
    _activeByEvent
      ..clear()
      ..addAll(next);
    _safeNotify();
  }

  void setIdToken(String? token) {
    if (_idToken == token) {
      api.setIdToken(token);
      return;
    }

    _tokenEpoch++;

    _idToken = token;
    _currentOwnerId = _ownerIdFromIdToken(token);
    api.setIdToken(token);

    _lastError = null;
    if (!useLocalQueue) {
      _activeByEvent.clear();
      _safeNotify();
      return;
    }

    final hasToken = token != null && token.isNotEmpty;
    if (!hasToken || _currentOwnerId == null) {
      _activeByEvent.clear();
      _triggerAgain = false;
      _safeNotify();
      return;
    }

    final tokenEpoch = _tokenEpoch;
    _safeNotify();
    unawaited(_rehydrateThenTrigger(tokenEpoch));
  }

  Future<void> _rehydrateThenTrigger(int tokenEpoch) async {
    await rehydrateActive();
    if (tokenEpoch == _tokenEpoch && _currentOwnerId != null) {
      unawaited(trigger());
    }
  }

  static String? _ownerIdFromIdToken(String? token) {
    if (token == null || token.isEmpty) return null;
    final segments = token.split('.');
    if (segments.length < 2) return null;
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      if (decoded is! Map<String, dynamic>) return null;
      final ownerId = decoded['user_id'] ?? decoded['sub'];
      return ownerId is String && ownerId.isNotEmpty ? ownerId : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> enqueueCapturedJpeg({
    required String eventId,
    required String photoId,
    required File capturedFile,
    required DateTime createdAt,
    String? originalFilename,
    DateTime? metadataCreatedAt,
    DateTime? filenameCreatedAt,
    String? createdAtSource,
    int? deviceUtcOffsetMinutes,
    String? frameId,
    String? orientation,
    String? cameraType,
  }) async {
    if (!useLocalQueue) {
      throw UnsupportedError('Local uploads are unavailable on web');
    }
    final ownerId = _currentOwnerId;
    if (ownerId == null) {
      throw StateError('Authenticated photo owner is unavailable');
    }
    final created = createdAt.toUtc().toIso8601String();
    final saved = await storage.saveJpeg(
      eventId: eventId,
      photoId: photoId,
      source: capturedFile,
    );

    final exists = await saved.exists();
    if (!exists) {
      throw StateError('Saved photo file not found: ${saved.path}');
    }

    final len = await saved.length();
    if (len <= 0) {
      throw StateError('Saved photo file is empty: ${saved.path}');
    }

    await db.enqueue(
      ownerId: ownerId,
      eventId: eventId,
      photoId: photoId,
      localPath: saved.path,
      contentType: 'image/jpeg',
      createdAt: created,
      originalFilename: originalFilename,
      metadataCreatedAt: metadataCreatedAt?.toUtc().toIso8601String(),
      filenameCreatedAt: filenameCreatedAt?.toUtc().toIso8601String(),
      createdAtSource: createdAtSource,
      deviceUtcOffsetMinutes: deviceUtcOffsetMinutes,
      frameId: frameId,
      orientation: orientation,
      cameraType: cameraType,
    );

    await _refreshActiveForEvent(eventId);
    _safeNotify();

    unawaited(trigger());
  }

  Future<void> _refreshActiveForEvent(String eventId) async {
    final ownerId = _currentOwnerId;
    if (eventId.isEmpty || ownerId == null) return;
    final items = await db.listActiveByEvent(
      eventId: eventId,
      ownerId: ownerId,
    );
    if (ownerId != _currentOwnerId) return;
    _activeByEvent[eventId] = items;
  }

  Future<void> refreshActiveForEvent({required String eventId}) async {
    final trimmed = eventId.trim();
    if (!useLocalQueue || trimmed.isEmpty) return;
    await _refreshActiveForEvent(trimmed);
    _safeNotify();
  }

  Future<void> trigger() async {
    if (!useLocalQueue) return;
    if (_running) {
      _triggerAgain = true;
      return;
    }

    final epoch = _tokenEpoch;
    final token = _idToken;
    final ownerId = _currentOwnerId;
    if (token == null || token.isEmpty || ownerId == null) return;

    _running = true;
    _triggerAgain = false;
    _safeNotify();

    try {
      await db.purgeStale(olderThan: const Duration(minutes: 10));

      _lastError = null;

      while (true) {
        if (epoch != _tokenEpoch) {
          break;
        }

        final currentToken = _idToken;
        if (currentToken == null || currentToken.isEmpty) {
          break;
        }

        final next = await db.listPending(ownerId: ownerId, limit: 1);
        if (next.isEmpty) break;

        final item = next.first;

        final connectivity = await Connectivity().checkConnectivity();
        if (connectivity.contains(ConnectivityResult.none)) {
          if (kDebugMode) {
            debugPrint(
              'photo_upload: offline eventId=${item.eventId} photoId=${item.photoId}',
            );
          }
          await db.markFailed(item.id, error: 'offline');
          _uploadProgressByPhotoId.remove(item.photoId);
          await _refreshActiveForEvent(item.eventId);
          _safeNotify();
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }

        final local = File(item.localPath);
        final localExists = await local.exists();
        if (!localExists) {
          if (kDebugMode) {
            debugPrint(
              'photo_upload: local_file_missing eventId=${item.eventId} photoId=${item.photoId}',
            );
          }
          await db.markLocalFileMissing(item.id);
          _uploadProgressByPhotoId.remove(item.photoId);
          await _refreshActiveForEvent(item.eventId);
          _safeNotify();
          continue;
        }

        final localLen = await local.length();
        if (localLen <= 0) {
          if (kDebugMode) {
            debugPrint(
              'photo_upload: local_file_empty eventId=${item.eventId} photoId=${item.photoId}',
            );
          }
          await db.markLocalFileMissing(item.id);
          _uploadProgressByPhotoId.remove(item.photoId);
          await _refreshActiveForEvent(item.eventId);
          _safeNotify();
          continue;
        }

        if (kDebugMode) {
          debugPrint(
            'photo_upload: start eventId=${item.eventId} photoId=${item.photoId} status=${item.status} attempts=${item.attempts}',
          );
        }

        try {
          await db.markUploading(item.id);
          await _refreshActiveForEvent(item.eventId);
          _safeNotify();

          final presign = await api.presignPut(
            eventId: item.eventId,
            photoId: item.photoId,
            contentType: item.contentType,
          );

          if (kDebugMode) {
            debugPrint(
              'photo_upload: presign_ok eventId=${item.eventId} photoId=${item.photoId} s3KeyOriginal=${presign.s3KeyOriginal}',
            );
          }

          await db.markPresigned(item.id, s3KeyOriginal: presign.s3KeyOriginal);
          await _refreshActiveForEvent(item.eventId);
          _safeNotify();

          final file = local;
          if (kDebugMode) {
            debugPrint(
              'photo_upload: put_start eventId=${item.eventId} photoId=${item.photoId} bytes=$localLen',
            );
          }
          await api.uploadToPresignedUrl(
            putUrl: presign.putUrl,
            file: file,
            contentType: item.contentType,
            onProgress: (sent, total) {
              if (total <= 0) return;
              final p = sent / total;
              final clamped = p < 0 ? 0.0 : (p > 1 ? 1.0 : p);
              _uploadProgressByPhotoId[item.photoId] = clamped;
              _safeNotify();
            },
          );

          if (kDebugMode) {
            debugPrint(
              'photo_upload: put_ok eventId=${item.eventId} photoId=${item.photoId}',
            );
          }

          await api.complete(
            eventId: item.eventId,
            photoId: item.photoId,
            s3KeyOriginal: presign.s3KeyOriginal,
            createdAt: item.createdAt,
            originalFilename: item.originalFilename,
            metadataCreatedAt: item.metadataCreatedAt,
            filenameCreatedAt: item.filenameCreatedAt,
            createdAtSource: item.createdAtSource,
            deviceUtcOffsetMinutes: item.deviceUtcOffsetMinutes,
          );

          if (kDebugMode) {
            debugPrint(
              'photo_upload: complete_ok eventId=${item.eventId} photoId=${item.photoId}',
            );
          }

          _uploadProgressByPhotoId[item.photoId] = 1.0;
          await db.markUploaded(item.id);
          await _refreshActiveForEvent(item.eventId);
          _safeNotify();
        } catch (e) {
          final isMissingLocalFile = e is FileSystemException &&
              (() {
                final osError = e.osError;
                if (osError?.errorCode == 2) return true;
                final msg = osError?.message;
                return msg != null &&
                    msg.toLowerCase().contains('no such file');
              })();
          if (isMissingLocalFile) {
            if (kDebugMode) {
              debugPrint(
                'photo_upload: local_file_missing_during_upload eventId=${item.eventId} photoId=${item.photoId}',
              );
            }
            await db.markLocalFileMissing(item.id);
            _uploadProgressByPhotoId.remove(item.photoId);
            await _refreshActiveForEvent(item.eventId);
            _safeNotify();
            continue;
          }
          if (kDebugMode) {
            final extra = e is DioException
                ? ' type=${e.type} status=${e.response?.statusCode} message=${e.message}'
                : '';
            debugPrint(
              'photo_upload: fail eventId=${item.eventId} photoId=${item.photoId} error=$e$extra',
            );
          }
          await db.markFailed(item.id, error: e.toString());
          _uploadProgressByPhotoId.remove(item.photoId);
          _lastError = e;

          await _refreshActiveForEvent(item.eventId);
          _safeNotify();

          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    } finally {
      _running = false;
      _safeNotify();

      if (_triggerAgain) {
        _triggerAgain = false;
        unawaited(trigger());
      }
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
