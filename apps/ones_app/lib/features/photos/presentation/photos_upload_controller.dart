import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../adapters/api/event_photos_api.dart';
import '../adapters/local/photo_storage.dart';
import '../adapters/local/photo_upload_db.dart';

class PhotosUploadController extends ChangeNotifier {
  final EventPhotosApi api;
  final PhotoUploadDb db;
  final PhotoStorage storage;

  String? _idToken;
  bool _running = false;
  Object? _lastError;

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

  void setIdToken(String? token) {
    _idToken = token;
    api.setIdToken(token);
  }

  Future<void> enqueueCapturedJpeg({
    required String eventId,
    required String photoId,
    required File capturedFile,
    required DateTime createdAt,
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
    );

    unawaited(trigger());
  }

  Future<void> trigger() async {
    if (_running) return;

    final token = _idToken;
    if (token == null || token.isEmpty) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    _running = true;
    notifyListeners();

    try {
      _lastError = null;

      while (true) {
        final next = await db.listPending(limit: 1);
        if (next.isEmpty) break;

        final item = next.first;

        try {
          await db.markUploading(item.id);

          final presign = await api.presignPut(
            eventId: item.eventId,
            photoId: item.photoId,
            contentType: item.contentType,
          );

          await db.markPresigned(item.id, s3KeyOriginal: presign.s3KeyOriginal);

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
        } catch (e) {
          await db.markFailed(item.id, error: e.toString());
          _lastError = e;
          break;
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
