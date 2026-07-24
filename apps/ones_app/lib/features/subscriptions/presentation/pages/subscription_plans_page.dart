import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../domain/subscription_plan.dart';
import '../subscriptions_controller.dart';
import 'payment_profile_form_page.dart';

class SubscriptionPlansPage extends StatefulWidget {
  static const routeName = '/subscription-plans';

  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionsController>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SubscriptionsController>();
    final plans = controller.plans;
    final subscription = controller.subscription;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes Ones'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: controller.isLoading && plans.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const _Header(),
                  const SizedBox(height: 24),
                  if (controller.error != null)
                    _ErrorBanner(message: controller.error!),
                  ...plans.map((plan) {
                    final isCurrent = subscription?.planId == plan.planId;
                    return _PlanCard(
                      plan: plan,
                      isCurrent: isCurrent,
                      onSubscribe: plan.tier.toLowerCase() == 'paid'
                          ? () => _onSubscribe(plan.planId)
                          : null,
                    );
                  }),
                ],
              ),
      ),
    );
  }

  Future<void> _onSubscribe(String planId) async {
    final method = await _selectPaymentMethod();
    if (!mounted || method == null) return;

    switch (method) {
      case _PaymentMethod.mercadoPago:
        // Navega a la pantalla para completar datos del pagador y continuar al checkout
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentProfileFormPage(planId: planId),
          ),
        );
        break;
      case _PaymentMethod.pse:
      case _PaymentMethod.stripe:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Metodo de pago proximamente disponible')),
        );
        break;
    }
  }

  Future<_PaymentMethod?> _selectPaymentMethod() async {
    return showModalBottomSheet<_PaymentMethod>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Selecciona metodo de pago',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.creditCard),
                title: const Text('Mercado Pago'),
                onTap: () => Navigator.of(ctx).pop(_PaymentMethod.mercadoPago),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.buildingColumns),
                title: const Text('PSE (proximamente)'),
                enabled: false,
                onTap: null,
              ),
              const Divider(height: 0),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.ccStripe),
                title: const Text('Stripe (proximamente)'),
                enabled: false,
                onTap: null,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
 
enum _PaymentMethod { mercadoPago, pse, stripe }

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FaIcon(
          FontAwesomeIcons.crown,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Elige tu plan',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Actualiza a Ones Plus y disfruta sin lÃ­mites. Puedes cambiar o cancelar en cualquier momento.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OnesColors.black.withOpacity(0.6),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final VoidCallback? onSubscribe;

  const _PlanCard({required this.plan, required this.isCurrent, this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaid = plan.tier.toLowerCase() == 'paid';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isCurrent ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrent
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (isCurrent)
                  Chip(
                    label: const Text('Actual'),
                    backgroundColor: OnesColors.purpleMid,
                    labelStyle: const TextStyle(
                      color: OnesColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plan.shortDescription ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: OnesColors.black.withOpacity(0.6),
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              plan.formattedPrice(),
              style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isPaid ? theme.colorScheme.primary : null,
                  ),
            ),
            const SizedBox(height: 16),
            ..._buildFeatures(plan),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCurrent ? null : onSubscribe,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isCurrent
                      ? 'Plan actual'
                      : (isPaid ? 'Suscribirse' : 'Continuar gratis'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeatures(SubscriptionPlan plan) {
    final entries = plan.features.entries.toList(growable: false)
      ..sort((MapEntry<String, PlanFeature> a, MapEntry<String, PlanFeature> b) {
        final aLabel = (a.value.label ?? a.key).toString();
        final bLabel = (b.value.label ?? b.key).toString();
        return aLabel.compareTo(bLabel);
      });

    return entries.map((entry) {
      final feature = entry.value;
      final value = feature.value;
      final label = feature.label ?? entry.key;
      FaIconData icon;
      String text;

      if (value is bool) {
        icon = value ? FontAwesomeIcons.check : FontAwesomeIcons.xmark;
        text = label;
      } else if (value is num) {
        icon = FontAwesomeIcons.circleCheck;
        text = '$label: ${value.toInt()}';
      } else {
        icon = FontAwesomeIcons.circleCheck;
        text = label;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            FaIcon(
              icon,
              size: 16,
              color: value == true || value is num
                  ? OnesColors.green
                  : OnesColors.black,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _PaymentProfileCard extends StatefulWidget {
  final String? initialEmail;
  final Future<void> Function(String email) onSave;

  const _PaymentProfileCard({required this.initialEmail, required this.onSave});

  @override
  State<_PaymentProfileCard> createState() => _PaymentProfileCardState();
}

class _PaymentProfileCardState extends State<_PaymentProfileCard> {
  late final TextEditingController _emailCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEmail = _emailCtrl.text.trim().isNotEmpty;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Perfil de pago', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Este correo se usarÃ¡ como pagador en Mercado Pago. Puedes actualizarlo antes de suscribirte.'),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo de pago (Mercado Pago)',
                hintText: 'tu-email@ejemplo.com',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final email = _emailCtrl.text.trim();
                          if (email.isEmpty) return;
                          setState(() => _saving = true);
                          try {
                            await widget.onSave(email);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Perfil de pago actualizado')),
                            );
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  icon: const Icon(Icons.save),
                  label: Text(_saving ? 'Guardando...' : 'Guardar'),
                ),
                const SizedBox(width: 12),
                if (!hasEmail)
                  const Text(
                    'Agrega tu correo de pago para continuar',
                    style: TextStyle(color: Colors.redAccent),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnesColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.circleExclamation, color: OnesColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: OnesColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

