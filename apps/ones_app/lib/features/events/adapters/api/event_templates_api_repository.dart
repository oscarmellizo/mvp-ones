import '../../../../core/http/ones_api_factory.dart';

class EventTemplate {
  final String id;
  final String name;
  final String status;
  final int? sortOrder;
  final List<String> frameIds;

  const EventTemplate({
    required this.id,
    required this.name,
    required this.status,
    required this.sortOrder,
    required this.frameIds,
  });

  factory EventTemplate.fromJson(Map<String, dynamic> json) {
    final id = json['eventTemplateId'];
    final name = json['name'];
    final status = json['status'];
    final frameIds =
        (json['frameIds'] as List?)?.map((e) => e.toString()).toList() ?? [];

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
    final res = await dio.get('/v1/event-templates');
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
