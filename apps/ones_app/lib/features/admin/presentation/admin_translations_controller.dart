import 'package:ones_api_client/ones_api_client.dart';

class TranslationItem {
  final String translationKey;
  final String languageCode;
  final String? value;
  final String? context;

  TranslationItem({
    required this.translationKey,
    required this.languageCode,
    this.value,
    this.context,
  });
}

class AdminTranslationsController {
  final OnesApiClient _apiClient;

  AdminTranslationsController(this._apiClient);

  List<TranslationItem> items = [];
  bool loading = false;
  String? lastError;

  Future<void> load(String languageCode) async {
    loading = true;
    lastError = null;
    // Note: This will need to be implemented after API client is regenerated
    // For now, we'll use a placeholder
    try {
      // TODO: Implement after API client regeneration
      // final translations = await _apiClient.v1AdminTranslationsList(
      //   languageCode: languageCode,
      // );
      // items = translations.map((t) => TranslationItem(
      //   translationKey: t.translationKey ?? '',
      //   languageCode: t.languageCode ?? '',
      //   value: t.value,
      //   context: t.context,
      // )).toList();
      items = [];
    } catch (e) {
      lastError = e.toString();
    } finally {
      loading = false;
    }
  }

  Future<void> create({
    required String translationKey,
    required String languageCode,
    String? value,
    String? context,
  }) async {
    loading = true;
    lastError = null;
    try {
      // TODO: Implement after API client regeneration
      // await _apiClient.v1AdminTranslationsPost(
      //   body: UpsertTranslationRequest(
      //     translationKey: translationKey,
      //     languageCode: languageCode,
      //     value: value,
      //     context: context,
      //   ),
      // );
      items.add(TranslationItem(
        translationKey: translationKey,
        languageCode: languageCode,
        value: value,
        context: context,
      ));
    } catch (e) {
      lastError = e.toString();
    } finally {
      loading = false;
    }
  }

  Future<void> update({
    required String translationKey,
    required String languageCode,
    String? value,
    String? context,
  }) async {
    loading = true;
    lastError = null;
    try {
      // TODO: Implement after API client regeneration
      // await _apiClient.v1AdminTranslationsPost(
      //   body: UpsertTranslationRequest(
      //     translationKey: translationKey,
      //     languageCode: languageCode,
      //     value: value,
      //     context: context,
      //   ),
      // );
      final index = items.indexWhere(
        (t) => t.translationKey == translationKey && t.languageCode == languageCode,
      );
      if (index >= 0) {
        items[index] = TranslationItem(
          translationKey: translationKey,
          languageCode: languageCode,
          value: value,
          context: context,
        );
      }
    } catch (e) {
      lastError = e.toString();
    } finally {
      loading = false;
    }
  }

  Future<void> delete(String translationKey, String languageCode) async {
    loading = true;
    lastError = null;
    try {
      // TODO: Implement after API client regeneration
      // await _apiClient.v1AdminTranslationsTranslationKeyLanguageCodeDelete(
      //   translationKey: translationKey,
      //   languageCode: languageCode,
      // );
      items.removeWhere(
        (t) => t.translationKey == translationKey && t.languageCode == languageCode,
      );
    } catch (e) {
      lastError = e.toString();
    } finally {
      loading = false;
    }
  }
}
