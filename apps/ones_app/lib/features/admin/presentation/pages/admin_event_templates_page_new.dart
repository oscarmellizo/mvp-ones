import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../admin_event_templates_controller.dart';
import '../widgets/admin_gate.dart';
import 'admin_event_template_edit_page.dart';

class AdminEventTemplatesPage extends StatefulWidget {
  const AdminEventTemplatesPage({super.key});

  @override
  State<AdminEventTemplatesPage> createState() =>
      _AdminEventTemplatesPageState();
}

class _AdminEventTemplatesPageState extends State<AdminEventTemplatesPage> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminEventTemplatesController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminEventTemplatesController>();

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        title: const Text('Event Templates'),
        actions: [
          IconButton(
            onPressed: ctrl.loading ? null : () => ctrl.load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AdminGate(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        ctrl.loading ? null : () => _navigateToCreate(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: OnesColors.purpleMid,
                      foregroundColor: OnesColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: const Text(
                      'Add event template',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (ctrl.lastError != null)
                  Text(
                    'Error: ${ctrl.lastError}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (ctrl.loading) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: ctrl.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final et = ctrl.items[i];
                      final isActive = et.status.toLowerCase() == 'active';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          et.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${et.frameIds.length} frame${et.frameIds.length == 1 ? '' : 's'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: ctrl.loading
                                  ? null
                                  : () => _navigateToEdit(
                                      context, et.eventTemplateId),
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar event template',
                            ),
                            Switch(
                              value: isActive,
                              onChanged: ctrl.loading
                                  ? null
                                  : (v) => ctrl.updateStatus(
                                        eventTemplateId: et.eventTemplateId,
                                        active: v,
                                      ),
                            ),
                            IconButton(
                              onPressed: ctrl.loading
                                  ? null
                                  : () async {
                                      final ok = await _confirmDelete(context);
                                      if (ok != true) return;
                                      await ctrl.delete(
                                          eventTemplateId: et.eventTemplateId);
                                    },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminEventTemplateEditPage(),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, String eventTemplateId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AdminEventTemplateEditPage(eventTemplateId: eventTemplateId),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete event template?'),
          content: const Text('This will remove the event template record.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
