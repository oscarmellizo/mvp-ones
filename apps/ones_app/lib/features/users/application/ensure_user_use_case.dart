import '../domain/users_repository.dart';

class EnsureUserUseCase {
  final UsersRepository repository;

  EnsureUserUseCase(this.repository);

  Future<void> execute(String idToken) {
    return repository.ensureUser(idToken);
  }
}
