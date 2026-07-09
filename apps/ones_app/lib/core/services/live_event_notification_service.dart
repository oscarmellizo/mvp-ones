import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/events/domain/event.dart';

const int _kLiveNotifId = 42;
const int _kPhotoUploadNotifId = 43;
const String _kChannelId = 'live_event_channel';
const String _kChannelName = 'Evento en vivo';
const String _kChannelDesc = 'Notificación activa mientras un evento está en curso';
const String _kPhotoUploadChannelId = 'photo_upload_channel';
const String _kPhotoUploadChannelName = 'Fotos subidas';
const String _kPhotoUploadChannelDesc = 'Notificación cuando alguien sube fotos a un evento';
const String _kEventsKey = 'live_notif_cached_events';

const String kActionGallery = 'ACTION_GALLERY';
const String kActionCamera = 'ACTION_CAMERA';
const String kActionSelect = 'ACTION_SELECT';

class LiveEventNotificationService {
  static final LiveEventNotificationService _instance =
      LiveEventNotificationService._internal();
  factory LiveEventNotificationService() => _instance;
  LiveEventNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _createAndroidChannel();
    await _createPhotoUploadAndroidChannel();
    _initialized = true;
  }

  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDesc,
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _createPhotoUploadAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      _kPhotoUploadChannelId,
      _kPhotoUploadChannelName,
      description: _kPhotoUploadChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> showPhotoUploadedNotification({
    required String eventId,
    required String eventTitle,
    required String uploaderName,
    required int photoCount,
  }) async {
    if (!_initialized) return;
    final payload = jsonEncode({'eventId': eventId, 'action': kActionGallery});

    final androidDetails = AndroidNotificationDetails(
      _kPhotoUploadChannelId,
      _kPhotoUploadChannelName,
      channelDescription: _kPhotoUploadChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
    );

    final body = photoCount == 1
        ? '$uploaderName subió 1 foto al evento $eventTitle'
        : '$uploaderName subió $photoCount fotos al evento $eventTitle';

    await _plugin.show(
      _kPhotoUploadNotifId,
      '📷 Nueva foto',
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true) ?? false;
    }
    return false;
  }

  void _onNotificationResponse(NotificationResponse response) {
    _handlePayload(response.payload, response.actionId);
  }

  static void _handlePayload(String? payload, String? actionId) {
    if (payload == null || payload.isEmpty) return;
    _pendingPayload = payload;
    _pendingActionId = actionId;
  }

  static String? _pendingPayload;
  static String? _pendingActionId;

  static ({String? payload, String? actionId})? consumePending() {
    if (_pendingPayload == null) return null;
    final result = (payload: _pendingPayload, actionId: _pendingActionId);
    _pendingPayload = null;
    _pendingActionId = null;
    return result;
  }

  Future<void> checkAndUpdate(List<Event> events) async {
    final now = DateTime.now();
    final liveEvents = events.where((e) {
      final start = e.startAt.toLocal();
      final end = e.endAt.toLocal();
      return (now.isAfter(start) || now.isAtSameMomentAs(start)) &&
          now.isBefore(end);
    }).toList(growable: false);

    if (liveEvents.isEmpty) {
      await cancel();
      return;
    }

    if (liveEvents.length == 1) {
      await _showSingleEventNotification(liveEvents.first);
    } else {
      await _showMultiEventNotification(liveEvents);
    }
  }

  Future<void> _showSingleEventNotification(Event event) async {
    final payload = jsonEncode({'eventId': event.id});

    final androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: _kChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      actions: [
        const AndroidNotificationAction(
          kActionGallery,
          'Ver galería',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          kActionCamera,
          'Tomar foto',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: false,
      presentBadge: false,
      categoryIdentifier: 'LIVE_EVENT',
    );

    await _plugin.show(
      _kLiveNotifId,
      '📸 ${event.title}',
      'Evento en vivo · ${_formatTime(event.startAt)} – ${_formatTime(event.endAt)}',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<void> _showMultiEventNotification(List<Event> events) async {
    final payload = jsonEncode({'multi': true});

    final androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: _kChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      actions: [
        const AndroidNotificationAction(
          kActionSelect,
          'Ver eventos en vivo',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: false,
      presentBadge: false,
      categoryIdentifier: 'LIVE_EVENT',
    );

    final titles = events.map((e) => e.title).take(2).join(', ');

    await _plugin.show(
      _kLiveNotifId,
      '📸 ${events.length} eventos en vivo',
      titles,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<void> cancel() async {
    await _plugin.cancel(_kLiveNotifId);
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static Future<void> cacheEvents(List<Event> events) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(events
        .map((e) => {
              'id': e.id,
              'title': e.title,
              'startAt': e.startAt.toIso8601String(),
              'endAt': e.endAt.toIso8601String(),
              'ownerId': e.ownerId,
              'createdAt': e.createdAt.toIso8601String(),
              'objective': e.objective,
              'location': e.location,
              'allowGuestInvites': e.allowGuestInvites,
              'inviteLinkEnabled': e.inviteLinkEnabled,
            })
        .toList());
    await prefs.setString(_kEventsKey, encoded);
  }

  static Future<List<Event>> loadCachedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kEventsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((m) {
        final map = m as Map<String, dynamic>;
        return Event(
          id: map['id'] as String,
          ownerId: map['ownerId'] as String,
          createdAt: DateTime.parse(map['createdAt'] as String),
          title: map['title'] as String,
          objective: map['objective'] as String,
          location: map['location'] as String,
          startAt: DateTime.parse(map['startAt'] as String),
          endAt: DateTime.parse(map['endAt'] as String),
          coverKey: null,
          allowGuestInvites: map['allowGuestInvites'] as bool? ?? false,
          inviteLinkEnabled: map['inviteLinkEnabled'] as bool? ?? true,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  LiveEventNotificationService._handlePayload(
      response.payload, response.actionId);
}
