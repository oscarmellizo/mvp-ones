import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';
import '../../presentation/admin_admins_controller.dart';
import '../widgets/admin_gate.dart';

class AdminAdminsPage extends StatelessWidget {
  const AdminAdminsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: Scaffold(
        backgroundColor: OnesColors.background,
        appBar: AppBar(
          title: const Text('Administrators'),
          actions: [
            IconButton(
              onPressed: () => context.read<AdminAdminsController>().refresh(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: _Body(),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminAdminsController>().refresh();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminAdminsController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnesCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add administrator',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'email@domain.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                ),
                onSubmitted: (_) => _onAdd(context),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OnesColors.purpleMid,
                    foregroundColor: OnesColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  onPressed: ctrl.loading ? null : () => _onAdd(context),
                  child: Text(
                    ctrl.loading ? 'Saving...' : 'Add / activate',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (ctrl.error != null) ...[
          OnesCard(
            padding: const EdgeInsets.all(14),
            color: OnesColors.white,
            child: Text(
              'Error: ${ctrl.error}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Expanded(
          child: OnesCard(
            padding: const EdgeInsets.all(14),
            child: ctrl.loading && ctrl.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ctrl.items.isEmpty
                    ? const Text('No administrators found.')
                    : ListView.separated(
                        itemCount: ctrl.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (context, idx) {
                          final it = ctrl.items[idx];
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it.email,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      it.status.toLowerCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: it.isActive
                                            ? OnesColors.green
                                            : OnesColors.black
                                                .withOpacity(0.55),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: it.isActive,
                                onChanged: ctrl.loading
                                    ? null
                                    : (v) async {
                                        try {
                                          await context
                                              .read<AdminAdminsController>()
                                              .setStatus(it.email, v);
                                        } catch (_) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Could not update status.'),
                                            ),
                                          );
                                        }
                                      },
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Future<void> _onAdd(BuildContext context) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    FocusScope.of(context).unfocus();
    try {
      await context.read<AdminAdminsController>().addAdmin(email);
      if (!context.mounted) return;
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin saved: $email')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save admin.')),
      );
    }
  }
}
