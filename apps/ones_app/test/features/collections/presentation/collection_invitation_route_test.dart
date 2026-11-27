import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/app.dart';

void main() {
  test('accepts collection email links from the configured dev host', () {
    final route = collectionInvitationRouteForLink(
      Uri.parse(
        'https://appdev.ones.events/collection-invitation?token=abc123',
      ),
      allowDevHost: true,
    );

    expect(route, '/collection-invitation?token=abc123');
  });

  test('does not treat a dev email link as a production link', () {
    final route = collectionInvitationRouteForLink(
      Uri.parse(
        'https://appdev.ones.events/collection-invitation?token=abc123',
      ),
    );

    expect(route, isNull);
  });
}
