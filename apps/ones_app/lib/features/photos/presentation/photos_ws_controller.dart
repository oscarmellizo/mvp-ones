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
  String? _subscribedEventId;

  bool _notifyScheduled = false;

  void Function(String eventId, String photoId)? onPhotoReady;

  PhotosWsController({required this.wsUrl});

  bool get connected => _connected;
  bool get connecting => _connecting;

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
            if (data['type'] == 'photo.ready') {
              final eventId = data['eventId'];
              final photoId = data['photoId'];
              if (eventId is String && photoId is String) {
                onPhotoReady?.call(eventId, photoId);
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
          _safeNotify();
        },
        onError: (_) {
          _connected = false;
          _connecting = false;
          _channel = null;
          _sub = null;
          _safeNotify();
        },
      );

      _connected = true;
    } finally {
      _connecting = false;
      _safeNotify();
    }

    final eventId = _subscribedEventId;
    if (eventId != null && eventId.isNotEmpty) {
      subscribe(eventId: eventId);
    }
  }

  void subscribe({required String eventId}) {
    _subscribedEventId = eventId;
    final ch = _channel;
    if (ch == null) return;

    final token = _idToken;
    if (token == null || token.isEmpty) return;

    ch.sink.add(
      jsonEncode(
        {
          'action': 'subscribe',
          'eventId': eventId,
          'token': token,
        },
      ),
    );
  }

  void unsubscribe({required String eventId}) {
    if (_subscribedEventId == eventId) {
      _subscribedEventId = null;
    }
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode({'action': 'unsubscribe', 'eventId': eventId}));
  }

  Future<void> disconnect() async {
    _subscribedEventId = null;
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
