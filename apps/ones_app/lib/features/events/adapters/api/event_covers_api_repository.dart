import 'package:ones_api_client/ones_api_client.dart' as api;

import '../../../../core/http/ones_api_factory.dart';

class EventCoversApiRepository {
  final api.DefaultApi Function(String? idToken) _defaultApi;

  String? _idToken;

  Map<String, String>? _authHeaders() {
    final token = _idToken;
    if (token == null || token.isEmpty) return null;
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  EventCoversApiRepository(OnesApiFactory apiFactory)
      : _defaultApi =
            ((idToken) => apiFactory.create(idToken: idToken).getDefaultApi());

  EventCoversApiRepository.forTesting(
      api.DefaultApi Function(String? idToken) defaultApiFactory)
      : _defaultApi = defaultApiFactory;

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<api.GenerateEventCoverResponse> generate({
    required String eventName,
    required String objective,
    required String location,
    String? size,
  }) async {
    final req = api.GenerateEventCoverRequest((b) => b
      ..eventName = eventName
      ..objective = objective
      ..location = location
      ..size = size);

    final res = await _defaultApi(_idToken).generateEventCover(
      generateEventCoverRequest: req,
      headers: _authHeaders(),
    );

    final data = res.data;
    if (data == null) {
      throw StateError('Missing generateEventCover response');
    }
    return data;
  }

  Future<String> accept(String coverId) async {
    final res = await _defaultApi(_idToken).acceptEventCover(
      coverId: coverId,
      headers: _authHeaders(),
    );
    final data = res.data;
    if (data == null) {
      throw StateError('Missing acceptEventCover response');
    }
    return data.reservationId;
  }

  Future<void> cancel(String coverId) async {
    await _defaultApi(_idToken).cancelEventCover(
      coverId: coverId,
      headers: _authHeaders(),
    );
  }

  Future<api.PresignEventCoverUploadResponse> presignUpload({
    required String eventId,
    required String contentType,
  }) async {
    final req = api.PresignEventCoverUploadRequest((b) => b..contentType = contentType);
    final res = await _defaultApi(_idToken).presignEventCoverUpload(
      id: eventId,
      presignEventCoverUploadRequest: req,
      headers: _authHeaders(),
    );
    final data = res.data;
    if (data == null) {
      throw StateError('Missing presignEventCoverUpload response');
    }
    return data;
  }

  Future<api.PresignedUrlResponse> setFromUpload({
    required String eventId,
    required String uploadKey,
  }) async {
    final req = api.SetEventCoverRequest((b) => b
      ..source = 'upload'
      ..uploadKey = uploadKey);
    final res = await _defaultApi(_idToken).setEventCover(
      id: eventId,
      setEventCoverRequest: req,
      headers: _authHeaders(),
    );
    final data = res.data;
    if (data == null) {
      throw StateError('Missing setEventCover(upload) response');
    }
    return data;
  }

  Future<api.PresignedUrlResponse> setFromPhoto({
    required String eventId,
    required String photoId,
  }) async {
    final req = api.SetEventCoverRequest((b) => b
      ..source = 'photo'
      ..photoId = photoId);
    final res = await _defaultApi(_idToken).setEventCover(
      id: eventId,
      setEventCoverRequest: req,
      headers: _authHeaders(),
    );
    final data = res.data;
    if (data == null) {
      throw StateError('Missing setEventCover(photo) response');
    }
    return data;
  }
}
