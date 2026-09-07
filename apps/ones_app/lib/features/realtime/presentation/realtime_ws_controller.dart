import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
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

  RealtimeWsController({required this.wsUrl, required this.apiFactory}) {
    // ignore: avoid_print
    print('realtime_ws: controller constructed with wsUrl=$wsUrl');
  }

  bool get connected => _connected;
  bool get connecting => _connecting;

  void setIdToken(String? token) {
    _idToken = token;
    final masked = (token == null || token.isEmpty)
        ? 'null'
        : '***${token.substring(token.length - (token.length >= 5 ? 5 : token.length))}';
    print('realtime_ws: setIdToken token=${masked}');
    // Proactively attempt connect/disconnect upon token change
    if (token != null && token.isNotEmpty) {
      // don't await to avoid blocking caller
      // ignore: discarded_futures
      connect();
    } else {
      // ignore: discarded_futures
      disconnect();
    }
  }

  Future<String?> _fetchSessionToken() async {
    try {
      final dio = apiFactory.create(idToken: _idToken).dio;
      print('realtime_ws: requesting /v1/realtime/session');
      final auth = _idToken;
      if (auth == null || auth.isEmpty) {
        print('realtime_ws: cannot request session, idToken missing');
        return null;
      }
      print('realtime_ws: attaching Authorization header (bearer)');
      final res = await dio.post(
        '/v1/realtime/session',
        options: Options(headers: {'Authorization': 'Bearer $auth'}),
      );
      print('realtime_ws: session response status=${res.statusCode} data=${res.data}');
      final data = res.data;
      if (data is Map) {
        final v = data['token'];
        if (v is String && v.isNotEmpty) {
          print('realtime_ws: obtained session token len=${v.length}');
          return v;
        }
      }
      return null;
    } catch (e) {
      print('realtime_ws: session token fetch error=$e');
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
    print('realtime_ws: connect() called');
    if (_connecting) {
      print('realtime_ws: skipping connect, already connecting');
      return;
    }
    if (_connected) {
      print('realtime_ws: skipping connect, already connected');
      return;
    }
    if (wsUrl.trim().isEmpty) {
      print('realtime_ws: abort connect, wsUrl is empty');
      return;
    }

    final token = _idToken;
    if (token == null || token.isEmpty) {
      print('realtime_ws: abort connect, idToken is null/empty');
      return;
    }

    _connecting = true;
    _safeNotify();

    try {
      print('realtime_ws: fetching session token...');
      final session = await _fetchSessionToken();
      if (session == null || session.isEmpty) {
        print('realtime_ws: failed to obtain session token');
        _scheduleReconnect();
        return;
      }
      final uri = _normalizeWsUri(wsUrl, session);
      print('realtime_ws: connecting to normalized=$uri');
      final ch = WebSocketChannel.connect(uri);
      _channel = ch;

      _sub = ch.stream.listen(
        (msg) {
          // Optional: handle incoming payloads for future UI features
          try {
            final raw = msg is String ? msg : utf8.decode(msg as List<int>);
            print('realtime_ws: message=$raw');
          } catch (_) {}
        },
        onDone: () {
          _connected = false;
          _connecting = false;
          _channel = null;
          _sub = null;
          print('realtime_ws: closed');
          _scheduleReconnect();
          _safeNotify();
        },
        onError: (e) {
          _connected = false;
          _connecting = false;
          _channel = null;
          _sub = null;
          print('realtime_ws: error=$e');
          _scheduleReconnect();
          _safeNotify();
        },
      );

      // Confirm subscription attached (no onListen param in Stream.listen)
      print('realtime_ws: stream subscription attached');

      _connected = true;
      _reconnectAttempts = 0;
      print('realtime_ws: connected');
    } catch (e) {
      _connected = false;
      print('realtime_ws: connect failed: $e');
      _scheduleReconnect();
    } finally {
      _connecting = false;
      _safeNotify();
    }
  }

  Future<void> disconnect() async {
    print('realtime_ws: disconnect() called');
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
      print('realtime_ws: reconnect attempt=$_reconnectAttempts after ${seconds}s');
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
