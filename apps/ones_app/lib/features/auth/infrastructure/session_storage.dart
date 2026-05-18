import 'secure_storage.dart';

class SessionStorage {
  static const _accessTokenKey = 'ones.access_token';
  static const _refreshTokenKey = 'ones.refresh_token';

  final SecureStorage storage;

  SessionStorage(this.storage);

  Future<String?> readAccessToken() => storage.read(_accessTokenKey);
  Future<String?> readRefreshToken() => storage.read(_refreshTokenKey);

  Future<void> writeTokens({required String accessToken, required String refreshToken}) async {
    await storage.write(_accessTokenKey, accessToken);
    await storage.write(_refreshTokenKey, refreshToken);
  }

  Future<void> clear() async {
    await storage.delete(_accessTokenKey);
    await storage.delete(_refreshTokenKey);
  }
}
