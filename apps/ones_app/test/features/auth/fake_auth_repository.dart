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

  /// Si no es null, los inicios de sesión esperan a que se complete.
  Completer<void>? signInGate;
  AuthException? migrationError;
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
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    tokenRequests.add(forceRefresh);
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
  Future<void> signOut() async {
    signOutCalls++;
    current = null;
  }
}
