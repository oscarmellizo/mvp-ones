import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../presentation/admin_ops_controller.dart';

class AdminOpsPage extends StatelessWidget {
  const AdminOpsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminOpsController>();

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(title: const Text('Admin Ops')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                FilledButton(
                  onPressed: ctrl.isLoading ? null : () => ctrl.loadQueues(),
                  child: const Text('Cargar colas'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: ctrl.isLoading ? null : () => ctrl.loadMappings(),
                  child: const Text('Cargar mappings'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: ctrl.isLoading ? null : () => ctrl.setRealtimeMapping(true),
                  child: const Text('Habilitar Realtime'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: ctrl.isLoading ? null : () => ctrl.setRealtimeMapping(false),
                  child: const Text('Deshabilitar Realtime'),
                ),
              ]),
              const SizedBox(height: 16),
              const Text('Queues', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(_pretty(ctrl.queues)),
              ),
              const SizedBox(height: 16),
              const Text('Mappings', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(_pretty(ctrl.mappings)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _pretty(Map<String, dynamic>? map) {
    if (map == null) return '{}';
    return const JsonEncoder.withIndent('  ').convert(map);
    }
}
