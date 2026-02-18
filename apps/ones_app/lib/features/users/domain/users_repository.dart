abstract interface class UsersRepository {
  Future<void> ensureUser(String idToken);
}
