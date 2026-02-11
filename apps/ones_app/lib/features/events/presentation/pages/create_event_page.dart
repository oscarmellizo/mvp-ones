import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../events_controller.dart';

class CreateEventPage extends StatefulWidget {
  static const routeName = '/events/create';

  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Crear evento')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.loading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        await controller.createNew(_titleController.text.trim());
                        if (context.mounted) Navigator.of(context).pop();
                      },
                child: controller.loading ? const Text('Creando...') : const Text('Crear'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
