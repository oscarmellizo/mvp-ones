import '../domain/auth_repository.dart';

class GetIdTokenUseCase {
  final AuthRepository repository;

  GetIdTokenUseCase(this.repository);

  Future<String?> execute() {
    return repository.getIdToken();
  }
}
