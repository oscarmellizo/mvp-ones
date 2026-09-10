import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../subscriptions/presentation/subscriptions_controller.dart';
import '../../presentation/account_controller.dart';
import '../../../subscriptions/presentation/pages/subscription_plans_page.dart';

class AccountPage extends StatelessWidget {
  static const routeName = '/account';

  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final subs = context.watch<SubscriptionsController>();
    final auth = context.watch<AuthController>();
    final account = context.watch<AccountController>();

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        backgroundColor: OnesColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Cuenta'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              _PlanCard(subscriptions: subs),
              const SizedBox(height: 16),
              OnesCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Desactivar cuenta',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tu cuenta se desactivará ahora. Si vuelves a iniciar sesión dentro de 30 días, se reactivará automáticamente. Pasados 30 días te enviaremos tus fotos al correo registrado y procederemos al cierre definitivo de tu cuenta.',
                      style: TextStyle(color: OnesColors.black.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: OnesColors.danger,
                          foregroundColor: OnesColors.white,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: account.loading
                            ? null
                            : () async {
                                final confirmed1 = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Desactivar cuenta'),
                                    content: const Text(
                                        'Tu cuenta se desactivará ahora. Si vuelves a iniciar sesión dentro de 30 días, se reactivará automáticamente. Pasados 30 días te enviaremos tus fotos al correo registrado y procederemos al cierre definitivo de tu cuenta. ¿Deseas continuar?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: const Text('Darse de baja'),
                                      )
                                    ],
                                  ),
                                );
                                if (confirmed1 != true) return;
                                final confirmed2 = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirmar desactivación'),
                                    content: const Text('¿Confirmas desactivar tu cuenta? Se cerrará tu sesión.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: const Text('Confirmar'),
                                      )
                                    ],
                                  ),
                                );
                                if (confirmed2 != true) return;
                                final ok = await context.read<AccountController>().deactivateAndSignOut(auth);
                                if (!context.mounted) return;
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No fue posible desactivar la cuenta. Intenta de nuevo.')),
                                  );
                                  return;
                                }
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              },
                        child: account.loading
                            ? const Text('Procesando…')
                            : const Text('Borrar cuenta'),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionsController subscriptions;
  const _PlanCard({required this.subscriptions});

  @override
  Widget build(BuildContext context) {
    final plan = subscriptions.currentPlan;
    final status = subscriptions.subscription?.status ?? 'free';
    return OnesCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan actual',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan?.name ?? 'Free',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: OnesColors.black,
                      ),
                    ),
                    Text(
                      plan?.formattedPrice() ?? 'Gratis',
                      style: TextStyle(
                        color: OnesColors.black.withOpacity(0.6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: status.toLowerCase() == 'active'
                      ? OnesColors.green.withOpacity(0.15)
                      : OnesColors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    color: status.toLowerCase() == 'active'
                        ? OnesColors.green
                        : OnesColors.black.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: OnesColors.purpleMid,
                side: const BorderSide(color: OnesColors.purpleMid),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionPlansPage(),
                  ),
                );
              },
              child: const Text(
                'Ver planes',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
