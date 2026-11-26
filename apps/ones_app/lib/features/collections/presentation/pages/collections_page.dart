import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_empty_state.dart';
import '../../../../core/ui/widgets/ones_search_field.dart';
import '../../../tutorial/presentation/tutorial_keys.dart';
import '../../domain/collection.dart';
import '../collections_controller.dart';
import 'collection_detail_page.dart';
import 'create_collection_page.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CollectionsController>().refresh();
    });
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _create() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreateCollectionPage()),
    );
    if (mounted) context.read<CollectionsController>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CollectionsController>();
    final translations = context.watch<TranslationsService>();
    final language = translations.getCurrentLanguage();
    final query = _search.text.trim().toLowerCase();
    final filtered = controller.collections.where((collection) {
      if (query.isEmpty) return true;
      return collection.name.toLowerCase().contains(query) ||
          (collection.description ?? '').toLowerCase().contains(query) ||
          collection.type.label(language).toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) {
        if (a.isLifeCollection != b.isLifeCollection) {
          return a.isLifeCollection ? -1 : 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });

    return ColoredBox(
      color: OnesColors.surfaceWarm,
      child: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                translations.translate('collections.title',
                    fallback: 'Colecciones'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: OnesColors.purpleDeep,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              OnesSearchField(
                key: TutorialKeys.homeCollectionsSearch,
                controller: _search,
                hintText: translations.translate(
                  'collections.search',
                  fallback: 'Buscar colecciones',
                ),
                borderRadius: BorderRadius.circular(14),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _search.clear,
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: translations.translate(
                          'common.clear',
                          fallback: 'Limpiar',
                        ),
                      ),
              ),
              const SizedBox(height: 18),
              if (controller.loading && controller.collections.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (controller.error != null &&
                  controller.collections.isEmpty)
                OnesEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: translations.translate(
                    'collections.load_error',
                    fallback: 'No pudimos cargar tus colecciones',
                  ),
                  action: FilledButton.tonal(
                    onPressed: controller.refresh,
                    child: Text(translations.translate(
                      'common.retry',
                      fallback: 'Reintentar',
                    )),
                  ),
                )
              else if (filtered.isEmpty)
                OnesEmptyState(
                  icon: query.isEmpty
                      ? Icons.collections_bookmark_outlined
                      : Icons.search_off_outlined,
                  title: query.isEmpty
                      ? translations.translate(
                          'collections.empty_title',
                          fallback: 'Tus recuerdos empiezan aquí',
                        )
                      : translations.translate(
                          'collections.no_results',
                          fallback: 'No encontramos esa colección',
                        ),
                  message: query.isEmpty
                      ? translations.translate(
                          'collections.empty_message',
                          fallback:
                              'Crea un espacio para reunir fotos con las personas que elijas.',
                        )
                      : null,
                  action: query.isEmpty
                      ? FilledButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.add),
                          label: Text(translations.translate(
                            'collections.create',
                            fallback: 'Crear colección',
                          )),
                        )
                      : null,
                )
              else
                ...filtered.map(
                  (collection) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CollectionCard(
                      collection: collection,
                      language: language,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CollectionDetailPage(collection: collection),
                        ),
                      ),
                    ),
                  ),
                ),
              if (controller.error != null && controller.collections.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    translations.translate(
                      'collections.refresh_error',
                      fallback: 'No se pudieron actualizar las colecciones.',
                    ),
                    style: const TextStyle(color: OnesColors.danger),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final OnesCollection collection;
  final String language;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.collection,
    required this.language,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OnesColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: OnesColors.surfaceMuted),
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: collection.isLifeCollection
                      ? OnesColors.purpleMid.withValues(alpha: .12)
                      : OnesColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  collection.isLifeCollection
                      ? Icons.favorite_border
                      : collection.type == CollectionType.private
                          ? Icons.lock_outline
                          : Icons.collections_bookmark_outlined,
                  color: OnesColors.purpleMid,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      collection.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OnesColors.purpleDeep,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      collection.description?.isNotEmpty == true
                          ? collection.description!
                          : collection.type.label(language),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OnesColors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: OnesColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
