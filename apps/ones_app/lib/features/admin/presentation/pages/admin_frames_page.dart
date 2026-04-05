import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../admin_frames_controller.dart';
import '../widgets/admin_gate.dart';
import 'admin_frame_edit_page.dart';

class AdminFramesPage extends StatefulWidget {
  const AdminFramesPage({super.key});

  @override
  State<AdminFramesPage> createState() => _AdminFramesPageState();
}

class _AdminFramesPageState extends State<AdminFramesPage> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminFramesController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminFramesController>();

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        title: const Text('Frames'),
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
                    onPressed: ctrl.loading
                        ? null
                        : () async {
                            final name = await _promptForName(context);
                            if (name == null || name.isEmpty) return;
                            await ctrl.create(name: name);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: OnesColors.purpleMid,
                      foregroundColor: OnesColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: const Text(
                      'Add frame',
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
                      final f = ctrl.items[i];
                      final isActive = f.status.toLowerCase() == 'active';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          f.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: ctrl.loading
                                  ? null
                                  : () => _navigateToEdit(context, f.frameId),
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar frame',
                            ),
                            Switch(
                              value: isActive,
                              onChanged: ctrl.loading
                                  ? null
                                  : (v) => ctrl.updateStatus(
                                        frameId: f.frameId,
                                        active: v,
                                      ),
                            ),
                            IconButton(
                              onPressed: ctrl.loading
                                  ? null
                                  : () async {
                                      final ok = await _confirmDelete(context);
                                      if (ok != true) return;
                                      await ctrl.delete(frameId: f.frameId);
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

  void _navigateToEdit(BuildContext context, String frameId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminFrameEditPage(frameId: frameId),
      ),
    );
  }

  Future<String?> _promptForName(BuildContext context) async {
    final controller = TextEditingController();

    final res = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New frame'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    return res;
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete frame?'),
          content: const Text('This will remove the frame record.'),
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
