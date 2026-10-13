import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../presentation/account_controller.dart';

class AccountPage extends StatelessWidget {
  static const routeName = '/account';

  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                      'Tu cuenta se desactivará ahora. Si vuelves a iniciar sesión dentro de los próximos 30 días, se reactivará automáticamente. Pasados 30 días te enviaremos tus fotos por correo; el enlace dura 8 días y después borraremos tu cuenta y todo su contenido definitivamente.',
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
                                        'Tu cuenta se desactivará ahora. Si vuelves a iniciar sesión dentro de los próximos 30 días, se reactivará automáticamente. Pasados 30 días te enviaremos tus fotos por correo; el enlace dura 8 días y después borraremos tu cuenta y todo su contenido definitivamente. ¿Deseas continuar?'),
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
                                final result = await context.read<AccountController>().deactivateAndSignOut(auth);
                                if (!context.mounted) return;
                                if (result == DeactivationResult.cancelled) return;
                                if (result == DeactivationResult.failed) {
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

