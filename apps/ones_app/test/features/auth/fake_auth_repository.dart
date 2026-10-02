import 'dart:async';

import 'package:ones_app/features/auth/domain/auth_failure.dart';
import 'package:ones_app/features/auth/domain/auth_repository.dart';
import 'package:ones_app/features/auth/domain/auth_user.dart';

AuthUser fakeUser({String id = 'uid-1', String provider = 'google.com', bool verified = true}) => AuthUser(
      userId: id,
      email: '$id@example.com',
      displayName: 'Ana Pérez',
      pictureUrl: null,
      provider: provider,
      emailVerified: verified,
    );

class FakeAuthRepository implements AuthRepository {
  AuthUser? current;
  AuthUser signInResult = fakeUser();
  AuthException? signInError;
  AuthUser? afterMigration;
  AuthUser? afterReload;
  String token = 'token-1';
  int signOutCalls = 0;
  int verificationEmails = 0;
  int migrationRetries = 0;
  int reloadCalls = 0;

  /// Bitácora opcional de llamadas (para comprobar el orden con otros fakes).
  final List<String> calls = [];
  AuthException? revokeError;

  /// Si no es null, los inicios de sesión esperan a que se complete.
  Completer<void>? signInGate;
  AuthException? migrationError;

  /// Error al pedir el ID token (sesión muerta, sin internet...).
  AuthException? tokenError;

  /// Simula la primera apertura tras instalar: la sesión guardada se descarta.
  bool freshInstall = false;
  int freshInstallChecks = 0;
  final List<String> passwordResets = [];
  final List<bool> tokenRequests = [];

  Future<AuthUser> _signIn() async {
    await signInGate?.future;
    final error = signInError;
    if (error != null) throw error;
    current = signInResult;
    return signInResult;
  }

  @override
  Future<AuthUser?> currentUser() async => current;

  @override
  Future<AuthUser> signInWithGoogle() => _signIn();

  @override
  Future<AuthUser> signInWithApple() => _signIn();

  @override
  Future<AuthUser> signInWithEmail(String email, String password) => _signIn();

  @override
  Future<AuthUser> registerWithEmail(String email, String password) async {
    final user = await _signIn();
    verificationEmails++;
    return user;
  }

  @override
  Future<void> sendEmailVerification() async => verificationEmails++;

  @override
  Future<AuthUser?> reloadUser() async {
    reloadCalls++;
    await Future<void>.delayed(Duration.zero);
    return current = afterReload ?? current;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final error = signInError;
    if (error != null) throw error;
    passwordResets.add(email);
  }

  @override
  Future<void> clearSessionIfFreshInstall() async {
    freshInstallChecks++;
    if (freshInstall) current = null;
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    tokenRequests.add(forceRefresh);
    final error = tokenError;
    if (error != null) throw error;
    return current == null ? null : token;
  }

  @override
  Future<AuthUser> signInAgainAfterMigration() async {
    migrationRetries++;
    final error = migrationError;
    if (error != null) throw error;
    current = afterMigration ?? current;
    return current!;
  }

  @override
  Future<void> revokeAppleAccessIfNeeded() async {
    calls.add('revokeAppleAccessIfNeeded');
    final error = revokeError;
    if (error != null) throw error;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    signOutCalls++;
    current = null;
  }
}
