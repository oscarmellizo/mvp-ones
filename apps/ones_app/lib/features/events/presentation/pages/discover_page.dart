import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';
import '../../../../core/ui/widgets/ones_search_field.dart';
import 'create_event_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _searchController = TextEditingController();

  late final List<_EventTemplate> _templates;

  @override
  void initState() {
    super.initState();
    _templates = _buildTemplates();
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
    final q = _searchController.text.trim().toLowerCase();
    final filtered = _templates.where((t) {
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          t.eventType.toLowerCase().contains(q) ||
          t.location.toLowerCase().contains(q);
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
        ),
      ),
    );
  }

  List<_EventTemplate> _buildTemplates() {
    final now = DateTime.now();
    return [
      _EventTemplate(
        id: 't_concert',
        title: 'Live Concert',
        eventType: 'Concert',
        location: 'NYC',
        start: DateTime(now.year, now.month, now.day + 2, 20, 0),
        end: DateTime(now.year, now.month, now.day + 2, 23, 0),
        coverAsset: 'assets/auth/concierto.png',
        framesHint: 'Neon stage frames',
      ),
      _EventTemplate(
        id: 't_movie',
        title: 'Movie Night',
        eventType: 'Movie',
        location: 'Brooklyn',
        start: DateTime(now.year, now.month, now.day + 5, 19, 30),
        end: DateTime(now.year, now.month, now.day + 5, 22, 0),
        coverAsset: 'assets/auth/amigos.png',
        framesHint: 'Cinema frames',
      ),
      _EventTemplate(
        id: 't_football',
        title: 'Football Match',
        eventType: 'Sports',
        location: 'Queens',
        start: DateTime(now.year, now.month, now.day + 8, 16, 0),
        end: DateTime(now.year, now.month, now.day + 8, 18, 0),
        coverAsset: 'assets/auth/amigos.png',
        framesHint: 'Team color frames',
      ),
    ];
  }

  Future<void> _openTemplate(BuildContext context, _EventTemplate template) {
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
                  initialTitle: template.title,
                  initialEventType: template.eventType,
                  initialLocation: template.location,
                  initialStartDate: DateTime(
                    template.start.year,
                    template.start.month,
                    template.start.day,
                  ),
                  initialStartTime: TimeOfDay.fromDateTime(template.start),
                  initialEndDate: DateTime(
                    template.end.year,
                    template.end.month,
                    template.end.day,
                  ),
                  initialEndTime: TimeOfDay.fromDateTime(template.end),
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
  final _EventTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: OnesColors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                template.coverAsset,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
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
                          borderRadius: BorderRadius.circular(16),
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
                          '${template.eventType} • ${template.location}',
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
  final _EventTemplate template;
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
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  template.coverAsset,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                template.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10),
              _InfoRow(label: 'Type', value: template.eventType),
              _InfoRow(label: 'Location', value: template.location),
              _InfoRow(label: 'Starts', value: _formatDateTime(template.start)),
              _InfoRow(label: 'Ends', value: _formatDateTime(template.end)),
              _InfoRow(label: 'Frames', value: template.framesHint),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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

  static String _formatDateTime(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$mm/$dd/${dt.year} $hh:$min';
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

class _EventTemplate {
  final String id;
  final String title;
  final String eventType;
  final String location;
  final DateTime start;
  final DateTime end;
  final String coverAsset;
  final String framesHint;

  const _EventTemplate({
    required this.id,
    required this.title,
    required this.eventType,
    required this.location,
    required this.start,
    required this.end,
    required this.coverAsset,
    required this.framesHint,
  });
}
