import '../../../../core/http/ones_api_factory.dart';
import 'package:dio/dio.dart';

class TemplateFrame {
  final String frameId;
  final String? name;
  final String? verticalUrl;
  final String? horizontalUrl;

  const TemplateFrame({
    required this.frameId,
    required this.name,
    required this.verticalUrl,
    required this.horizontalUrl,
  });

  factory TemplateFrame.fromJson(Map<String, dynamic> json) {
    final frameId = json['frameId'];
    final verticalUrl = json['verticalUrl'];
    final horizontalUrl = json['horizontalUrl'];

    if (frameId is! String || frameId.isEmpty) {
      throw StateError('Missing frameId');
    }

    return TemplateFrame(
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

class EventTemplate {
  final String id;
  final String name;
  final String status;
  final int? sortOrder;
  final List<String> frameIds;
  final List<TemplateFrame> frames;

  const EventTemplate({
    required this.id,
    required this.name,
    required this.status,
    required this.sortOrder,
    required this.frameIds,
    required this.frames,
  });

  factory EventTemplate.fromJson(Map<String, dynamic> json) {
    final id = json['eventTemplateId'];
    final name = json['name'];
    final status = json['status'];
    final frameIds =
        (json['frameIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final framesRaw = json['frames'];
    final frames = framesRaw is List
        ? framesRaw
            .whereType<Map>()
            .map((m) => TemplateFrame.fromJson(m.cast<String, dynamic>()))
            .toList(growable: false)
        : const <TemplateFrame>[];

    if (id is! String || id.isEmpty) {
      throw StateError('Missing eventTemplateId');
    }
    if (name is! String || name.isEmpty) {
      throw StateError('Missing name');
    }
    if (status is! String) {
      throw StateError('Missing status');
    }

    return EventTemplate(
      id: id,
      name: name,
      status: status,
      sortOrder: json['sortOrder'] as int?,
      frameIds: frameIds,
      frames: frames,
    );
  }
}

class EventTemplatesApiRepository {
  final OnesApiFactory _apiFactory;
  String? _idToken;

  EventTemplatesApiRepository(this._apiFactory);

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<List<EventTemplate>> listTemplates() async {
    final dio = _apiFactory.create(idToken: _idToken).dio;
    final res = await dio.get(
      '/v1/event-templates',
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
    );
    final data = res.data;
    if (data is! List) {
      throw StateError('Invalid event templates response');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(EventTemplate.fromJson)
        .toList(growable: false);
  }
}
