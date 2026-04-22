import 'package:flutter/foundation.dart';

import '../adapters/api/event_templates_api_repository.dart';

class DiscoverTemplatesController extends ChangeNotifier {
  final EventTemplatesApiRepository repository;

  bool _loading = false;
  Object? _error;
  List<EventTemplate> _templates = const [];

  DiscoverTemplatesController({required this.repository});

  bool get loading => _loading;
  Object? get error => _error;
  List<EventTemplate> get templates => _templates;

  void setIdToken(String? token) {
    repository.setIdToken(token);
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _templates = await repository.listTemplates();
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
