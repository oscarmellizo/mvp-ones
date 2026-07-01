import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../adapters/api/event_photos_api.dart';
import '../adapters/local/photo_storage.dart';
import '../adapters/local/photo_upload_db.dart';
import '../domain/photo_upload_item.dart';

class PhotosUploadController extends ChangeNotifier {
  final EventPhotosApi api;
  final PhotoUploadDb db;
  final PhotoStorage storage;

  String? _idToken;
  bool _running = false;
  Object? _lastError;

  int _tokenEpoch = 0;
  bool _triggerAgain = false;

  final Map<String, List<PhotoUploadItem>> _activeByEvent = {};

  final Map<String, double> _uploadProgressByPhotoId = {};

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  PhotosUploadController({
    required this.api,
    required this.db,
    required this.storage,
  }) {
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((_) => trigger());
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
    if (eventId.isEmpty || photoId.isEmpty) return;
    await db.deleteByPhotoId(photoId);
    _uploadProgressByPhotoId.remove(photoId);
    await _refreshActiveForEvent(eventId);
    notifyListeners();
  }

  Future<void> rehydrateActive() async {
    await db.purgeStale();
    final items = await db.listActive();
    final next = <String, List<PhotoUploadItem>>{};
    for (final it in items) {
      if (it.eventId.isEmpty) continue;
      (next[it.eventId] ??= <PhotoUploadItem>[]).add(it);
    }
    _activeByEvent
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  void setIdToken(String? token) {
    if (_idToken == token) {
      api.setIdToken(token);
      return;
    }

    _tokenEpoch++;

    _idToken = token;
    api.setIdToken(token);

    _lastError = null;

    final hasToken = token != null && token.isNotEmpty;
    if (!hasToken) {
      _activeByEvent.clear();
      unawaited(db.clearAll());
      _triggerAgain = false;
      notifyListeners();
      return;
    }

    unawaited(rehydrateActive());
    _triggerAgain = true;
    notifyListeners();
    unawaited(trigger());
  }

  Future<void> enqueueCapturedJpeg({
    required String eventId,
    required String photoId,
    required File capturedFile,
    required DateTime createdAt,
    String? frameId,
    String? orientation,
    String? cameraType,
  }) async {
    final created = createdAt.toUtc().toIso8601String();
    final saved = await storage.saveJpeg(
      eventId: eventId,
      photoId: photoId,
      source: capturedFile,
    );

    await db.enqueue(
      eventId: eventId,
      photoId: photoId,
      localPath: saved.path,
      contentType: 'image/jpeg',
      createdAt: created,
      frameId: frameId,
      orientation: orientation,
      cameraType: cameraType,
    );

    await _refreshActiveForEvent(eventId);
    notifyListeners();

    unawaited(trigger());
  }

  Future<void> _refreshActiveForEvent(String eventId) async {
    if (eventId.isEmpty) return;
    final items = await db.listActiveByEvent(eventId: eventId);
    _activeByEvent[eventId] = items;
  }

  Future<void> trigger() async {
    if (_running) return;

    final epoch = _tokenEpoch;
    final token = _idToken;
    if (token == null || token.isEmpty) return;

    _running = true;
    _triggerAgain = false;
    notifyListeners();

    try {
      _lastError = null;

      while (true) {
        if (epoch != _tokenEpoch) {
          break;
        }

        final currentToken = _idToken;
        if (currentToken == null || currentToken.isEmpty) {
          break;
        }

        final connectivity = await Connectivity().checkConnectivity();
        if (connectivity.contains(ConnectivityResult.none)) {
          break;
        }

        final next = await db.listPending(limit: 1);
        if (next.isEmpty) break;

        final item = next.first;

        try {
          await db.markUploading(item.id);
          await _refreshActiveForEvent(item.eventId);
          notifyListeners();

          final presign = await api.presignPut(
            eventId: item.eventId,
            photoId: item.photoId,
            contentType: item.contentType,
          );

          await db.markPresigned(item.id, s3KeyOriginal: presign.s3KeyOriginal);
          await _refreshActiveForEvent(item.eventId);
          notifyListeners();

          final file = File(item.localPath);
          await api.uploadToPresignedUrl(
            putUrl: presign.putUrl,
            file: file,
            contentType: item.contentType,
            onProgress: (sent, total) {
              if (total <= 0) return;
              final p = sent / total;
              final clamped = p < 0 ? 0.0 : (p > 1 ? 1.0 : p);
              _uploadProgressByPhotoId[item.photoId] = clamped;
              notifyListeners();
            },
          );

          await api.complete(
            eventId: item.eventId,
            photoId: item.photoId,
            s3KeyOriginal: presign.s3KeyOriginal,
            createdAt: item.createdAt,
          );

          await db.markProcessing(item.id);
          await _refreshActiveForEvent(item.eventId);
          notifyListeners();
        } catch (e) {
          await db.markFailed(item.id, error: e.toString());
          _lastError = e;

          await _refreshActiveForEvent(item.eventId);
          notifyListeners();

          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    } finally {
      _running = false;
      notifyListeners();

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
