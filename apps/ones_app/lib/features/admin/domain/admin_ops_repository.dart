abstract interface class AdminOpsRepository {
  Future<Map<String, dynamic>> getQueues(String idToken);
  Future<Map<String, dynamic>> getMappings(String idToken);
  Future<void> setRealtimeMapping(String idToken, bool enabled);
}
