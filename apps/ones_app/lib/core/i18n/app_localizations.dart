import 'package:flutter/widgets.dart';
import 'translations_service.dart';

class AppLocalizations {
  final TranslationsService _translationsService;

  AppLocalizations(this._translationsService);

  static AppLocalizations of(BuildContext context) {
    final TranslationsService? service = 
        context.dependOnInheritedWidgetOfExactType<TranslationsProvider>()?.service;
    if (service == null) {
      throw Exception('TranslationsProvider not found in widget tree');
    }
    return AppLocalizations(service);
  }

  String translate(String key, {String? fallback}) {
    return _translationsService.translate(key, fallback: fallback);
  }

  // Common translations
  String get save => translate('common.save', fallback: 'Guardar');
  String get cancel => translate('common.cancel', fallback: 'Cancelar');
  String get delete => translate('common.delete', fallback: 'Eliminar');
  String get edit => translate('common.edit', fallback: 'Editar');
  String get loading => translate('common.loading', fallback: 'Cargando...');
  String get error => translate('common.error', fallback: 'Error');
  String get success => translate('common.success', fallback: 'Éxito');
  String get retry => translate('common.retry', fallback: 'Reintentar');
  String get close => translate('common.close', fallback: 'Cerrar');
  String get confirm => translate('common.confirm', fallback: 'Confirmar');
  String get back => translate('common.back', fallback: 'Atrás');
}

class TranslationsProvider extends InheritedWidget {
  final TranslationsService service;

  const TranslationsProvider({
    super.key,
    required this.service,
    required Widget child,
  }) : super(child: child);

  static TranslationsProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TranslationsProvider>();
  }

  @override
  bool updateShouldNotify(TranslationsProvider oldWidget) {
    return service != oldWidget.service;
  }
}
