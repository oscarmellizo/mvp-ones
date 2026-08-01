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
      final uri = _normalizeWsUri(wsUrl, token);
      if (kDebugMode) {
        debugPrint('photos_ws: connect url=$wsUrl normalized=$uri');
        if ((uri.pathSegments.isEmpty ||
            (uri.pathSegments.length == 1 && uri.pathSegments.first.trim().isEmpty))) {
          debugPrint('photos_ws: hint: missing stage (e.g., /dev or /prod) in ONES_PHOTOS_WS_URL');
        }
      }
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
          if (kDebugMode) {
            debugPrint('photos_ws: closed by server');
          }
          _scheduleReconnect();
          _safeNotify();
        },
        onError: (e) {
          _connected = false;
          _connecting = false;
          _channel = null;
          _sub = null;
          if (kDebugMode) {
            debugPrint('photos_ws: error=$e');
          }
          _scheduleReconnect();
          _safeNotify();
        },
      );

      _connected = true;
      _reconnectAttempts = 0;
    } catch (e) {
      _connected = false;
      if (kDebugMode) {
        debugPrint('photos_ws: connect failed: $e');
      }
      _scheduleReconnect();
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
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
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

  // Reconnect logic with backoff
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  void _scheduleReconnect() {
    if (wsUrl.trim().isEmpty) return;
    final token = _idToken;
    if (token == null || token.isEmpty) return;
    if (_connecting || _connected) return;

    _reconnectAttempts = (_reconnectAttempts + 1).clamp(1, 10);
    final delays = <int>[1, 2, 5, 10, 15, 20, 30, 30, 30, 30];
    final seconds = delays[_reconnectAttempts - 1];
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (kDebugMode) {
        debugPrint('photos_ws: reconnect attempt=$_reconnectAttempts');
      }
      connect();
    });
  }

  Uri _normalizeWsUri(String raw, String token) {
    Uri base;
    try {
      base = Uri.parse(raw);
    } catch (_) {
      return Uri.parse(raw);
    }

    // Fix scheme to wss if http/https provided
    final scheme = (base.scheme.isEmpty || base.scheme == 'http' || base.scheme == 'https')
        ? 'wss'
        : base.scheme;

    // Drop invalid :0 port
    final port = (base.hasPort && base.port == 0) ? null : (base.hasPort ? base.port : null);

    return base.replace(
      scheme: scheme,
      port: port,
      queryParameters: {'token': token},
    );
  }
}
