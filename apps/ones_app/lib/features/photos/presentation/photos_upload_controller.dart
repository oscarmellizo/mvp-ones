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

  final Map<String, List<PhotoUploadItem>> _activeByEvent = {};

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

  void setIdToken(String? token) {
    if (_idToken == token) {
      api.setIdToken(token);
      return;
    }

    _idToken = token;
    api.setIdToken(token);

    _running = false;
    _lastError = null;
    _activeByEvent.clear();
    notifyListeners();
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

    final token = _idToken;
    if (token == null || token.isEmpty) return;

    _running = true;
    notifyListeners();

    try {
      _lastError = null;

      while (true) {
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
          );

          await api.complete(
            eventId: item.eventId,
            photoId: item.photoId,
            s3KeyOriginal: presign.s3KeyOriginal,
            createdAt: item.createdAt,
          );

          await db.markUploaded(item.id);
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
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
