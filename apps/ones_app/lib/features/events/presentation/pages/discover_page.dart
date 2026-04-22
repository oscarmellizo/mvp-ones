import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
              hintText: 'Search templates (concert, movie, football...)',
            ),
            const SizedBox(height: 14),
            if (ctrl.loading && items.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (ctrl.error != null && items.isEmpty)
              OnesCard(
                child: Text(
                  'Failed to load templates. Please try again.',
                  style: TextStyle(
                    color: OnesColors.black.withOpacity(0.6),
                  ),
                ),
              )
            else ...[
              if (filtered.isEmpty)
                OnesCard(
                  child: Text(
                    'No templates found for "$q".',
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
                        child: const Text(
                          'Public',
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
              _InfoRow(label: 'Status', value: template.status),
              _InfoRow(
                  label: 'Frames',
                  value:
                      '${template.frameIds.length} frame${template.frameIds.length == 1 ? '' : 's'}'),
              const SizedBox(height: 16),
              const Text(
                'Use this event template?',
                style: TextStyle(fontWeight: FontWeight.w900),
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
                      child: const Text('Not now'),
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
                      child: const Text(
                        'Use template',
                        style: TextStyle(fontWeight: FontWeight.w900),
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
