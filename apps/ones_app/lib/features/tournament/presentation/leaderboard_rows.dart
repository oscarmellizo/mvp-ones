class TournamentRankingRow {
  const TournamentRankingRow({
    required this.userId,
    required this.displayName,
    required this.points,
    required this.exactCount,
    required this.fivePointCount,
    required this.hasPrediction,
    this.place,
    this.email,
  });

  final String userId;
  final String displayName;
  final int? place;
  final int points;
  final int exactCount;
  final int fivePointCount;
  final bool hasPrediction;
  final String? email;
}

List<TournamentRankingRow> buildTournamentRankingRows({
  required List<Map<String, dynamic>> leaderboard,
  required List<Map<String, dynamic>> participants,
  required bool participantsLoaded,
  Map<String, dynamic>? myPrediction,
}) {
  final scoresByUser = <String, Map<String, dynamic>>{};
  for (final row in leaderboard) {
    final userId = _text(row['userId']);
    if (userId == null) continue;
    final existing = scoresByUser[userId];
    if (existing == null || _scoreIsBetter(row, existing)) {
      scoresByUser[userId] = row;
    }
  }

  final currentUserId = _text(myPrediction?['userId']);
  if (currentUserId != null && !scoresByUser.containsKey(currentUserId)) {
    scoresByUser[currentUserId] = myPrediction!;
  }

  if (!participantsLoaded || participants.isEmpty) {
    final rows = scoresByUser.entries
        .map((entry) => _scoredRow(entry.key, entry.value))
        .toList();
    rows.sort(_compareRows);
    return rows;
  }

  final groups = <String, List<Map<String, dynamic>>>{};
  final groupByUserId = <String, String>{};
  for (final participant in participants) {
    if (participant['role'] != 'owner' && participant['status'] != 'accepted') {
      continue;
    }
    final userId = _text(participant['userId']);
    if (userId == null) continue;

    final email = _text(participant['email'])?.toLowerCase();
    final identity = email == null ? 'user:$userId' : 'email:$email';
    final existingIdentity = groupByUserId[userId];
    if (existingIdentity != null) {
      groups[existingIdentity]!.add(participant);
      continue;
    }
    groupByUserId[userId] = identity;
    groups.putIfAbsent(identity, () => []).add(participant);
  }

  if (groups.isEmpty) {
    final rows = scoresByUser.entries
        .map((entry) => _scoredRow(entry.key, entry.value))
        .toList();
    rows.sort(_compareRows);
    return rows;
  }

  final rows = <TournamentRankingRow>[];
  for (final group in groups.values) {
    final scored = group
        .map((member) => _text(member['userId']))
        .whereType<String>()
        .map((userId) => MapEntry(userId, scoresByUser[userId]))
        .where((entry) => entry.value != null)
        .toList();
    scored.sort((a, b) => _compareScores(a.value!, b.value!));

    final score = scored.isEmpty ? null : scored.first.value;
    final member = score == null
        ? group.first
        : group.firstWhere(
            (candidate) => _text(candidate['userId']) == _text(score['userId']),
            orElse: () => group.first,
          );
    final userId = _text(score?['userId']) ?? _text(member['userId']);
    if (userId == null) continue;

    final email = _text(member['email']);
    final preferredName =
        _text(member['displayName']) ??
        _text(score?['displayName']) ??
        email ??
        'Participante';
    rows.add(
      TournamentRankingRow(
        userId: userId,
        displayName: preferredName,
        email: email,
        place: _integer(score?['place']),
        points: _integer(score?['points']) ?? 0,
        exactCount: _integer(score?['exactCount']) ?? 0,
        fivePointCount: _integer(score?['fivePointCount']) ?? 0,
        hasPrediction: score != null,
      ),
    );
  }

  rows.sort(_compareRows);
  return rows;
}

TournamentRankingRow _scoredRow(String userId, Map<String, dynamic> score) =>
    TournamentRankingRow(
      userId: userId,
      displayName: _text(score['displayName']) ?? 'Participante',
      email: null,
      place: _integer(score['place']),
      points: _integer(score['points']) ?? 0,
      exactCount: _integer(score['exactCount']) ?? 0,
      fivePointCount: _integer(score['fivePointCount']) ?? 0,
      hasPrediction: true,
    );

int _compareRows(TournamentRankingRow a, TournamentRankingRow b) {
  if (a.place != null && b.place != null && a.place != b.place) {
    return a.place!.compareTo(b.place!);
  }
  if (a.place != null &&
      b.place != null &&
      a.hasPrediction &&
      b.hasPrediction) {
    return a.userId.compareTo(b.userId);
  }
  if (a.place != null && b.place == null) return -1;
  if (a.place == null && b.place != null) return 1;
  if (a.hasPrediction != b.hasPrediction) {
    return a.hasPrediction ? -1 : 1;
  }
  final nameOrder = a.displayName.toLowerCase().compareTo(
    b.displayName.toLowerCase(),
  );
  return nameOrder != 0 ? nameOrder : a.userId.compareTo(b.userId);
}

bool _scoreIsBetter(
  Map<String, dynamic> candidate,
  Map<String, dynamic> current,
) => _compareScores(candidate, current) < 0;

int _compareScores(Map<String, dynamic> a, Map<String, dynamic> b) {
  final aPlace = _integer(a['place']);
  final bPlace = _integer(b['place']);
  if (aPlace != null && bPlace != null && aPlace != bPlace) {
    return aPlace.compareTo(bPlace);
  }
  final pointsOrder = (_integer(b['points']) ?? 0).compareTo(
    _integer(a['points']) ?? 0,
  );
  if (pointsOrder != 0) return pointsOrder;
  final exactOrder = (_integer(b['exactCount']) ?? 0).compareTo(
    _integer(a['exactCount']) ?? 0,
  );
  if (exactOrder != 0) return exactOrder;
  return (_integer(b['fivePointCount']) ?? 0).compareTo(
    _integer(a['fivePointCount']) ?? 0,
  );
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _integer(dynamic value) => value is int ? value : int.tryParse('$value');
