abstract interface class UsersRepository {
  Future<void> ensureUser(String idToken);

  Future<UserPreferences?> getPreferences(String idToken);

  Future<UserPreferences?> updatePreferences(
    String idToken,
    String preferredName,
    String languagePreference,
  );

  Future<UserLookup?> lookupUserByEmail(String idToken, String email);
}

class UserPreferences {
  final String? preferredName;
  final String? languagePreference;

  const UserPreferences({
    required this.preferredName,
    required this.languagePreference,
  });
}

class UserLookup {
  final String email;
  final String? preferredName;

  const UserLookup({required this.email, required this.preferredName});
}
