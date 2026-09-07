import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/http/ones_api_factory.dart';

class RealtimeWsController extends ChangeNotifier {
  final String wsUrl;
  final OnesApiFactory apiFactory;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  bool _connected = false;
  bool _connecting = false;

  String? _idToken;

  bool _notifyScheduled = false;

  RealtimeWsController({required this.wsUrl, required this.apiFactory});

  bool get connected => _connected;
  bool get connecting => _connecting;

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<String?> _fetchSessionToken() async {
    try {
      final dio = apiFactory.create(idToken: _idToken).dio;
      final res = await dio.post('/v1/realtime/session');
      final data = res.data;
      if (data is Map) {
        final v = data['token'];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('realtime_ws: session token fetch error=$e');
      return null;
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

  Future<void> connect() async {
    if (_connecting || _connected) return;
    if (wsUrl.trim().isEmpty) return;

    final token = _idToken;
    if (token == null || token.isEmpty) return;

    _connecting = true;
    _safeNotify();

    try {
      final session = await _fetchSessionToken();
      if (session == null || session.isEmpty) {
        if (kDebugMode) debugPrint('realtime_ws: failed to obtain session token');
        _scheduleReconnect();
        return;
      }
      final uri = _normalizeWsUri(wsUrl, session);
      if (kDebugMode) {
        debugPrint('realtime_ws: connect url=$wsUrl normalized=$uri');
      }
      final ch = WebSocketChannel.connect(uri);
      _channel = ch;

      _sub = ch.stream.listen(
        (msg) {
          // Optional: handle incoming payloads for future UI features
          try {
            final raw = msg is String ? msg : utf8.decode(msg as List<int>);
            if (kDebugMode) debugPrint('realtime_ws: message=$raw');
          } catch (_) {}
        },
        onDone: () {
          _connected = false;
          _connecting = false;
          _channel = null;
          _sub = null;
          if (kDebugMode) debugPrint('realtime_ws: closed');
          _scheduleReconnect();
          _safeNotify();
        },
        onError: (e) {
          _connected = false;
          _connecting = false;
          _channel = null;
          _sub = null;
          if (kDebugMode) debugPrint('realtime_ws: error=$e');
          _scheduleReconnect();
          _safeNotify();
        },
      );

      _connected = true;
      _reconnectAttempts = 0;
    } catch (e) {
      _connected = false;
      if (kDebugMode) debugPrint('realtime_ws: connect failed: $e');
      _scheduleReconnect();
    } finally {
      _connecting = false;
      _safeNotify();
    }
  }

  Future<void> disconnect() async {
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
      if (kDebugMode) debugPrint('realtime_ws: reconnect attempt=$_reconnectAttempts');
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

    final scheme = (base.scheme.isEmpty || base.scheme == 'http' || base.scheme == 'https')
        ? 'wss'
        : base.scheme;

    final port = (base.hasPort && base.port == 0) ? null : (base.hasPort ? base.port : null);

    final qp = Map<String, String>.from(base.queryParameters);
    qp['sessionToken'] = token;

    return base.replace(
      scheme: scheme,
      port: port,
      queryParameters: qp,
    );
  }
}
