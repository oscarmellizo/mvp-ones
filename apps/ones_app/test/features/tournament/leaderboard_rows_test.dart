import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/tournament/presentation/leaderboard_rows.dart';

void main() {
  group('buildTournamentRankingRows', () {
    test('uses preferred names and collapses duplicate invite identities', () {
      final rows = buildTournamentRankingRows(
        leaderboard: [
          {
            'userId': 'universe-current',
            'displayName': 'Universo Explicado',
            'points': 18,
            'exactCount': 1,
            'fivePointCount': 3,
            'place': 2,
          },
          {
            'userId': 'universe-legacy',
            'displayName': 'Universo Explicado',
            'points': 0,
            'exactCount': 0,
            'fivePointCount': 0,
            'place': 4,
          },
        ],
        participants: [
          {
            'userId': 'owner',
            'email': 'owner@example.com',
            'displayName': 'Oscar',
            'role': 'owner',
            'status': 'owner',
          },
          {
            'userId': 'universe-current',
            'email': 'universe@example.com',
            'displayName': 'Nombre preferido',
            'role': 'guest',
            'status': 'accepted',
          },
          {
            'userId': 'universe-legacy',
            'email': 'universe@example.com',
            'displayName': 'Nombre preferido',
            'role': 'guest',
            'status': 'accepted',
          },
          {
            'userId': 'pending',
            'email': 'pending@example.com',
            'displayName': 'Invitado pendiente',
            'role': 'guest',
            'status': 'invited',
          },
        ],
        participantsLoaded: true,
      );

      expect(rows, hasLength(2));
      expect(rows.first.userId, 'universe-current');
      expect(rows.first.displayName, 'Nombre preferido');
      expect(rows.first.points, 18);
      expect(rows.first.place, 2);
      expect(rows.last.userId, 'owner');
      expect(rows.last.hasPrediction, isFalse);
      expect(rows.map((row) => row.userId), isNot(contains('pending')));
    });

    test('deduplicates repeated score rows for the same participant', () {
      final rows = buildTournamentRankingRows(
        leaderboard: [
          {
            'userId': 'member',
            'displayName': 'Stale name',
            'points': 18,
            'exactCount': 1,
            'fivePointCount': 3,
            'place': 1,
          },
          {
            'userId': 'member',
            'displayName': 'Stale name',
            'points': 0,
            'exactCount': 0,
            'fivePointCount': 0,
            'place': 4,
          },
        ],
        participants: [
          {
            'userId': 'member',
            'email': 'member@example.com',
            'displayName': 'Preferred name',
            'role': 'guest',
            'status': 'accepted',
          },
        ],
        participantsLoaded: true,
      );

      expect(rows, hasLength(1));
      expect(rows.single.displayName, 'Preferred name');
      expect(rows.single.points, 18);
    });

    test('keeps different guests with the same preferred name distinct', () {
      final rows = buildTournamentRankingRows(
        leaderboard: const [],
        participants: [
          {
            'userId': 'guest-1',
            'email': 'one@example.com',
            'displayName': 'Alex',
            'role': 'guest',
            'status': 'accepted',
          },
          {
            'userId': 'guest-2',
            'email': 'two@example.com',
            'displayName': 'Alex',
            'role': 'guest',
            'status': 'accepted',
          },
        ],
        participantsLoaded: true,
      );

      expect(rows, hasLength(2));
      expect(rows.map((row) => row.email).toSet(), {
        'one@example.com',
        'two@example.com',
      });
      expect(rows.every((row) => !row.hasPrediction), isTrue);
    });

    test(
      'falls back to unique scored users when the member list is unavailable',
      () {
        final rows = buildTournamentRankingRows(
          leaderboard: [
            {
              'userId': 'member',
              'displayName': 'Stored name',
              'points': 18,
              'exactCount': 1,
              'fivePointCount': 3,
              'place': 1,
            },
            {
              'userId': 'member',
              'displayName': 'Stored name',
              'points': 0,
              'exactCount': 0,
              'fivePointCount': 0,
              'place': 4,
            },
          ],
          participants: const [],
          participantsLoaded: false,
        );

        expect(rows, hasLength(1));
        expect(rows.single.displayName, 'Stored name');
        expect(rows.single.points, 18);
      },
    );
  });
}
