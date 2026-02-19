import '../domain/users_repository.dart';

class EnsureUserUseCase {
  final UsersRepository repository;

  EnsureUserUseCase(this.repository);

  Future<void> execute(String idToken) {
    return repository.ensureUser(idToken);
  }
}

class GetPreferredNameUseCase {
  final UsersRepository repository;

  GetPreferredNameUseCase(this.repository);

  Future<String?> execute(String idToken) {
    return repository.getPreferredName(idToken);
  }
}

class UpdatePreferredNameUseCase {
  final UsersRepository repository;

  UpdatePreferredNameUseCase(this.repository);

  Future<String?> execute(String idToken, String preferredName) {
    return repository.updatePreferredName(idToken, preferredName);
  }
}

class LookupUserByEmailUseCase {
  final UsersRepository repository;

  LookupUserByEmailUseCase(this.repository);

  Future<UserLookup?> execute(String idToken, String email) {
    return repository.lookupUserByEmail(idToken, email);
  }
}
