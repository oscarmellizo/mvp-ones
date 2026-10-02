import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/core/i18n/translations_service.dart';
import 'package:ones_app/core/ui/widgets/ones_card.dart';
import 'package:ones_app/features/admin/application/get_admin_me_use_case.dart';
import 'package:ones_app/features/auth/presentation/auth_controller.dart';
import 'package:ones_app/features/events/presentation/pages/profile_page.dart';
import 'package:ones_app/features/subscriptions/presentation/subscriptions_controller.dart';
import 'package:ones_app/features/users/application/ensure_user_use_case.dart';
import 'package:ones_app/features/users/domain/users_repository.dart';
import 'package:provider/provider.dart';

import '../../../auth/fake_auth_repository.dart';

class _MockTranslations extends Mock implements TranslationsService {}
class _MockSubscriptions extends Mock implements SubscriptionsController {}
class _MockGetPrefs extends Mock implements GetUserPreferencesUseCase {}
class _MockGetAdminMe extends Mock implements GetAdminMeUseCase {}
class _MockEnsureUser extends Mock implements EnsureUserUseCase {}
class _MockUpdatePrefs extends Mock implements UpdateUserPreferencesUseCase {}
class _MockLookup extends Mock implements LookupUserByEmailUseCase {}

void main() {
  testWidgets('la tarjeta Cuenta muestra solo el correo, sin nombre ni apellido', (tester) async {
    await pumpProfile(tester);

    expect(find.text('profile.account'), findsOneWidget);
    expect(find.text('profile.email'), findsOneWidget);
    expect(find.text('uid-1@example.com'), findsOneWidget);
    expect(find.text('profile.first_name'), findsNothing);
    expect(find.text('profile.last_name'), findsNothing);
  });


  testWidgets('la tarjeta Cuenta ocupa todo el ancho y cerrar sesión queda abajo', (tester) async {
    await pumpProfile(tester);

    // Pantalla de 540 pt menos 16 pt de margen por lado.
    final card = find.ancestor(of: find.text('profile.account'), matching: find.byType(OnesCard));
    expect(tester.getSize(card).width, 540 - 32);

    final logout = find.ancestor(of: find.text('profile.logout'), matching: find.byType(FilledButton));
    expect(tester.getRect(logout).bottom, closeTo(1200 - 16, 1));
  });
}

Future<void> pumpProfile(WidgetTester tester) async {
  final translations = _MockTranslations();
  when(() => translations.translate(any(), fallback: any(named: 'fallback')))
      .thenAnswer((i) => i.positionalArguments.first as String);
  when(() => translations.getCurrentLanguage()).thenReturn('es');
  when(() => translations.ensureInitialized()).thenAnswer((_) async {});
  when(() => translations.ensurePageTranslations(
        page: any(named: 'page'),
        requiredKeys: any(named: 'requiredKeys'),
      )).thenAnswer((_) async {});
  final subscriptions = _MockSubscriptions();
  when(() => subscriptions.loadAll()).thenAnswer((_) async {});
  when(() => subscriptions.subscription).thenReturn(null);

  final getPrefs = _MockGetPrefs();
  when(() => getPrefs.execute(any()))
      .thenAnswer((_) async => const UserPreferences(preferredName: 'Ana', languagePreference: 'es'));
  final admin = _MockGetAdminMe();
  when(() => admin.execute(any())).thenAnswer((_) async => false);
  final repo = FakeAuthRepository()..signInResult = fakeUser();
  final auth = AuthController(
    authRepository: repo,
    ensureUser: _MockEnsureUser(),
    getUserPreferences: getPrefs,
    updateUserPreferences: _MockUpdatePrefs(),
    lookupUserByEmailUseCase: _MockLookup(),
    getAdminMe: admin,
  );
  await auth.signInWithGoogle();

  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: auth),
      ChangeNotifierProvider<TranslationsService>.value(value: translations),
      ChangeNotifierProvider<SubscriptionsController>.value(value: subscriptions),
    ],
    child: const MaterialApp(home: ProfilePage()),
  ));
  await tester.pump();
}
