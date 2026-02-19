abstract interface class UsersRepository {
  Future<void> ensureUser(String idToken);

  Future<String?> getPreferredName(String idToken);

  Future<String?> updatePreferredName(String idToken, String preferredName);

  Future<UserLookup?> lookupUserByEmail(String idToken, String email);
}

class UserLookup {
  final String email;
  final String? preferredName;

  const UserLookup({required this.email, required this.preferredName});
}
