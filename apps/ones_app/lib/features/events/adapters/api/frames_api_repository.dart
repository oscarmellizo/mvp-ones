import '../../../../core/http/ones_api_factory.dart';
import 'package:dio/dio.dart';

class FrameCatalogItem {
  final String frameId;
  final String? name;
  final String? verticalUrl;
  final String? horizontalUrl;

  const FrameCatalogItem({
    required this.frameId,
    required this.name,
    required this.verticalUrl,
    required this.horizontalUrl,
  });

  factory FrameCatalogItem.fromJson(Map<String, dynamic> json) {
    final frameId = json['frameId'];
    if (frameId is! String || frameId.isEmpty) {
      throw StateError('Missing frameId');
    }

    final verticalUrl = json['verticalUrl'];
    final horizontalUrl = json['horizontalUrl'];

    return FrameCatalogItem(
      frameId: frameId,
      name: json['name'] as String?,
      verticalUrl:
          verticalUrl is String && verticalUrl.isNotEmpty ? verticalUrl : null,
      horizontalUrl: horizontalUrl is String && horizontalUrl.isNotEmpty
          ? horizontalUrl
          : null,
    );
  }
}

class ListFramesResult {
  final List<FrameCatalogItem> items;
  final String? nextToken;

  const ListFramesResult({required this.items, required this.nextToken});
}

class FramesApiRepository {
  final OnesApiFactory _apiFactory;
  String? _idToken;

  FramesApiRepository(this._apiFactory);

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<ListFramesResult> listFrames({
    int limit = 50,
    String? nextToken,
  }) async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    final res = await dio.get(
      '/v1/frames',
      options: Options(
        extra: {
          'secure': [
            {
              'type': 'http',
              'scheme': 'bearer',
              'name': 'bearerAuth',
            }
          ],
        },
      ),
      queryParameters: {
        'limit': limit,
        if (nextToken != null && nextToken.isNotEmpty) 'nextToken': nextToken,
      },
    );

    final data = res.data;
    if (data is! Map) {
      throw StateError('Invalid frames response');
    }

    final itemsRaw = data['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((m) => FrameCatalogItem.fromJson(m.cast<String, dynamic>()))
            .toList(growable: false)
        : const <FrameCatalogItem>[];

    final nt = data['nextToken'];

    return ListFramesResult(
      items: items,
      nextToken: nt is String && nt.isNotEmpty ? nt : null,
    );
  }
}
