import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../admin_event_templates_controller.dart';
import '../admin_frames_controller.dart';
import '../widgets/admin_gate.dart';
import '../widgets/frame_multi_selector.dart';

class AdminEventTemplateEditPage extends StatefulWidget {
  final String? eventTemplateId;

  const AdminEventTemplateEditPage({super.key, this.eventTemplateId});

  @override
  State<AdminEventTemplateEditPage> createState() => _AdminEventTemplateEditPageState();
}

class _AdminEventTemplateEditPageState extends State<AdminEventTemplateEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sortOrderController = TextEditingController();
  String _status = 'active';
  List<String> _selectedFrameIds = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.eventTemplateId != null) {
      _loadEventTemplate();
    }
  }

  Future<void> _loadEventTemplate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ctrl = context.read<AdminEventTemplatesController>();
      final items = ctrl.items;
      final et = items.firstWhere(
        (e) => e.eventTemplateId == widget.eventTemplateId,
        orElse: () => throw Exception('Event template not found'),
      );

      _nameController.text = et.name;
      _status = et.status.toLowerCase() == 'active' ? 'active' : 'inactive';
      _sortOrderController.text = et.sortOrder?.toString() ?? '';
      _selectedFrameIds = List.from(et.frameIds);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ctrl = context.read<AdminEventTemplatesController>();
      final sortOrder = _sortOrderController.text.isNotEmpty
          ? int.tryParse(_sortOrderController.text)
          : null;

      if (widget.eventTemplateId != null) {
        await ctrl.update(
          eventTemplateId: widget.eventTemplateId!,
          name: _nameController.text.trim(),
          status: _status,
          sortOrder: sortOrder,
          frameIds: _selectedFrameIds,
        );
      } else {
        await ctrl.create(
          name: _nameController.text.trim(),
          status: _status,
          sortOrder: sortOrder,
          frameIds: _selectedFrameIds,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final framesCtrl = context.watch<AdminFramesController>();

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        title: Text(widget.eventTemplateId != null
            ? 'Edit Event Template'
            : 'Create Event Template'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: AdminGate(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildForm(framesCtrl),
      ),
    );
  }

  Widget _buildForm(AdminFramesController framesCtrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Error: $_error',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _status = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sortOrderController,
              decoration: const InputDecoration(
                labelText: 'Sort Order (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final parsed = int.tryParse(value);
                  if (parsed == null) {
                    return 'Must be a number';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            if (framesCtrl.loading)
              const LinearProgressIndicator()
            else
              FrameMultiSelector(
                availableFrames: framesCtrl.items
                    .where((f) => f.status.toLowerCase() == 'active')
                    .map((f) => FrameOption(id: f.frameId, name: f.name))
                    .toList(),
                selectedFrameIds: _selectedFrameIds,
                onSelectionChanged: (ids) {
                  setState(() {
                    _selectedFrameIds = ids;
                  });
                },
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: OnesColors.purpleMid,
                  foregroundColor: OnesColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.eventTemplateId != null ? 'Update' : 'Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }
}
