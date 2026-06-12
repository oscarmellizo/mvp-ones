import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';
import '../../../../core/ui/widgets/ones_search_field.dart';
import '../../adapters/api/event_templates_api_repository.dart';
import '../discover_templates_controller.dart';
import 'create_event_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _searchController = TextEditingController();

  String? _lastLanguage;

  static const Set<String> _discoverRequiredKeys = {
    'discover.search_templates',
    'discover.failed_load_templates',
    'discover.no_templates_found_for',
    'discover.public',
    'discover.status_label',
    'discover.frames_label',
    'discover.use_template_question',
    'discover.not_now',
    'discover.use_template',
  };

  String _formatError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map) {
        final code = data['code'] ?? data['error'];
        final msg = data['message'];
        return 'HTTP $status ${code ?? ''} ${msg ?? ''}'.trim();
      }
      if (data is String && data.trim().isNotEmpty) {
        return 'HTTP $status ${data.trim()}'.trim();
      }
      return 'HTTP $status ${error.message ?? 'Request failed'}'.trim();
    }
    return error.toString();
  }

  @override
  void initState() {
    super.initState();
    _lastLanguage = context.read<TranslationsService>().getCurrentLanguage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TranslationsService>().ensurePageTranslations(
            page: 'discover',
            requiredKeys: _discoverRequiredKeys,
          );
      final ctrl = context.read<DiscoverTemplatesController>();
      if (ctrl.templates.isEmpty && !ctrl.loading) {
        ctrl.load();
      }
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DiscoverTemplatesController>();
    final t = context.watch<TranslationsService>();

    final lang = t.getCurrentLanguage();
    if (_lastLanguage != lang) {
      _lastLanguage = lang;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TranslationsService>().ensurePageTranslations(
              page: 'discover',
              requiredKeys: _discoverRequiredKeys,
            );
      });
    }
    final q = _searchController.text.trim().toLowerCase();
    final items = ctrl.templates;
    final filtered = items.where((t) {
      if (q.isEmpty) return true;
      return t.name.toLowerCase().contains(q);
    }).toList(growable: false);

    return Scaffold(
      backgroundColor: OnesColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
          children: [
            OnesSearchField(
              controller: _searchController,
              hintText: t.translate('discover.search_templates'),
            ),
            const SizedBox(height: 14),
            if (ctrl.loading && items.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (ctrl.error != null && items.isEmpty)
              OnesCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.translate('discover.failed_load_templates'),
                      style: TextStyle(
                        color: OnesColors.black.withOpacity(0.6),
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 6),
                      Text(
                        _formatError(ctrl.error!),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: OnesColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else ...[
              if (filtered.isEmpty)
                OnesCard(
                  child: Text(
                    '${t.translate('discover.no_templates_found_for')} "$q".',
                    style: TextStyle(color: OnesColors.black.withOpacity(0.6)),
                  ),
                )
              else
                ...filtered.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TemplateCard(
                      template: t,
                      onTap: () => _openTemplate(context, t),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openTemplate(BuildContext context, EventTemplate template) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _TemplateDetailsSheet(
          template: template,
          onUseTemplate: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreateEventPage(
                  initialTitle: template.name,
                  initialLocation: null,
                  initialStartDate: null,
                  initialStartTime: null,
                  initialEndDate: null,
                  initialEndTime: null,
                  initialFrameIds: template.frameIds,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final EventTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: OnesColors.white,
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Container(
                width: 56,
                height: 56,
                color: OnesColors.yellowLight,
                child: const Icon(Icons.event, color: OnesColors.purpleDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: OnesColors.green.withOpacity(0.25),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Text(
                          t.translate('discover.public'),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: OnesColors.purpleDark,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${template.status} • ${template.frameIds.length} frame${template.frameIds.length == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: OnesColors.black.withOpacity(0.55),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _TemplateDetailsSheet extends StatelessWidget {
  final EventTemplate template;
  final VoidCallback onUseTemplate;

  const _TemplateDetailsSheet({
    required this.template,
    required this.onUseTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.40,
      maxChildSize: 0.90,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: OnesColors.yellowLight.withOpacity(0.35),
            borderRadius: BorderRadius.zero,
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: OnesColors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Container(
                  height: 160,
                  color: OnesColors.yellow,
                  child: const Icon(
                    Icons.event,
                    size: 80,
                    color: OnesColors.purpleDark,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                template.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10),
              _InfoRow(
                  label: t.translate('discover.status_label'),
                  value: template.status),
              _InfoRow(
                  label: t.translate('discover.frames_label'),
                  value:
                      '${template.frameIds.length} frame${template.frameIds.length == 1 ? '' : 's'}'),
              const SizedBox(height: 12),
              if (template.frames.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: template.frames.map((f) {
                    final hasVertical =
                        f.verticalUrl != null && f.verticalUrl!.isNotEmpty;
                    final hasHorizontal =
                        f.horizontalUrl != null && f.horizontalUrl!.isNotEmpty;
                    if (!hasVertical && !hasHorizontal) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (f.name != null && f.name!.isNotEmpty) ...[
                            Text(
                              f.name!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Row(
                            children: [
                              if (hasVertical)
                                Expanded(
                                  child: AspectRatio(
                                    aspectRatio: 9 / 16,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.zero,
                                      child: Image.network(
                                        f.verticalUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              if (hasVertical && hasHorizontal)
                                const SizedBox(width: 8),
                              if (hasHorizontal)
                                Expanded(
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.zero,
                                      child: Image.network(
                                        f.horizontalUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              Text(
                t.translate('discover.use_template_question'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: Text(t.translate('discover.not_now')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onUseTemplate,
                      style: FilledButton.styleFrom(
                        backgroundColor: OnesColors.purpleMid,
                        foregroundColor: OnesColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: Text(
                        t.translate('discover.use_template'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withOpacity(0.55),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
