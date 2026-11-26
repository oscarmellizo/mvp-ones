import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../domain/collection.dart';
import '../collections_controller.dart';
import 'collection_detail_page.dart';

class CreateCollectionPage extends StatefulWidget {
  const CreateCollectionPage({super.key});

  @override
  State<CreateCollectionPage> createState() => _CreateCollectionPageState();
}

class _CreateCollectionPageState extends State<CreateCollectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _inviteesController = TextEditingController();
  CollectionType _type = CollectionType.family;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _inviteesController.dispose();
    super.dispose();
  }

  List<String> _emails() => _inviteesController.text
      .split(RegExp(r'[,;\n]'))
      .map((email) => email.trim().toLowerCase())
      .where((email) => email.isNotEmpty)
      .toSet()
      .toList(growable: false);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final collection = await context.read<CollectionsController>().create(
            name: _nameController.text.trim(),
            type: _type,
            description: _descriptionController.text.trim(),
            inviteeEmails: _type == CollectionType.private ? [] : _emails(),
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CollectionDetailPage(collection: collection),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    final language = t.getCurrentLanguage();
    final privateType = _type == CollectionType.private;

    return Scaffold(
      backgroundColor: OnesColors.surfaceWarm,
      appBar: AppBar(
        title: Text(t.translate(
          'collections.create',
          fallback: 'Nueva colección',
        )),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                t.translate(
                  'collections.create_intro',
                  fallback: 'Un espacio para guardar recuerdos juntos.',
                ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: OnesColors.inkSoft,
                    ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText:
                      t.translate('collections.name', fallback: 'Nombre'),
                  hintText: t.translate(
                    'collections.name_hint',
                    fallback: 'Ej. Viajes de la familia',
                  ),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? t.translate(
                        'collections.name_required',
                        fallback: 'Escribe un nombre para continuar.',
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                t.translate('collections.type', fallback: 'Tipo de colección'),
                style: const TextStyle(
                  color: OnesColors.purpleDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CollectionType.values.map((type) {
                  return ChoiceChip(
                    label: Text(type.label(language)),
                    selected: _type == type,
                    onSelected: (selected) {
                      if (selected) setState(() => _type = type);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLength: 500,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: t.translate(
                    'collections.description_optional',
                    fallback: 'Descripción (opcional)',
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              if (!privateType) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _inviteesController,
                  keyboardType: TextInputType.emailAddress,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _type == CollectionType.couple
                        ? t.translate(
                            'collections.partner_email',
                            fallback: 'Correo de tu pareja',
                          )
                        : t.translate(
                            'collections.invitees_optional',
                            fallback: 'Invitar por correo (opcional)',
                          ),
                    hintText: _type == CollectionType.couple
                        ? 'nombre@correo.com'
                        : 'nombre@correo.com, otra@correo.com',
                    helperText: _type == CollectionType.couple
                        ? t.translate(
                            'collections.partner_required_help',
                            fallback:
                                'La colección Pareja necesita una invitación para crearse.',
                          )
                        : t.translate(
                            'collections.invitees_help',
                            fallback:
                                'Puedes invitar más personas después de crearla.',
                          ),
                  ),
                  validator: (_) {
                    final emails = _emails();
                    if (_type == CollectionType.couple && emails.length != 1) {
                      return t.translate(
                        'collections.partner_required',
                        fallback: 'Agrega el correo de una persona.',
                      );
                    }
                    if (emails.any((email) => !email.contains('@'))) {
                      return t.translate(
                        'collections.email_invalid',
                        fallback: 'Revisa los correos ingresados.',
                      );
                    }
                    return null;
                  },
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    t.translate(
                      'collections.private_help',
                      fallback:
                          'Solo tú podrás entrar a esta colección. Aun así, puedes compartir fotos individuales.',
                    ),
                    style: const TextStyle(color: OnesColors.inkSoft),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: OnesColors.danger)),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.collections_bookmark_outlined),
                label: Text(t.translate(
                  'collections.create',
                  fallback: 'Crear colección',
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
