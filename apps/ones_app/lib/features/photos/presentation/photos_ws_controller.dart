import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class PhotosWsController extends ChangeNotifier {
  final String wsUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  bool _connected = false;
  bool _connecting = false;

  String? _idToken;

  /// All currently subscribed event IDs (active on the WS server).
  final Set<String> _subscribedEventIds = {};

  /// TTL-based retention: eventId → keep subscription until this DateTime.
  final Map<String, DateTime> _retainedUntil = {};

  /// Listeners for photo.ready messages, keyed by caller ID.
  final Map<String, void Function(String eventId, String photoId)>
      _photoReadyListeners = {};

  /// Listeners for photo.uploaded messages, keyed by caller ID.
  final Map<String,
          void Function(String eventId, String uploaderName, int photoCount,
              String eventTitle)>
      _photoUploadedListeners = {};

  Timer? _retentionTimer;

  bool _notifyScheduled = false;

  PhotosWsController({required this.wsUrl});

  bool get connected => _connected;
  bool get connecting => _connecting;

  // ---------------------------------------------------------------------------
  // Listener registration
  // ---------------------------------------------------------------------------

  void addPhotoReadyListener(
    String key,
    void Function(String eventId, String photoId) callback,
  ) {
    _photoReadyListeners[key] = callback;
  }

  void removePhotoReadyListener(String key) {
    _photoReadyListeners.remove(key);
  }

  void addPhotoUploadedListener(
    String key,
    void Function(String eventId, String uploaderName, int photoCount,
            String eventTitle)
        callback,
  ) {
    _photoUploadedListeners[key] = callback;
  }

  void removePhotoUploadedListener(String key) {
    _photoUploadedListeners.remove(key);
  }

  // ---------------------------------------------------------------------------
  // Retention API
  // ---------------------------------------------------------------------------

  /// Register a TTL for the subscription without triggering an unsubscribe.
  /// When [until] expires the periodic cleanup will unsubscribe from the WS.
  void retainSubscription(String eventId, {required DateTime until}) {
    if (eventId.isEmpty) return;
    _retainedUntil[eventId] = until;
    _ensureRetentionTimer();
  }

  void _ensureRetentionTimer() {
    _retentionTimer ??= Timer.periodic(const Duration(minutes: 5), (_) {
      _pruneExpiredSubscriptions();
    });
  }

  void _pruneExpiredSubscriptions() {
    final now = DateTime.now();
    final expired = _retainedUntil.entries
        .where((e) => now.isAfter(e.value))
        .map((e) => e.key)
        .toList();
    for (final eventId in expired) {
      _retainedUntil.remove(eventId);
      _doUnsubscribe(eventId);
    }
  }

  // ---------------------------------------------------------------------------
  // Token
  // ---------------------------------------------------------------------------

  void setIdToken(String? token) {
    _idToken = token;
  }

  void _safeNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  Future<void> connect() async {
    if (_connecting || _connected) return;

    if (wsUrl.trim().isEmpty) return;

    final token = _idToken;
    if (token == null || token.isEmpty) return;

    _connecting = true;
    _safeNotify();

    try {
      final uri = Uri.parse(wsUrl).replace(queryParameters: {'token': token});
      final ch = WebSocketChannel.connect(uri);
      _channel = ch;

      _sub = ch.stream.listen(
        (msg) {
          try {
            final raw = msg is String ? msg : utf8.decode(msg as List<int>);
            final data = jsonDecode(raw);
            if (data is! Map) return;
            final type = data['type'];
            if (type == 'photo.ready') {
              final eventId = data['eventId'];
              final photoId = data['photoId'];
              if (eventId is String && photoId is String) {
                for (final cb in _photoReadyListeners.values.toList()) {
                  cb(eventId, photoId);
                }
              }
            } else if (type == 'photo.uploaded') {
              final eventId = data['eventId'];
              final uploaderName = data['uploaderName'];
              final photoCount = data['photoCount'];
              final eventTitle = data['eventTitle'];
              if (eventId is String &&
                  uploaderName is String &&
                  photoCount is int &&
                  eventTitle is String) {
                for (final cb in _photoUploadedListeners.values.toList()) {
                  cb(eventId, uploaderName, photoCount, eventTitle);
                }
              }
            }
          } catch (_) {
            return;
          }
        },
        onDone: () {
          _connected = false;
          _connecting = false;
          _channel = null;
          _sub = null;
          // Keep _subscribedEventIds so reconnect can re-subscribe.
          _safeNotify();
        },
        onError: (_) {
          _connected = false;
          _connecting = false;
          _channel = null;
          _sub = null;
          // Keep _subscribedEventIds so reconnect can re-subscribe.
          _safeNotify();
        },
      );

      _connected = true;
    } finally {
      _connecting = false;
      _safeNotify();
    }

    // Re-subscribe to all known event IDs after reconnect.
    final toResub = <String>{
      ..._subscribedEventIds,
      ..._retainedUntil.keys,
    };
    for (final eventId in toResub) {
      _sendSubscribe(eventId);
    }
  }

  // ---------------------------------------------------------------------------
  // Subscribe / Unsubscribe
  // ---------------------------------------------------------------------------

  void subscribe({required String eventId}) {
    if (eventId.isEmpty) return;
    _subscribedEventIds.add(eventId);
    _sendSubscribe(eventId);
  }

  void _sendSubscribe(String eventId) {
    final ch = _channel;
    if (ch == null) return;
    final token = _idToken;
    if (token == null || token.isEmpty) return;
    ch.sink.add(
      jsonEncode({
        'action': 'subscribe',
        'eventId': eventId,
        'token': token,
      }),
    );
  }

  /// Hard unsubscribe — removes from server and internal sets.
  void _doUnsubscribe(String eventId) {
    _subscribedEventIds.remove(eventId);
    _retainedUntil.remove(eventId);
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode({'action': 'unsubscribe', 'eventId': eventId}));
  }

  /// Explicit unsubscribe (e.g. when changing event in didUpdateWidget).
  /// Also clears any retained TTL for that event.
  void unsubscribe({required String eventId}) {
    _doUnsubscribe(eventId);
  }

  // ---------------------------------------------------------------------------
  // Disconnect / Dispose
  // ---------------------------------------------------------------------------

  Future<void> disconnect() async {
    _retentionTimer?.cancel();
    _retentionTimer = null;
    _subscribedEventIds.clear();
    _retainedUntil.clear();
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _connected = false;
    _connecting = false;
    _safeNotify();
  }

  @override
  void dispose() {
    unawaited(disconnect());
    super.dispose();
  }
}
