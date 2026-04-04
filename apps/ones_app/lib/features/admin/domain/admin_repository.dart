abstract interface class AdminRepository {
  Future<bool> isAdmin(String idToken);
}
