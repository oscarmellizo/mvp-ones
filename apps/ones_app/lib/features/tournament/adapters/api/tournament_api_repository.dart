import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';

class TournamentApiRepository {
  final OnesApiFactory _apiFactory;
  String? _idToken;

  TournamentApiRepository(this._apiFactory);

  void setIdToken(String? token) => _idToken = token;

  Future<Map<String, dynamic>> get(String eventId) async {
    final response = await _secureDio().get('/v1/events/$eventId/tournament');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> saveSetup(
    String eventId,
    List<Map<String, dynamic>> teams,
  ) async {
    final response = await _secureDio().put(
      '/v1/events/$eventId/tournament/setup',
      data: {'teams': teams},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> startPredictions(String eventId) async {
    final response = await _secureDio()
        .post('/v1/events/$eventId/tournament/predictions/start');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> closePredictions(String eventId) async {
    final response = await _secureDio()
        .post('/v1/events/$eventId/tournament/predictions/close');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<bool> recalculateScores(String eventId) async {
    final response = await _secureDio()
        .post('/v1/events/$eventId/tournament/scores/recalculate');
    return response.data is Map && response.data['status'] == 'queued';
  }

  Future<void> savePredictions(
    String eventId, {
    required Map<String, dynamic> roundRobinScores,
    Map<String, dynamic>? finalScore,
    Map<String, dynamic>? thirdPlaceScore,
  }) async {
    await _secureDio().put(
      '/v1/events/$eventId/tournament/predictions',
      data: {
        'roundRobinScores': roundRobinScores,
        'finalScore': finalScore,
        'thirdPlaceScore': thirdPlaceScore,
      },
    );
  }

  Future<void> startMatch(String eventId, String matchId) async {
    await _secureDio()
        .post('/v1/events/$eventId/tournament/matches/$matchId/start');
  }

  Future<void> finishMatch(
    String eventId,
    String matchId, {
    required int homeGoals,
    required int awayGoals,
    String? penaltyWinnerTeamId,
    bool confirmKnockoutReset = false,
  }) async {
    await _secureDio().put(
      '/v1/events/$eventId/tournament/matches/$matchId/result',
      data: {
        'homeGoals': homeGoals,
        'awayGoals': awayGoals,
        if (penaltyWinnerTeamId != null)
          'penaltyWinnerTeamId': penaltyWinnerTeamId,
        'confirmKnockoutReset': confirmKnockoutReset,
      },
    );
  }

  Future<List<Map<String, dynamic>>> acceptedMembers(String eventId) async {
    final members = await eventMembers(eventId);
    return members
        .where((item) => item['status'] == 'accepted')
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> eventMembers(String eventId) async {
    final response = await _secureDio().get('/v1/events/$eventId/guests/v2');
    return (response.data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> setDelegates(
    String eventId,
    List<String> userIds,
  ) async {
    final response = await _secureDio().put(
      '/v1/events/$eventId/tournament/delegates',
      data: {'userIds': userIds},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> setTieBreakOrder(
    String eventId, {
    required List<String> teamIds,
    required String reason,
  }) async {
    await _secureDio().put(
      '/v1/events/$eventId/tournament/standings/tie-break',
      data: {'teamIds': teamIds, 'reason': reason},
    );
  }

  Future<List<Map<String, dynamic>>> revealedPredictions(String eventId) async {
    final response = await _secureDio().get(
      '/v1/events/$eventId/tournament/predictions/revealed',
      queryParameters: const {'limit': 100},
    );
    return (response.data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Dio _secureDio() {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    dio.options.extra['secure'] = const [
      {
        'type': 'http',
        'scheme': 'bearer',
        'name': 'bearerAuth',
      }
    ];
    return dio;
  }
}
