import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../auth_controller.dart';
import '../widgets/polaroid_frame.dart';

/// Hay sesión, pero al abrir la app no se pudo hablar con el API. No se saca al usuario al login.
class OfflinePage extends StatelessWidget {
  const OfflinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final text = Theme.of(context).textTheme;
    final title =
        auth.serviceUnavailable ? 'Servicio no disponible' : 'Sin conexión';
    final message = auth.serviceUnavailable
        ? 'El servicio de Ones no está disponible temporalmente. Tu sesión sigue abierta; inténtalo de nuevo en unos minutos.'
        : 'No pudimos conectar con Ones. Revisa tu conexión a internet e inténtalo de nuevo; tu sesión sigue abierta.';

    return Scaffold(
      backgroundColor: OnesColors.surfaceWarm,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: PolaroidFrame(
                      angle: 0.03,
                      child: ColoredBox(
                        color: OnesColors.surfaceMuted,
                        child: Center(
                            child: Icon(Icons.wifi_off_rounded,
                                size: 72, color: OnesColors.purpleDeep)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800, color: OnesColors.black),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: OnesColors.black.withValues(alpha: 0.75),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('offline.retry'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: OnesColors.purpleMid,
                      foregroundColor: OnesColors.white,
                      shape: const RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12))),
                    ),
                    onPressed:
                        auth.isLoading ? null : () => auth.retryConnection(),
                    child: Text(
                      auth.isLoading ? 'Conectando...' : 'Reintentar',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('offline.logout'),
                    onPressed: auth.isLoading ? null : () => auth.logout(),
                    child: const Text(
                      'Usar otra cuenta',
                      style: TextStyle(
                          color: OnesColors.purpleDeep,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
