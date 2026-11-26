class CollectionJoinQrPayload {
  final String collectionId;
  final String token;

  const CollectionJoinQrPayload({
    required this.collectionId,
    required this.token,
  });

  static CollectionJoinQrPayload? tryParse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.hasPort || uri.userInfo.isNotEmpty) return null;

    final isWebLink = uri.scheme == 'https' &&
        const {'app.ones.events', 'appdev.ones.events'}.contains(uri.host) &&
        uri.path == '/collections/join';
    final isAppLink = uri.scheme == 'ones' &&
        uri.host == 'collections' &&
        uri.path == '/join';
    if (!isWebLink && !isAppLink) return null;

    final ids = uri.queryParametersAll['collectionId'];
    final tokens = uri.queryParametersAll['token'];
    if (ids == null ||
        tokens == null ||
        ids.length != 1 ||
        tokens.length != 1 ||
        ids.single.trim().isEmpty ||
        tokens.single.trim().isEmpty) {
      return null;
    }
    return CollectionJoinQrPayload(
      collectionId: ids.single.trim(),
      token: tokens.single.trim(),
    );
  }
}
