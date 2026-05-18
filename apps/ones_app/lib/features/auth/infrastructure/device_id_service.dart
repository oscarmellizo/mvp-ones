import 'package:uuid/uuid.dart';

import 'secure_storage.dart';

class DeviceIdService {
  static const _key = 'ones.device_id';

  final SecureStorage storage;
  final Uuid _uuid;

  DeviceIdService(this.storage) : _uuid = const Uuid();

  Future<String> getOrCreate() async {
    final existing = await storage.read(_key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = _uuid.v4();
    await storage.write(_key, created);
    return created;
  }
}
