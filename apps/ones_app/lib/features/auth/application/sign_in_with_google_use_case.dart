import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

class SignInWithGoogleUseCase {
  final AuthRepository repository;

  SignInWithGoogleUseCase(this.repository);

  Future<AuthUser> execute() {
    return repository.signInWithGoogle();
  }
}
