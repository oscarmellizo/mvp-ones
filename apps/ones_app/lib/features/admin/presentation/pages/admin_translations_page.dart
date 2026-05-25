import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../admin_translations_controller.dart';
import '../widgets/admin_gate.dart';
import 'admin_translation_edit_page.dart';

class AdminTranslationsPage extends StatefulWidget {
  const AdminTranslationsPage({super.key});

  @override
  State<AdminTranslationsPage> createState() => _AdminTranslationsPageState();
}

class _AdminTranslationsPageState extends State<AdminTranslationsPage> {
  bool _loaded = false;
  String _selectedLanguage = 'es';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminTranslationsController>().load(_selectedLanguage);
    });
  }

  Future<void> _refresh() {
    return context.read<AdminTranslationsController>().load(_selectedLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminTranslationsController>();

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        title: const Text('Traducciones'),
        actions: [
          IconButton(
            onPressed: ctrl.loading ? null : _refresh,
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
                // Language selector
                DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Idioma',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'pt', child: Text('Português')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedLanguage = value;
                      });
                      _refresh();
                    }
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: ctrl.loading
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminTranslationEditPage(
                                  languageCode: _selectedLanguage,
                                ),
                              ),
                            );
                            _refresh();
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
                      'Add translation',
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
                      final t = ctrl.items[i];

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          t.translationKey,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(t.value ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: ctrl.loading
                                  ? null
                                  : () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AdminTranslationEditPage(
                                            languageCode: _selectedLanguage,
                                            translationKey: t.translationKey,
                                            currentValue: t.value,
                                            currentContext: t.context,
                                          ),
                                        ),
                                      );
                                      _refresh();
                                    },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: ctrl.loading
                                  ? null
                                  : () async {
                                      final confirmed = await _confirmDelete(context);
                                      if (confirmed && mounted) {
                                        await ctrl.delete(
                                          t.translationKey,
                                          _selectedLanguage,
                                        );
                                        _refresh();
                                      }
                                    },
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

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete translation'),
            content: const Text('Are you sure you want to delete this translation?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _promptForName(BuildContext context) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New frame'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
