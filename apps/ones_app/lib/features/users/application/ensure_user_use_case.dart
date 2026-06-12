import '../domain/users_repository.dart';

class EnsureUserUseCase {
  final UsersRepository repository;

  EnsureUserUseCase(this.repository);

  Future<void> execute(String idToken) {
    return repository.ensureUser(idToken);
  }
}

class GetUserPreferencesUseCase {
  final UsersRepository repository;

  GetUserPreferencesUseCase(this.repository);

  Future<UserPreferences?> execute(String idToken) {
    return repository.getPreferences(idToken);
  }
}

class UpdateUserPreferencesUseCase {
  final UsersRepository repository;

  UpdateUserPreferencesUseCase(this.repository);

  Future<UserPreferences?> execute(
    String idToken,
    String preferredName,
    String languagePreference,
  ) {
    return repository.updatePreferences(idToken, preferredName, languagePreference);
  }
}

class LookupUserByEmailUseCase {
  final UsersRepository repository;

  LookupUserByEmailUseCase(this.repository);

  Future<UserLookup?> execute(String idToken, String email) {
    return repository.lookupUserByEmail(idToken, email);
  }
}
