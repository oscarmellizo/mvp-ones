import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../admin_translations_controller.dart';

class AdminTranslationEditPage extends StatefulWidget {
  final String languageCode;
  final String? translationKey;
  final String? currentValue;
  final String? currentContext;

  const AdminTranslationEditPage({
    super.key,
    required this.languageCode,
    this.translationKey,
    this.currentValue,
    this.currentContext,
  });

  @override
  State<AdminTranslationEditPage> createState() => _AdminTranslationEditPageState();
}

class _AdminTranslationEditPageState extends State<AdminTranslationEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();
  final _contextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _keyController.text = widget.translationKey ?? '';
    _valueController.text = widget.currentValue ?? '';
    _contextController.text = widget.currentContext ?? '';
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final ctrl = context.read<AdminTranslationsController>();
    final isEditing = widget.translationKey != null;

    if (isEditing) {
      await ctrl.update(
        translationKey: widget.translationKey!,
        languageCode: widget.languageCode,
        value: _valueController.text,
        context: _contextController.text.isEmpty ? null : _contextController.text,
      );
    } else {
      await ctrl.create(
        translationKey: _keyController.text,
        languageCode: widget.languageCode,
        value: _valueController.text,
        context: _contextController.text.isEmpty ? null : _contextController.text,
      );
    }

    if (mounted && ctrl.lastError == null) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminTranslationsController>();
    final isEditing = widget.translationKey != null;

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Translation' : 'Add Translation'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _keyController,
                  enabled: !isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Translation Key',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Translation key is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valueController,
                  decoration: const InputDecoration(
                    labelText: 'Translation Value',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Translation value is required';
                    }
                    return null;
                  },
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contextController,
                  decoration: const InputDecoration(
                    labelText: 'Context (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., button, label, message',
                  ),
                ),
                const SizedBox(height: 16),
                if (ctrl.lastError != null)
                  Text(
                    'Error: ${ctrl.lastError}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 16),
                if (ctrl.loading) const LinearProgressIndicator(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: ctrl.loading ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: OnesColors.purpleMid,
                      foregroundColor: OnesColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Update' : 'Create',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
