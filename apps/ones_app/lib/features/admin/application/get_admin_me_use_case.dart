import '../domain/admin_repository.dart';

class GetAdminMeUseCase {
  final AdminRepository repository;

  GetAdminMeUseCase(this.repository);

  Future<bool> execute(String idToken) {
    return repository.isAdmin(idToken);
  }
}
